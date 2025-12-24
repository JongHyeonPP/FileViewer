import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'pptx_models.dart';
import 'pptx_parser.dart';

class PptxSlideWidget extends StatelessWidget {
  final PptxPresentationData presentation;
  final PptxSlideData slide;
  final bool isThumbnail;

  const PptxSlideWidget({
    super.key,
    required this.presentation,
    required this.slide,
    required this.isThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth;
        final double maxH = constraints.maxHeight;

        final double slideW = presentation.slideWidthEmu.toDouble();
        final double slideH = presentation.slideHeightEmu.toDouble();

        if (slideW <= 0 || slideH <= 0 || maxW <= 0 || maxH <= 0) {
          return const SizedBox.shrink();
        }

        final double containScale = math.min(maxW / slideW, maxH / slideH);
        final double coverScale = math.max(maxW / slideW, maxH / slideH);

        final double scale = isThumbnail ? coverScale : containScale;

        final double renderW = slideW * scale;
        final double renderH = slideH * scale;

        final double offsetX = (maxW - renderW) / 2.0;
        final double offsetY = (maxH - renderH) / 2.0;

        return SizedBox(
          width: maxW,
          height: maxH,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                Positioned.fill(
                  child: ColoredBox(
                    color: slide.backgroundColor ?? Colors.white,
                  ),
                ),
                for (final PptxSlideElement element in slide.elements)
                  _buildElement(
                    element: element,
                    scale: scale,
                    offsetX: offsetX,
                    offsetY: offsetY,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildElement({
    required PptxSlideElement element,
    required double scale,
    required double offsetX,
    required double offsetY,
  }) {
    final double left = offsetX + element.rect.x * scale;
    final double top = offsetY + element.rect.y * scale;
    final double width = element.rect.cx * scale;
    final double height = element.rect.cy * scale;

    if (element is PptxPicture) {
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: _buildPicture(pic: element, width: width, height: height),
      );
    }

    if (element is PptxTextBox) {
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: _buildTextBox(
          textBox: element,
          scale: scale,
          width: width,
          height: height,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPicture({
    required PptxPicture pic,
    required double width,
    required double height,
  }) {
    Widget child = SizedBox(
      width: width,
      height: height,
      child: Image.memory(
        pic.bytes,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        filterQuality: isThumbnail ? FilterQuality.high : FilterQuality.medium,
      ),
    );

    if (!pic.crop.isNone) {
      final double visibleW = (1.0 - pic.crop.l - pic.crop.r).clamp(
        0.0001,
        1.0,
      );
      final double visibleH = (1.0 - pic.crop.t - pic.crop.b).clamp(
        0.0001,
        1.0,
      );

      final double scaleX = 1.0 / visibleW;
      final double scaleY = 1.0 / visibleH;

      final double dx = -pic.crop.l * width * scaleX;
      final double dy = -pic.crop.t * height * scaleY;

      child = ClipRect(
        child: Transform(
          alignment: Alignment.topLeft,
          transform: Matrix4.identity()
            ..translate(dx, dy)
            ..scale(scaleX, scaleY),
          child: child,
        ),
      );
    }

    final bool hasFlip = pic.flipH || pic.flipV;
    final bool hasRotate = pic.rotationRad != 0;

    if (hasFlip || hasRotate) {
      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(pic.rotationRad)
          ..scale(pic.flipH ? -1.0 : 1.0, pic.flipV ? -1.0 : 1.0),
        child: child,
      );
    }

    return child;
  }

  Widget _buildTextBox({
    required PptxTextBox textBox,
    required double scale,
    required double width,
    required double height,
  }) {
    final double padL = textBox.paddingEmu.l * scale;
    final double padT = textBox.paddingEmu.t * scale;
    final double padR = textBox.paddingEmu.r * scale;
    final double padB = textBox.paddingEmu.b * scale;

    final Alignment boxAlign =
        textBox.verticalAnchor == PptxVerticalAnchor.center
        ? Alignment.centerLeft
        : textBox.verticalAnchor == PptxVerticalAnchor.bottom
        ? Alignment.bottomLeft
        : Alignment.topLeft;

    final List<InlineSpan> spans = <InlineSpan>[];
    bool firstParagraph = true;

    for (final PptxParagraph p in textBox.paragraphs) {
      if (!firstParagraph) {
        spans.add(const TextSpan(text: '\n'));
      }
      firstParagraph = false;

      final double indentPx =
          (p.leftMarginEmu + math.max(0, p.indentEmu)) * scale;
      if (indentPx > 0) {
        spans.add(WidgetSpan(child: SizedBox(width: indentPx)));
      }

      if (p.bulletChar != null && p.bulletChar!.isNotEmpty) {
        spans.add(
          TextSpan(
            text: '${p.bulletChar} ',
            style: TextStyle(
              fontSize: _ptToCanvasPx(
                p.defaultFontSizePt,
                scale,
              ).clamp(1.0, 500.0),
              height: 1.2,
              color: p.defaultColor ?? Colors.black,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }

      for (final PptxRun r in p.runs) {
        final double pt = r.fontSizePt > 0 ? r.fontSizePt : p.defaultFontSizePt;

        spans.add(
          TextSpan(
            text: r.text,
            style: TextStyle(
              fontSize: _ptToCanvasPx(pt, scale).clamp(1.0, 500.0),
              height: 1.2,
              fontWeight: r.isBold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: r.isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: r.isUnderline
                  ? TextDecoration.underline
                  : TextDecoration.none,
              color: r.color ?? p.defaultColor ?? Colors.black,
              fontFamily: r.fontFamily,
            ),
          ),
        );
      }
    }

    final Widget rich = RichText(
      text: TextSpan(
        children: spans.isEmpty
            ? <InlineSpan>[const TextSpan(text: '')]
            : spans,
      ),
      textAlign: textBox.textAlign,
      softWrap: true,
      overflow: TextOverflow.visible,
    );

    return Container(
      color: textBox.backgroundColor ?? Colors.transparent,
      padding: EdgeInsets.fromLTRB(padL, padT, padR, padB),
      child: Align(
        alignment: boxAlign,
        child: OverflowBox(
          alignment: boxAlign,
          minWidth: width,
          maxWidth: width,
          minHeight: 0,
          maxHeight: double.infinity,
          child: rich,
        ),
      ),
    );
  }

  double _ptToCanvasPx(double pt, double slideScale) {
    return pt * PptxParser.emuPerPt * slideScale;
  }
}
