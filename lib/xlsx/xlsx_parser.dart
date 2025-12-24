// lib/xlsx/xlsx_parser.dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;

import 'xlsx_models.dart';

class XlsxParser {
  Future<List<XlsxSheetData>> loadAllSheetsFromXlsx(String path) async {
    final File file = File(path);
    final List<int> bytes = await file.readAsBytes();
    final Archive archive = ZipDecoder().decodeBytes(bytes);

    final Map<String, ArchiveFile> fileMap = <String, ArchiveFile>{};
    for (final ArchiveFile f in archive.files) {
      fileMap[f.name] = f;
    }

    final ArchiveFile? sharedStringsFile = fileMap['xl/sharedStrings.xml'];
    final ArchiveFile? workbookFile = fileMap['xl/workbook.xml'];
    final ArchiveFile? relsFile = fileMap['xl/_rels/workbook.xml.rels'];
    final ArchiveFile? stylesFile = fileMap['xl/styles.xml'];

    final Map<String, ArchiveFile> worksheetFiles = <String, ArchiveFile>{};
    for (final ArchiveFile f in archive.files) {
      if (f.name.startsWith('xl/worksheets/')) {
        worksheetFiles[f.name] = f;
      }
    }

    final List<String> sharedStrings = _parseSharedStrings(sharedStringsFile);
    final List<XlsxCellStyle> cellStyles = _parseCellStyles(stylesFile);

    final List<_XlsxSheetRef> sheetRefs = _parseSheetRefs(
      workbookFile: workbookFile,
      relsFile: relsFile,
      worksheetFiles: worksheetFiles,
    );

    final List<XlsxSheetData> result = <XlsxSheetData>[];
    final List<String> sortedWorksheetKeys = worksheetFiles.keys.toList()
      ..sort();

    for (int i = 0; i < sheetRefs.length; i += 1) {
      final _XlsxSheetRef ref = sheetRefs[i];

      ArchiveFile? sheetFile;
      if (ref.sheetPath != null) {
        sheetFile = fileMap[ref.sheetPath!];
      }

      if (sheetFile == null && sortedWorksheetKeys.isNotEmpty) {
        if (i >= 0 && i < sortedWorksheetKeys.length) {
          sheetFile = worksheetFiles[sortedWorksheetKeys[i]];
        } else {
          sheetFile = worksheetFiles[sortedWorksheetKeys.first];
        }
      }

      if (sheetFile == null) {
        continue;
      }

      final List<List<XlsxCell>> rows = _parseSheetRows(
        sheetFile: sheetFile,
        sharedStrings: sharedStrings,
        cellStyles: cellStyles,
      );

      result.add(XlsxSheetData(sheetName: ref.sheetName, rows: rows));
    }

    if (result.isEmpty) {
      result.add(XlsxSheetData(sheetName: 'Sheet1', rows: <List<XlsxCell>>[]));
    }

    return result;
  }

  List<String> _parseSharedStrings(ArchiveFile? sharedStringsFile) {
    if (sharedStringsFile == null) {
      return <String>[];
    }

    try {
      final String xmlString = utf8.decode(
        sharedStringsFile.content as List<int>,
      );
      final xml.XmlDocument doc = xml.XmlDocument.parse(xmlString);

      final List<String> sharedStrings = <String>[];
      for (final xml.XmlElement si in doc.findAllElements('si')) {
        final StringBuffer buffer = StringBuffer();
        for (final xml.XmlElement t
            in si.descendants.whereType<xml.XmlElement>()) {
          if (t.name.local == 't') {
            buffer.write(t.text);
          }
        }
        sharedStrings.add(buffer.toString());
      }
      return sharedStrings;
    } catch (_) {
      return <String>[];
    }
  }

  List<XlsxCellStyle> _parseCellStyles(ArchiveFile? stylesFile) {
    if (stylesFile == null) {
      return <XlsxCellStyle>[];
    }

    try {
      final String stylesXml = utf8.decode(stylesFile.content as List<int>);
      final xml.XmlDocument doc = xml.XmlDocument.parse(stylesXml);

      xml.XmlElement? cellXfsElem;
      for (final xml.XmlElement e in doc.findAllElements('cellXfs')) {
        cellXfsElem = e;
        break;
      }
      if (cellXfsElem == null) {
        return <XlsxCellStyle>[];
      }

      final List<XlsxCellStyle> result = <XlsxCellStyle>[];
      final Iterable<xml.XmlElement> xfElements = cellXfsElem.findAllElements(
        'xf',
      );

      for (final xml.XmlElement xf in xfElements) {
        XlsxHorizontalAlign align = XlsxHorizontalAlign.general;

        final String? applyAlignmentAttr = xf.getAttribute('applyAlignment');
        final bool applyAlignment =
            applyAlignmentAttr == null || applyAlignmentAttr == '1';

        if (applyAlignment) {
          xml.XmlElement? alignmentElem;
          for (final xml.XmlNode n in xf.children) {
            if (n is xml.XmlElement && n.name.local == 'alignment') {
              alignmentElem = n;
              break;
            }
          }

          if (alignmentElem != null) {
            final String? horizontal = alignmentElem.getAttribute('horizontal');
            if (horizontal != null) {
              switch (horizontal) {
                case 'center':
                case 'centerContinuous':
                case 'distributed':
                case 'justifyDistributed':
                  align = XlsxHorizontalAlign.center;
                  break;
                case 'right':
                case 'justify':
                  align = XlsxHorizontalAlign.right;
                  break;
                case 'left':
                default:
                  align = XlsxHorizontalAlign.left;
                  break;
              }
            }
          }
        }

        result.add(XlsxCellStyle(horizontalAlign: align));
      }

      return result;
    } catch (_) {
      return <XlsxCellStyle>[];
    }
  }

  List<_XlsxSheetRef> _parseSheetRefs({
    required ArchiveFile? workbookFile,
    required ArchiveFile? relsFile,
    required Map<String, ArchiveFile> worksheetFiles,
  }) {
    final List<_XlsxSheetRef> sheetRefs = <_XlsxSheetRef>[];

    if (workbookFile != null && relsFile != null) {
      try {
        final String workbookXml = utf8.decode(
          workbookFile.content as List<int>,
        );
        final xml.XmlDocument workbookDoc = xml.XmlDocument.parse(workbookXml);

        final String relsXml = utf8.decode(relsFile.content as List<int>);
        final xml.XmlDocument relsDoc = xml.XmlDocument.parse(relsXml);

        final Map<String, String> relMap = <String, String>{};
        for (final xml.XmlElement rel in relsDoc.findAllElements(
          'Relationship',
        )) {
          final String? id = rel.getAttribute('Id');
          final String? target = rel.getAttribute('Target');
          if (id != null && target != null) {
            relMap[id] = target;
          }
        }

        for (final xml.XmlElement sheetElem in workbookDoc.findAllElements(
          'sheet',
        )) {
          final String sheetName = sheetElem.getAttribute('name') ?? 'Sheet';
          final String? rId = _attrWithPrefix(sheetElem, 'id', 'r');

          String? sheetPath;
          if (rId != null) {
            final String? target = relMap[rId];
            if (target != null && target.trim().isNotEmpty) {
              sheetPath = _normalizeXlTarget(target.trim());
            }
          }

          sheetRefs.add(
            _XlsxSheetRef(sheetName: sheetName, sheetPath: sheetPath),
          );
        }
      } catch (_) {}
    }

    if (sheetRefs.isEmpty && worksheetFiles.isNotEmpty) {
      final List<String> keys = worksheetFiles.keys.toList()..sort();
      for (int i = 0; i < keys.length; i += 1) {
        sheetRefs.add(
          _XlsxSheetRef(sheetName: 'Sheet${i + 1}', sheetPath: keys[i]),
        );
      }
    }

    return sheetRefs;
  }

  List<List<XlsxCell>> _parseSheetRows({
    required ArchiveFile sheetFile,
    required List<String> sharedStrings,
    required List<XlsxCellStyle> cellStyles,
  }) {
    final String sheetXml = utf8.decode(sheetFile.content as List<int>);
    final xml.XmlDocument sheetDoc = xml.XmlDocument.parse(sheetXml);

    xml.XmlElement? sheetData;
    for (final xml.XmlElement e in sheetDoc.findAllElements('sheetData')) {
      sheetData = e;
      break;
    }
    if (sheetData == null) {
      return <List<XlsxCell>>[];
    }

    final List<List<XlsxCell>> rows = <List<XlsxCell>>[];
    final Iterable<xml.XmlElement> rowElements = sheetData.findAllElements(
      'row',
    );

    for (final xml.XmlElement rowElem in rowElements) {
      final Map<int, XlsxCell> cellMap = <int, XlsxCell>{};
      int maxColIndex = -1;

      final Iterable<xml.XmlElement> cellElements = rowElem.findAllElements(
        'c',
      );
      for (final xml.XmlElement c in cellElements) {
        final String? ref = c.getAttribute('r');
        if (ref == null) {
          continue;
        }

        final int colIndex = _columnIndexFromRef(ref);
        if (colIndex < 0) {
          continue;
        }

        final String? type = c.getAttribute('t');

        String value = '';
        final xml.XmlElement? vElem = _firstChildElementByLocalName(c, 'v');

        if (type == 's') {
          if (vElem != null) {
            final String raw = vElem.text;
            final int idx = int.tryParse(raw) ?? -1;
            if (idx >= 0 && idx < sharedStrings.length) {
              value = sharedStrings[idx];
            } else {
              value = raw;
            }
          }
        } else if (type == 'inlineStr') {
          value = _extractInlineStringFromCell(c);
        } else {
          if (vElem != null) {
            value = vElem.text;
          } else {
            final xml.XmlElement? isElem = _firstChildElementByLocalName(
              c,
              'is',
            );
            if (isElem != null) {
              value = _extractInlineStringFromCell(c);
            }
          }
        }

        XlsxHorizontalAlign align = XlsxHorizontalAlign.general;
        final String? styleIndexStr = c.getAttribute('s');
        if (styleIndexStr != null) {
          final int styleIndex = int.tryParse(styleIndexStr) ?? -1;
          if (styleIndex >= 0 && styleIndex < cellStyles.length) {
            align = cellStyles[styleIndex].horizontalAlign;
          }
        }

        cellMap[colIndex] = XlsxCell(text: value, horizontalAlign: align);

        if (colIndex > maxColIndex) {
          maxColIndex = colIndex;
        }
      }

      if (maxColIndex < 0) {
        rows.add(<XlsxCell>[]);
        continue;
      }

      final List<XlsxCell> rowValues = List<XlsxCell>.filled(
        maxColIndex + 1,
        XlsxCell.empty,
      );
      cellMap.forEach((int col, XlsxCell v) {
        if (col >= 0 && col < rowValues.length) {
          rowValues[col] = v;
        }
      });

      rows.add(rowValues);
    }

    return rows;
  }

  String _extractInlineStringFromCell(xml.XmlElement cell) {
    final xml.XmlElement? isElem = _firstChildElementByLocalName(cell, 'is');
    if (isElem == null) {
      return '';
    }

    final StringBuffer buffer = StringBuffer();
    for (final xml.XmlElement t
        in isElem.descendants.whereType<xml.XmlElement>()) {
      if (t.name.local == 't') {
        buffer.write(t.text);
      }
    }
    return buffer.toString();
  }

  xml.XmlElement? _firstChildElementByLocalName(
    xml.XmlElement parent,
    String local,
  ) {
    for (final xml.XmlNode n in parent.children) {
      if (n is xml.XmlElement && n.name.local == local) {
        return n;
      }
    }
    return null;
  }

  String? _attrWithPrefix(xml.XmlElement element, String local, String prefix) {
    for (final xml.XmlAttribute a in element.attributes) {
      if (a.name.local == local && a.name.prefix == prefix) {
        return a.value;
      }
    }
    return null;
  }

  String _normalizeXlTarget(String target) {
    String t = target.trim();
    while (t.startsWith('/')) {
      t = t.substring(1);
    }
    if (t.startsWith('xl/')) {
      return t;
    }
    return 'xl/$t';
  }

  int _columnIndexFromRef(String ref) {
    final RegExp exp = RegExp(r'^[A-Z]+');
    final RegExpMatch? match = exp.firstMatch(ref);
    if (match == null) {
      return -1;
    }

    final String letters = match.group(0)!;
    int index = 0;
    for (int i = 0; i < letters.length; i += 1) {
      final int codeUnit = letters.codeUnitAt(i) - 'A'.codeUnitAt(0) + 1;
      index = index * 26 + codeUnit;
    }
    return index - 1;
  }
}

class _XlsxSheetRef {
  final String sheetName;
  final String? sheetPath;

  const _XlsxSheetRef({required this.sheetName, required this.sheetPath});
}
