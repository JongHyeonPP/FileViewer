// lib/xlsx/xlsx_zoom_controls.dart
import 'package:flutter/material.dart';

class XlsxZoomOverlayChip extends StatelessWidget {
  final double zoom;
  final bool visible;

  const XlsxZoomOverlayChip({
    super.key,
    required this.zoom,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 260),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${(zoom * 100).round()}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class XlsxZoomButtonBar extends StatelessWidget {
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;

  const XlsxZoomButtonBar({
    super.key,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  @override
  Widget build(BuildContext context) {
    const double buttonWidth = 32;
    const double buttonHeight = 30;
    const double iconSize = 16;

    Widget buildIcon(IconData icon) {
      return Icon(
        icon,
        size: iconSize,
        color: Colors.black87,
      );
    }

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.70),
            border: Border.all(
              color: Colors.black.withOpacity(0.32),
              width: 1.3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              InkWell(
                onTap: onZoomOut,
                child: SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: Center(child: buildIcon(Icons.remove)),
                ),
              ),
              Container(
                width: 1,
                height: 18,
                color: Colors.black.withOpacity(0.22),
              ),
              InkWell(
                onTap: onZoomIn,
                child: SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: Center(child: buildIcon(Icons.add)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class XlsxZoomSidebarPanel extends StatelessWidget {
  final double zoom;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;

  const XlsxZoomSidebarPanel({
    super.key,
    required this.zoom,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.black.withOpacity(0.20),
              width: 1.0,
            ),
          ),
          child: Text(
            '${(zoom * 100).round()}%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 10),
        XlsxZoomButtonBar(
          onZoomOut: onZoomOut,
          onZoomIn: onZoomIn,
        ),
      ],
    );
  }
}
