// lib/xlsx/xlsx_models.dart
import 'package:flutter/foundation.dart';

enum XlsxHorizontalAlign { left, center, right, general }

@immutable
class XlsxCellStyle {
  final XlsxHorizontalAlign horizontalAlign;

  const XlsxCellStyle({required this.horizontalAlign});

  static const XlsxCellStyle general = XlsxCellStyle(
    horizontalAlign: XlsxHorizontalAlign.general,
  );
}

@immutable
class XlsxCell {
  final String text;
  final XlsxHorizontalAlign horizontalAlign;

  const XlsxCell({required this.text, required this.horizontalAlign});

  static const XlsxCell empty = XlsxCell(
    text: '',
    horizontalAlign: XlsxHorizontalAlign.general,
  );

  bool get isEmpty => text.isEmpty;
}

@immutable
class XlsxSheetData {
  final String sheetName;
  final List<List<XlsxCell>> rows;

  const XlsxSheetData({required this.sheetName, required this.rows});
}
