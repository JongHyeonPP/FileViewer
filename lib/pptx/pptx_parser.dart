import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart' as xml;

import 'pptx_models.dart';

class PptxParser {
  static const double emuPerInch = 914400.0;
  static const double ptPerInch = 72.0;
  static const double emuPerPt = emuPerInch / ptPerInch;

  Future<PptxPresentationData> loadPresentation(String path) async {
    final File file = File(path);
    final List<int> bytes = await file.readAsBytes();
    final Archive archive = ZipDecoder().decodeBytes(bytes);

    final Map<String, ArchiveFile> fileMap = <String, ArchiveFile>{};
    for (final ArchiveFile f in archive.files) {
      fileMap[f.name] = f;
    }

    final ArchiveFile? presentationFile = fileMap['ppt/presentation.xml'];
    final ArchiveFile? relsFile = fileMap['ppt/_rels/presentation.xml.rels'];

    if (presentationFile == null || relsFile == null) {
      throw const FormatException('presentation not found');
    }

    final xml.XmlDocument presentationDoc = xml.XmlDocument.parse(
      _asUtf8String(presentationFile),
    );
    final xml.XmlDocument relsDoc = xml.XmlDocument.parse(
      _asUtf8String(relsFile),
    );

    int slideW = 9144000;
    int slideH = 6858000;

    final xml.XmlElement? sldSz = _firstByLocalName(presentationDoc, 'sldSz');
    if (sldSz != null) {
      final int? cx = int.tryParse(_attrLocal(sldSz, 'cx') ?? '');
      final int? cy = int.tryParse(_attrLocal(sldSz, 'cy') ?? '');
      if (cx != null && cx > 0) {
        slideW = cx;
      }
      if (cy != null && cy > 0) {
        slideH = cy;
      }
    }

    final Map<String, String> presRelMap = _parseRelationships(relsDoc);

    final List<String> slideTargets = <String>[];
    for (final xml.XmlElement sldId in _allByLocalName(
      presentationDoc,
      'sldId',
    )) {
      final String? rId = _attrLocal(sldId, 'id', prefix: 'r');
      if (rId == null || rId.isEmpty) {
        continue;
      }
      final String? target = presRelMap[rId];
      if (target == null || target.isEmpty) {
        continue;
      }
      final String slidePath = _resolvePath('ppt/', target);
      slideTargets.add(slidePath);
    }

    final List<PptxSlideData> slides = <PptxSlideData>[];

    for (int i = 0; i < slideTargets.length; i += 1) {
      final String slidePath = slideTargets[i];
      final ArchiveFile? slideFile = fileMap[slidePath];
      if (slideFile == null) {
        continue;
      }

      final String slideFileName = slidePath.split('/').last;
      final String slideRelsPath = 'ppt/slides/_rels/$slideFileName.rels';
      final ArchiveFile? slideRelsFile = fileMap[slideRelsPath];

      final xml.XmlDocument slideDoc = xml.XmlDocument.parse(
        _asUtf8String(slideFile),
      );

      final Map<String, String> slideRelMap = slideRelsFile != null
          ? _parseRelationships(
              xml.XmlDocument.parse(_asUtf8String(slideRelsFile)),
            )
          : <String, String>{};

      final _SlideParseResult parsed = _parseSlide(
        slideDoc: slideDoc,
        slideRelMap: slideRelMap,
        fileMap: fileMap,
        slideIndex: i,
      );

      slides.add(
        PptxSlideData(
          index: i,
          title: parsed.title,
          backgroundColor: parsed.backgroundColor,
          elements: parsed.elements,
        ),
      );
    }

    return PptxPresentationData(
      slideWidthEmu: slideW,
      slideHeightEmu: slideH,
      slides: slides,
    );
  }

  _SlideParseResult _parseSlide({
    required xml.XmlDocument slideDoc,
    required Map<String, String> slideRelMap,
    required Map<String, ArchiveFile> fileMap,
    required int slideIndex,
  }) {
    final Color? bgColor = _parseBackgroundColor(slideDoc);
    final List<PptxSlideElement> elements = <PptxSlideElement>[];

    final xml.XmlElement? spTree = _firstByLocalName(slideDoc, 'spTree');
    if (spTree == null) {
      return _SlideParseResult(
        title: null,
        backgroundColor: bgColor,
        elements: elements,
      );
    }

    final String? title = _extractTitleFromSpTree(spTree);

    _parseSpTree(
      spTree: spTree,
      transform: _PptxTransform.identity,
      slideRelMap: slideRelMap,
      fileMap: fileMap,
      elements: elements,
    );

    return _SlideParseResult(
      title: title,
      backgroundColor: bgColor,
      elements: elements,
    );
  }

  String? _extractTitleFromSpTree(xml.XmlElement spTree) {
    for (final xml.XmlNode node in spTree.children) {
      if (node is! xml.XmlElement) {
        continue;
      }
      if (node.name.local != 'sp') {
        continue;
      }

      final xml.XmlElement? nvSpPr = _firstChildByLocalName(node, 'nvSpPr');
      if (nvSpPr == null) {
        continue;
      }

      final xml.XmlElement? nvPr = _firstChildByLocalName(nvSpPr, 'nvPr');
      if (nvPr == null) {
        continue;
      }

      final xml.XmlElement? ph = _firstByLocalName(nvPr, 'ph');
      if (ph == null) {
        continue;
      }

      final String? type = _attrLocal(ph, 'type');
      if (type != 'title' && type != 'ctrTitle') {
        continue;
      }

      final String? text = _extractTextFromShape(node);
      if (text != null && text.trim().isNotEmpty) {
        return text.trim();
      }
    }

    return null;
  }

  void _parseSpTree({
    required xml.XmlElement spTree,
    required _PptxTransform transform,
    required Map<String, String> slideRelMap,
    required Map<String, ArchiveFile> fileMap,
    required List<PptxSlideElement> elements,
  }) {
    for (final xml.XmlNode node in spTree.children) {
      if (node is! xml.XmlElement) {
        continue;
      }

      final String local = node.name.local;

      if (local == 'sp') {
        final PptxPicture? filledPic = _parseShapeBlipFillAsPicture(
          sp: node,
          transform: transform,
          slideRelMap: slideRelMap,
          fileMap: fileMap,
        );
        if (filledPic != null) {
          elements.add(filledPic);
          continue;
        }

        final PptxTextBox? textBox = _parseTextShape(
          sp: node,
          transform: transform,
        );
        if (textBox != null) {
          elements.add(textBox);
        }
      } else if (local == 'pic') {
        final PptxPicture? pic = _parsePicture(
          pic: node,
          transform: transform,
          slideRelMap: slideRelMap,
          fileMap: fileMap,
        );
        if (pic != null) {
          elements.add(pic);
        }
      } else if (local == 'grpSp') {
        final _PptxTransform groupTransform = _deriveGroupTransform(
          grpSp: node,
          parent: transform,
        );

        _parseSpTree(
          spTree: node,
          transform: groupTransform,
          slideRelMap: slideRelMap,
          fileMap: fileMap,
          elements: elements,
        );
      }
    }
  }

  _PptxTransform _deriveGroupTransform({
    required xml.XmlElement grpSp,
    required _PptxTransform parent,
  }) {
    final xml.XmlElement? grpSpPr = _firstChildByLocalName(grpSp, 'grpSpPr');
    final xml.XmlElement? xfrm = grpSpPr != null
        ? _firstByLocalName(grpSpPr, 'xfrm')
        : null;

    if (xfrm == null) {
      return parent;
    }

    final _XfrmInfo info = _parseXfrm(xfrm);

    final double groupOffX = info.offX;
    final double groupOffY = info.offY;
    final double groupExtX = info.extX <= 0 ? 1 : info.extX;
    final double groupExtY = info.extY <= 0 ? 1 : info.extY;

    final double chOffX = info.chOffX;
    final double chOffY = info.chOffY;
    final double chExtX = info.chExtX <= 0 ? groupExtX : info.chExtX;
    final double chExtY = info.chExtY <= 0 ? groupExtY : info.chExtY;

    final double offXSlide = parent.applyX(groupOffX);
    final double offYSlide = parent.applyY(groupOffY);

    final double newScaleX = parent.scaleX * (groupExtX / chExtX);
    final double newScaleY = parent.scaleY * (groupExtY / chExtY);

    return _PptxTransform(
      offsetX: offXSlide,
      offsetY: offYSlide,
      originX: chOffX,
      originY: chOffY,
      scaleX: newScaleX,
      scaleY: newScaleY,
    );
  }

  PptxTextBox? _parseTextShape({
    required xml.XmlElement sp,
    required _PptxTransform transform,
  }) {
    final xml.XmlElement? spPr = _firstChildByLocalName(sp, 'spPr');
    if (spPr == null) {
      return null;
    }

    final xml.XmlElement? xfrm = _firstByLocalName(spPr, 'xfrm');
    if (xfrm == null) {
      return null;
    }

    final _XfrmRect? xr = _rectFromXfrm(xfrm);
    if (xr == null) {
      return null;
    }

    final PptxRect rect = transform.applyRect(xr.rect);

    final xml.XmlElement? txBody = _firstByLocalName(sp, 'txBody');
    if (txBody == null) {
      return null;
    }

    final _TextBodyInfo info = _parseTextBody(txBody);
    if (info.paragraphs.isEmpty) {
      return null;
    }

    return PptxTextBox(
      rect: rect,
      paragraphs: info.paragraphs,
      textAlign: info.paragraphs.first.textAlign,
      paddingEmu: info.paddingEmu,
      verticalAnchor: info.verticalAnchor,
      backgroundColor: info.backgroundColor,
    );
  }

  PptxPicture? _parsePicture({
    required xml.XmlElement pic,
    required _PptxTransform transform,
    required Map<String, String> slideRelMap,
    required Map<String, ArchiveFile> fileMap,
  }) {
    final xml.XmlElement? spPr = _firstByLocalName(pic, 'spPr');
    if (spPr == null) {
      return null;
    }

    final xml.XmlElement? xfrm = _firstByLocalName(spPr, 'xfrm');
    if (xfrm == null) {
      return null;
    }

    final _XfrmRect? xr = _rectFromXfrm(xfrm);
    if (xr == null) {
      return null;
    }

    final PptxRect rect = transform.applyRect(xr.rect);

    final xml.XmlElement? blip = _firstByLocalName(pic, 'blip');
    if (blip == null) {
      return null;
    }

    final String? rEmbed = _attrLocal(blip, 'embed', prefix: 'r');
    if (rEmbed == null || rEmbed.isEmpty) {
      return null;
    }

    final String? target = slideRelMap[rEmbed];
    if (target == null || target.isEmpty) {
      return null;
    }

    final String resolved = _resolvePath('ppt/slides/', target);
    final ArchiveFile? mediaFile = fileMap[resolved];
    if (mediaFile == null) {
      return null;
    }

    final PptxCropRect crop = _parseCropFromPicOrSp(pic) ?? PptxCropRect.none;

    return PptxPicture(
      rect: rect,
      bytes: _asBytes(mediaFile),
      rotationRad: xr.rotationRad,
      flipH: xr.flipH,
      flipV: xr.flipV,
      crop: crop,
    );
  }

  PptxPicture? _parseShapeBlipFillAsPicture({
    required xml.XmlElement sp,
    required _PptxTransform transform,
    required Map<String, String> slideRelMap,
    required Map<String, ArchiveFile> fileMap,
  }) {
    final xml.XmlElement? blipFill = _firstByLocalName(sp, 'blipFill');
    if (blipFill == null) {
      return null;
    }

    final xml.XmlElement? blip = _firstByLocalName(blipFill, 'blip');
    if (blip == null) {
      return null;
    }

    final String? rEmbed = _attrLocal(blip, 'embed', prefix: 'r');
    if (rEmbed == null || rEmbed.isEmpty) {
      return null;
    }

    final String? target = slideRelMap[rEmbed];
    if (target == null || target.isEmpty) {
      return null;
    }

    final xml.XmlElement? spPr = _firstChildByLocalName(sp, 'spPr');
    if (spPr == null) {
      return null;
    }

    final xml.XmlElement? xfrm = _firstByLocalName(spPr, 'xfrm');
    if (xfrm == null) {
      return null;
    }

    final _XfrmRect? xr = _rectFromXfrm(xfrm);
    if (xr == null) {
      return null;
    }

    final PptxRect rect = transform.applyRect(xr.rect);

    final String resolved = _resolvePath('ppt/slides/', target);
    final ArchiveFile? mediaFile = fileMap[resolved];
    if (mediaFile == null) {
      return null;
    }

    final PptxCropRect crop =
        _parseCropFromBlipFill(blipFill) ?? PptxCropRect.none;

    return PptxPicture(
      rect: rect,
      bytes: _asBytes(mediaFile),
      rotationRad: xr.rotationRad,
      flipH: xr.flipH,
      flipV: xr.flipV,
      crop: crop,
    );
  }

  PptxCropRect? _parseCropFromPicOrSp(xml.XmlElement picOrSp) {
    final xml.XmlElement? blipFill = _firstByLocalName(picOrSp, 'blipFill');
    if (blipFill == null) {
      return null;
    }
    return _parseCropFromBlipFill(blipFill);
  }

  PptxCropRect? _parseCropFromBlipFill(xml.XmlElement blipFill) {
    final xml.XmlElement? srcRect = _firstByLocalName(blipFill, 'srcRect');
    if (srcRect == null) {
      return null;
    }

    double parsePct(String? v) {
      if (v == null || v.trim().isEmpty) {
        return 0;
      }
      final int? raw = int.tryParse(v.trim());
      if (raw == null) {
        return 0;
      }
      return (raw / 100000.0).clamp(0.0, 1.0);
    }

    final double l = parsePct(_attrLocal(srcRect, 'l'));
    final double t = parsePct(_attrLocal(srcRect, 't'));
    final double r = parsePct(_attrLocal(srcRect, 'r'));
    final double b = parsePct(_attrLocal(srcRect, 'b'));

    if (l == 0 && t == 0 && r == 0 && b == 0) {
      return PptxCropRect.none;
    }

    return PptxCropRect(l: l, t: t, r: r, b: b);
  }

  _TextBodyInfo _parseTextBody(xml.XmlElement txBody) {
    PptxPaddingEmu paddingEmu = PptxPaddingEmu.zero;
    PptxVerticalAnchor anchor = PptxVerticalAnchor.top;

    final xml.XmlElement? bodyPr = _firstByLocalName(txBody, 'bodyPr');
    if (bodyPr != null) {
      final double lIns =
          double.tryParse(_attrLocal(bodyPr, 'lIns') ?? '') ?? 0;
      final double tIns =
          double.tryParse(_attrLocal(bodyPr, 'tIns') ?? '') ?? 0;
      final double rIns =
          double.tryParse(_attrLocal(bodyPr, 'rIns') ?? '') ?? 0;
      final double bIns =
          double.tryParse(_attrLocal(bodyPr, 'bIns') ?? '') ?? 0;

      paddingEmu = PptxPaddingEmu(l: lIns, t: tIns, r: rIns, b: bIns);

      final String? a = _attrLocal(bodyPr, 'anchor');
      if (a == 'ctr') {
        anchor = PptxVerticalAnchor.center;
      } else if (a == 'b') {
        anchor = PptxVerticalAnchor.bottom;
      } else {
        anchor = PptxVerticalAnchor.top;
      }
    }

    Color? backgroundColor;
    final xml.XmlElement? bgSolid = bodyPr != null
        ? _firstByLocalName(bodyPr, 'solidFill')
        : null;
    if (bgSolid != null) {
      final xml.XmlElement? srgb = _firstByLocalName(bgSolid, 'srgbClr');
      if (srgb != null) {
        backgroundColor = _parseSrgbColor(_attrLocal(srgb, 'val'));
      }
    }

    final List<PptxParagraph> paragraphs = <PptxParagraph>[];

    for (final xml.XmlNode node in txBody.children) {
      if (node is! xml.XmlElement) {
        continue;
      }
      if (node.name.local != 'p') {
        continue;
      }

      final xml.XmlElement p = node;

      final xml.XmlElement? pPr = _firstChildByLocalName(p, 'pPr');
      final String? algn = pPr != null ? _attrLocal(pPr, 'algn') : null;

      TextAlign textAlign = TextAlign.left;
      if (algn == 'ctr') {
        textAlign = TextAlign.center;
      } else if (algn == 'r') {
        textAlign = TextAlign.right;
      } else if (algn == 'just') {
        textAlign = TextAlign.justify;
      }

      String? bulletChar;
      double marL = 0;
      double indent = 0;

      if (pPr != null) {
        final xml.XmlElement? buChar = _firstByLocalName(pPr, 'buChar');
        if (buChar != null) {
          bulletChar = _attrLocal(buChar, 'char');
        }
        marL = double.tryParse(_attrLocal(pPr, 'marL') ?? '') ?? 0;
        indent = double.tryParse(_attrLocal(pPr, 'indent') ?? '') ?? 0;
      }

      final List<PptxRun> runs = <PptxRun>[];
      double defaultFontSizePt = 18.0;
      Color? defaultColor = Colors.black;

      for (final xml.XmlNode c in p.children) {
        if (c is! xml.XmlElement) {
          continue;
        }

        final String local = c.name.local;

        if (local == 'r') {
          final _RunStyle style = _parseRunStyle(c);
          final String text = _extractTextFromRun(c);

          if (style.fontSizePt != null) {
            defaultFontSizePt = style.fontSizePt!;
          }
          if (style.color != null) {
            defaultColor = style.color;
          }

          runs.add(
            PptxRun(
              text: text,
              fontSizePt: style.fontSizePt ?? defaultFontSizePt,
              isBold: style.isBold,
              isItalic: style.isItalic,
              isUnderline: style.isUnderline,
              color: style.color,
              fontFamily: style.fontFamily,
            ),
          );
        } else if (local == 'br') {
          runs.add(
            PptxRun(
              text: '\n',
              fontSizePt: defaultFontSizePt,
              isBold: false,
              isItalic: false,
              isUnderline: false,
              color: defaultColor,
              fontFamily: null,
            ),
          );
        } else if (local == 'fld') {
          final String text = _extractTextFromRun(c);
          runs.add(
            PptxRun(
              text: text,
              fontSizePt: defaultFontSizePt,
              isBold: false,
              isItalic: false,
              isUnderline: false,
              color: defaultColor,
              fontFamily: null,
            ),
          );
        }
      }

      if (runs.isEmpty) {
        continue;
      }

      paragraphs.add(
        PptxParagraph(
          runs: runs,
          bulletChar: bulletChar,
          textAlign: textAlign,
          defaultFontSizePt: defaultFontSizePt,
          defaultColor: defaultColor,
          leftMarginEmu: marL,
          indentEmu: indent,
        ),
      );
    }

    return _TextBodyInfo(
      paragraphs: paragraphs,
      paddingEmu: paddingEmu,
      verticalAnchor: anchor,
      backgroundColor: backgroundColor,
    );
  }

  _RunStyle _parseRunStyle(xml.XmlElement rOrFld) {
    final xml.XmlElement? rPr = _firstByLocalName(rOrFld, 'rPr');
    if (rPr == null) {
      return const _RunStyle(
        fontSizePt: null,
        isBold: false,
        isItalic: false,
        isUnderline: false,
        color: null,
        fontFamily: null,
      );
    }

    final String? szStr = _attrLocal(rPr, 'sz');
    double? fontSizePt;
    if (szStr != null) {
      final int? sz = int.tryParse(szStr);
      if (sz != null && sz > 0) {
        fontSizePt = sz / 100.0;
      }
    }

    final String? bStr = _attrLocal(rPr, 'b');
    final String? iStr = _attrLocal(rPr, 'i');
    final String? uStr = _attrLocal(rPr, 'u');

    final bool isBold = bStr == '1' || bStr == 'true';
    final bool isItalic = iStr == '1' || iStr == 'true';
    final bool isUnderline = uStr != null && uStr.isNotEmpty && uStr != 'none';

    String? fontFamily;
    final xml.XmlElement? latin = _firstByLocalName(rPr, 'latin');
    if (latin != null) {
      final String? tf = _attrLocal(latin, 'typeface');
      if (tf != null && tf.trim().isNotEmpty) {
        fontFamily = tf.trim();
      }
    }

    Color? color;
    final xml.XmlElement? solidFill = _firstByLocalName(rPr, 'solidFill');
    if (solidFill != null) {
      final xml.XmlElement? srgb = _firstByLocalName(solidFill, 'srgbClr');
      if (srgb != null) {
        color = _parseSrgbColor(_attrLocal(srgb, 'val'));
      }
    }

    return _RunStyle(
      fontSizePt: fontSizePt,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      color: color,
      fontFamily: fontFamily,
    );
  }

  String _extractTextFromRun(xml.XmlElement rOrFld) {
    final StringBuffer buffer = StringBuffer();
    for (final xml.XmlElement t in _allByLocalName(rOrFld, 't')) {
      buffer.write(t.text);
    }
    return buffer.toString();
  }

  String? _extractTextFromShape(xml.XmlElement sp) {
    final xml.XmlElement? txBody = _firstByLocalName(sp, 'txBody');
    if (txBody == null) {
      return null;
    }

    final StringBuffer buffer = StringBuffer();
    bool firstP = true;

    for (final xml.XmlNode node in txBody.children) {
      if (node is! xml.XmlElement) {
        continue;
      }
      if (node.name.local != 'p') {
        continue;
      }

      if (!firstP) {
        buffer.write('\n');
      }
      firstP = false;

      for (final xml.XmlElement t in _allByLocalName(node, 't')) {
        buffer.write(t.text);
      }
    }

    return buffer.toString();
  }

  _XfrmRect? _rectFromXfrm(xml.XmlElement xfrm) {
    final xml.XmlElement? off = _firstByLocalName(xfrm, 'off');
    final xml.XmlElement? ext = _firstByLocalName(xfrm, 'ext');
    if (off == null || ext == null) {
      return null;
    }

    final double x = double.tryParse(_attrLocal(off, 'x') ?? '') ?? 0;
    final double y = double.tryParse(_attrLocal(off, 'y') ?? '') ?? 0;
    final double cx = double.tryParse(_attrLocal(ext, 'cx') ?? '') ?? 0;
    final double cy = double.tryParse(_attrLocal(ext, 'cy') ?? '') ?? 0;

    if (cx <= 0 || cy <= 0) {
      return null;
    }

    final String? rotStr = _attrLocal(xfrm, 'rot');
    final int rotRaw = int.tryParse(rotStr ?? '') ?? 0;
    final double rotationRad = (rotRaw / 60000.0) * (math.pi / 180.0);

    final String? flipHStr = _attrLocal(xfrm, 'flipH');
    final String? flipVStr = _attrLocal(xfrm, 'flipV');
    final bool flipH = flipHStr == '1' || flipHStr == 'true';
    final bool flipV = flipVStr == '1' || flipVStr == 'true';

    return _XfrmRect(
      rect: PptxRect(x: x, y: y, cx: cx, cy: cy),
      rotationRad: rotationRad,
      flipH: flipH,
      flipV: flipV,
    );
  }

  Color? _parseBackgroundColor(xml.XmlDocument slideDoc) {
    final xml.XmlElement? bg = _firstByLocalName(slideDoc, 'bg');
    if (bg == null) {
      return null;
    }

    final xml.XmlElement? bgPr = _firstByLocalName(bg, 'bgPr');
    if (bgPr == null) {
      return null;
    }

    final xml.XmlElement? solidFill = _firstByLocalName(bgPr, 'solidFill');
    if (solidFill == null) {
      return null;
    }

    final xml.XmlElement? srgb = _firstByLocalName(solidFill, 'srgbClr');
    if (srgb == null) {
      return null;
    }

    return _parseSrgbColor(_attrLocal(srgb, 'val'));
  }

  Color? _parseSrgbColor(String? hex) {
    if (hex == null) {
      return null;
    }
    final String cleaned = hex.trim();
    if (cleaned.length != 6) {
      return null;
    }
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return null;
    }
    return Color(0xFF000000 | value);
  }

  Map<String, String> _parseRelationships(xml.XmlDocument relsDoc) {
    final Map<String, String> map = <String, String>{};
    for (final xml.XmlElement rel in _allByLocalName(relsDoc, 'Relationship')) {
      final String? id = _attrLocal(rel, 'Id');
      final String? target = _attrLocal(rel, 'Target');
      if (id != null && target != null) {
        map[id] = target;
      }
    }
    return map;
  }

  String _resolvePath(String baseDir, String target) {
    final Uri base = Uri(path: baseDir);
    final String resolved = base.resolve(target).path;
    String cleaned = resolved;
    while (cleaned.startsWith('/')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  String _asUtf8String(ArchiveFile f) {
    final Object? c = f.content;
    if (c is List<int>) {
      return utf8.decode(c);
    }
    if (c is String) {
      return c;
    }
    return '';
  }

  Uint8List _asBytes(ArchiveFile f) {
    final Object? c = f.content;
    if (c is Uint8List) {
      return c;
    }
    if (c is List<int>) {
      return Uint8List.fromList(c);
    }
    if (c is String) {
      return Uint8List.fromList(utf8.encode(c));
    }
    return Uint8List(0);
  }

  xml.XmlElement? _firstByLocalName(xml.XmlNode node, String local) {
    for (final xml.XmlElement e
        in node.descendants.whereType<xml.XmlElement>()) {
      if (e.name.local == local) {
        return e;
      }
    }
    return null;
  }

  Iterable<xml.XmlElement> _allByLocalName(
    xml.XmlNode node,
    String local,
  ) sync* {
    for (final xml.XmlElement e
        in node.descendants.whereType<xml.XmlElement>()) {
      if (e.name.local == local) {
        yield e;
      }
    }
  }

  xml.XmlElement? _firstChildByLocalName(xml.XmlElement node, String local) {
    for (final xml.XmlNode c in node.children) {
      if (c is! xml.XmlElement) {
        continue;
      }
      if (c.name.local == local) {
        return c;
      }
    }
    return null;
  }

  String? _attrLocal(xml.XmlElement element, String local, {String? prefix}) {
    for (final xml.XmlAttribute a in element.attributes) {
      if (a.name.local != local) {
        continue;
      }
      if (prefix != null && a.name.prefix != prefix) {
        continue;
      }
      return a.value;
    }
    return element.getAttribute(local);
  }

  _XfrmInfo _parseXfrm(xml.XmlElement xfrm) {
    double offX = 0;
    double offY = 0;
    double extX = 0;
    double extY = 0;

    double chOffX = 0;
    double chOffY = 0;
    double chExtX = 0;
    double chExtY = 0;

    final xml.XmlElement? off = _firstByLocalName(xfrm, 'off');
    if (off != null) {
      offX = double.tryParse(_attrLocal(off, 'x') ?? '') ?? 0;
      offY = double.tryParse(_attrLocal(off, 'y') ?? '') ?? 0;
    }

    final xml.XmlElement? ext = _firstByLocalName(xfrm, 'ext');
    if (ext != null) {
      extX = double.tryParse(_attrLocal(ext, 'cx') ?? '') ?? 0;
      extY = double.tryParse(_attrLocal(ext, 'cy') ?? '') ?? 0;
    }

    final xml.XmlElement? chOff = _firstByLocalName(xfrm, 'chOff');
    if (chOff != null) {
      chOffX = double.tryParse(_attrLocal(chOff, 'x') ?? '') ?? 0;
      chOffY = double.tryParse(_attrLocal(chOff, 'y') ?? '') ?? 0;
    }

    final xml.XmlElement? chExt = _firstByLocalName(xfrm, 'chExt');
    if (chExt != null) {
      chExtX = double.tryParse(_attrLocal(chExt, 'cx') ?? '') ?? 0;
      chExtY = double.tryParse(_attrLocal(chExt, 'cy') ?? '') ?? 0;
    }

    return _XfrmInfo(
      offX: offX,
      offY: offY,
      extX: extX,
      extY: extY,
      chOffX: chOffX,
      chOffY: chOffY,
      chExtX: chExtX,
      chExtY: chExtY,
    );
  }
}

class _SlideParseResult {
  final String? title;
  final Color? backgroundColor;
  final List<PptxSlideElement> elements;

  _SlideParseResult({
    required this.title,
    required this.backgroundColor,
    required this.elements,
  });
}

class _XfrmInfo {
  final double offX;
  final double offY;
  final double extX;
  final double extY;
  final double chOffX;
  final double chOffY;
  final double chExtX;
  final double chExtY;

  const _XfrmInfo({
    required this.offX,
    required this.offY,
    required this.extX,
    required this.extY,
    required this.chOffX,
    required this.chOffY,
    required this.chExtX,
    required this.chExtY,
  });
}

class _XfrmRect {
  final PptxRect rect;
  final double rotationRad;
  final bool flipH;
  final bool flipV;

  const _XfrmRect({
    required this.rect,
    required this.rotationRad,
    required this.flipH,
    required this.flipV,
  });
}

class _TextBodyInfo {
  final List<PptxParagraph> paragraphs;
  final PptxPaddingEmu paddingEmu;
  final PptxVerticalAnchor verticalAnchor;
  final Color? backgroundColor;

  _TextBodyInfo({
    required this.paragraphs,
    required this.paddingEmu,
    required this.verticalAnchor,
    required this.backgroundColor,
  });
}

class _RunStyle {
  final double? fontSizePt;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final Color? color;
  final String? fontFamily;

  const _RunStyle({
    required this.fontSizePt,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.color,
    required this.fontFamily,
  });
}

class _PptxTransform {
  final double offsetX;
  final double offsetY;
  final double originX;
  final double originY;
  final double scaleX;
  final double scaleY;

  const _PptxTransform({
    required this.offsetX,
    required this.offsetY,
    required this.originX,
    required this.originY,
    required this.scaleX,
    required this.scaleY,
  });

  static const _PptxTransform identity = _PptxTransform(
    offsetX: 0,
    offsetY: 0,
    originX: 0,
    originY: 0,
    scaleX: 1,
    scaleY: 1,
  );

  double applyX(double x) {
    return offsetX + (x - originX) * scaleX;
  }

  double applyY(double y) {
    return offsetY + (y - originY) * scaleY;
  }

  PptxRect applyRect(PptxRect r) {
    return PptxRect(
      x: applyX(r.x),
      y: applyY(r.y),
      cx: r.cx * scaleX,
      cy: r.cy * scaleY,
    );
  }
}
