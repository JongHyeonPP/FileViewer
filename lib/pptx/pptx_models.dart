// lib/pptx/pptx_models.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

class PptxPresentationData {
  final int slideWidthEmu;
  final int slideHeightEmu;
  final List<PptxSlideData> slides;

  PptxPresentationData({
    required this.slideWidthEmu,
    required this.slideHeightEmu,
    required this.slides,
  });
}

class PptxSlideData {
  final int index;
  final String? title;
  final Color? backgroundColor;
  final List<PptxSlideElement> elements;

  PptxSlideData({
    required this.index,
    required this.title,
    required this.backgroundColor,
    required this.elements,
  });
}

class PptxRect {
  final double x;
  final double y;
  final double cx;
  final double cy;

  const PptxRect({
    required this.x,
    required this.y,
    required this.cx,
    required this.cy,
  });
}

abstract class PptxSlideElement {
  final PptxRect rect;

  const PptxSlideElement({
    required this.rect,
  });
}

class PptxCropRect {
  final double l;
  final double t;
  final double r;
  final double b;

  const PptxCropRect({
    required this.l,
    required this.t,
    required this.r,
    required this.b,
  });

  static const none = PptxCropRect(l: 0, t: 0, r: 0, b: 0);

  bool get isNone => l == 0 && t == 0 && r == 0 && b == 0;
}

class PptxPicture extends PptxSlideElement {
  final Uint8List bytes;
  final double rotationRad;
  final bool flipH;
  final bool flipV;
  final PptxCropRect crop;

  const PptxPicture({
    required super.rect,
    required this.bytes,
    required this.rotationRad,
    required this.flipH,
    required this.flipV,
    required this.crop,
  });
}

enum PptxVerticalAnchor {
  top,
  center,
  bottom,
}

class PptxPaddingEmu {
  final double l;
  final double t;
  final double r;
  final double b;

  const PptxPaddingEmu({
    required this.l,
    required this.t,
    required this.r,
    required this.b,
  });

  static const zero = PptxPaddingEmu(l: 0, t: 0, r: 0, b: 0);
}

class PptxTextBox extends PptxSlideElement {
  final List<PptxParagraph> paragraphs;
  final TextAlign textAlign;
  final PptxPaddingEmu paddingEmu;
  final PptxVerticalAnchor verticalAnchor;
  final Color? backgroundColor;

  const PptxTextBox({
    required super.rect,
    required this.paragraphs,
    required this.textAlign,
    required this.paddingEmu,
    required this.verticalAnchor,
    required this.backgroundColor,
  });
}

class PptxParagraph {
  final List<PptxRun> runs;
  final String? bulletChar;
  final TextAlign textAlign;
  final double defaultFontSizePt;
  final Color? defaultColor;
  final double leftMarginEmu;
  final double indentEmu;

  const PptxParagraph({
    required this.runs,
    required this.bulletChar,
    required this.textAlign,
    required this.defaultFontSizePt,
    required this.defaultColor,
    required this.leftMarginEmu,
    required this.indentEmu,
  });
}

class PptxRun {
  final String text;
  final double fontSizePt;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final Color? color;
  final String? fontFamily;

  const PptxRun({
    required this.text,
    required this.fontSizePt,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.color,
    required this.fontFamily,
  });
}
