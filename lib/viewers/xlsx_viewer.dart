// lib/viewers/xlsx_viewer.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart' as xml;

import '../services/file_service.dart';

// 셀 가로 정렬 종류
enum XlsxHorizontalAlign {
  left,
  center,
  right,
  general,
}

// 스타일 한 개가 가지는 정보
class XlsxCellStyle {
  final XlsxHorizontalAlign horizontalAlign;

  const XlsxCellStyle({
    required this.horizontalAlign,
  });

  static const XlsxCellStyle general = XlsxCellStyle(
    horizontalAlign: XlsxHorizontalAlign.general,
  );
}

// 실제 셀 데이터
class XlsxCell {
  final String text;
  final XlsxHorizontalAlign horizontalAlign;

  const XlsxCell({
    required this.text,
    required this.horizontalAlign,
  });

  static const XlsxCell empty = XlsxCell(
    text: '',
    horizontalAlign: XlsxHorizontalAlign.general,
  );

  bool get isEmpty {
    return text.isEmpty;
  }
}

// 시트 한 개의 데이터
class XlsxSheetData {
  final String sheetName;
  final List<List<XlsxCell>> rows;

  XlsxSheetData({
    required this.sheetName,
    required this.rows,
  });
}

class XlsxViewer extends StatefulWidget {
  final ViewerFile file;

  const XlsxViewer({
    super.key,
    required this.file,
  });

  @override
  State<XlsxViewer> createState() => _XlsxViewerState();
}

class _XlsxViewerState extends State<XlsxViewer> {
  late Future<List<XlsxSheetData>> _future;
  int _selectedSheetIndex = 0;

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  bool _showHorizontalBar = false;
  Timer? _horizontalBarTimer;

  Color get _scrollThumbColor {
    return Colors.grey.shade600;
  }

  @override
  void initState() {
    super.initState();
    _future = _loadAllSheetsFromXlsx(widget.file.path);
  }

  @override
  void didUpdateWidget(covariant XlsxViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _selectedSheetIndex = 0;
      _future = _loadAllSheetsFromXlsx(widget.file.path);
    }
  }

  @override
  void dispose() {
    _horizontalBarTimer?.cancel();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _onUserHorizontalScroll() {
    if (!_showHorizontalBar) {
      setState(() {
        _showHorizontalBar = true;
      });
    }

    _horizontalBarTimer?.cancel();
    _horizontalBarTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showHorizontalBar = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XlsxSheetData>>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<List<XlsxSheetData>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '엑셀 파일을 불러오는 중 오류가 발생했습니다',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        }

        final List<XlsxSheetData> sheets = snapshot.data ?? <XlsxSheetData>[];
        if (sheets.isEmpty) {
          return const Center(
            child: Text(
              '시트가 비어 있습니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          );
        }

        if (_selectedSheetIndex < 0 || _selectedSheetIndex >= sheets.length) {
          _selectedSheetIndex = 0;
        }

        final XlsxSheetData currentSheet = sheets[_selectedSheetIndex];
        return _buildSheetView(context, sheets, currentSheet);
      },
    );
  }

  Widget _buildSheetView(
      BuildContext context,
      List<XlsxSheetData> sheets,
      XlsxSheetData data,
      ) {
    final List<List<XlsxCell>> rows = data.rows;
    int columnCount = 0;
    for (final List<XlsxCell> row in rows) {
      if (row.length > columnCount) {
        columnCount = row.length;
      }
    }

    if (columnCount == 0 || rows.isEmpty) {
      return Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: Text(
                '내용이 없는 시트입니다',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
          _buildSheetTabs(sheets),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _buildGrid(rows, columnCount),
        ),
        _buildSheetTabs(sheets),
      ],
    );
  }

  Widget _buildSheetTabs(List<XlsxSheetData> sheets) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FF),
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 0.8,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: sheets.length,
        itemBuilder: (BuildContext context, int index) {
          final bool selected = index == _selectedSheetIndex;
          final XlsxSheetData sheet = sheets[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                if (!selected) {
                  setState(() {
                    _selectedSheetIndex = index;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFFFFFF) : const Color(0xFFF0E6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? const Color(0xFF7C4DFF) : Colors.grey.shade400,
                    width: selected ? 1.3 : 1.0,
                  ),
                  boxShadow: selected
                      ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                      : <BoxShadow>[],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.grid_on,
                      size: 13,
                      color: selected ? const Color(0xFF5E35B1) : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sheet.sheetName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? const Color(0xFF5E35B1) : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<List<XlsxCell>> rows, int columnCount) {
    const double cellWidth = 90;
    final List<TableRow> tableRows = <TableRow>[];

    final List<Widget> headerCells = <Widget>[];
    headerCells.add(_buildCornerHeaderCell());
    for (int c = 0; c < columnCount; c += 1) {
      headerCells.add(
        _buildHeaderCell(_columnLabel(c)),
      );
    }
    tableRows.add(
      TableRow(
        children: headerCells,
      ),
    );

    for (int r = 0; r < rows.length; r += 1) {
      final List<XlsxCell> row = rows[r];
      final List<Widget> rowCells = <Widget>[];

      rowCells.add(
        _buildRowHeaderCell((r + 1).toString()),
      );

      for (int c = 0; c < columnCount; c += 1) {
        final XlsxCell cell = c < row.length ? row[c] : XlsxCell.empty;
        rowCells.add(
          _buildDataCell(cell),
        );
      }

      tableRows.add(
        TableRow(
          children: rowCells,
        ),
      );
    }

    return Stack(
      children: <Widget>[
        RawScrollbar(
          controller: _verticalController,
          thumbColor: _scrollThumbColor,
          radius: const Radius.circular(3),
          thickness: 4,
          notificationPredicate: (ScrollNotification notification) {
            return notification.metrics.axis == Axis.vertical;
          },
          child: SingleChildScrollView(
            controller: _verticalController,
            scrollDirection: Axis.vertical,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification.metrics.axis == Axis.horizontal && notification is ScrollUpdateNotification) {
                  _onUserHorizontalScroll();
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: cellWidth * (columnCount + 1),
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(cellWidth),
                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                      width: 0.5,
                    ),
                    children: tableRows,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_showHorizontalBar)
          Positioned(
            left: 8,
            right: 8,
            bottom: 2,
            child: _buildHorizontalIndicator(),
          ),
      ],
    );
  }

  Widget _buildHorizontalIndicator() {
    return AnimatedBuilder(
      animation: _horizontalController,
      builder: (BuildContext context, Widget? child) {
        if (!_horizontalController.hasClients) {
          return const SizedBox.shrink();
        }

        final ScrollPosition position = _horizontalController.position;
        if (position.maxScrollExtent <= 0) {
          return const SizedBox.shrink();
        }

        final double viewport = position.viewportDimension;
        final double maxScrollExtent = position.maxScrollExtent;
        final double content = viewport + maxScrollExtent;

        double thumbFraction = viewport / content;
        if (thumbFraction < 0.1) {
          thumbFraction = 0.1;
        } else if (thumbFraction > 1.0) {
          thumbFraction = 1.0;
        }

        final double scrollFraction = maxScrollExtent == 0 ? 0 : position.pixels / maxScrollExtent;
        final double thumbLeftFraction = (scrollFraction * (1 - thumbFraction)).clamp(0.0, 1.0 - thumbFraction);

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double trackWidth = constraints.maxWidth;
            final double thumbWidth = trackWidth * thumbFraction;
            final double thumbLeft = trackWidth * thumbLeftFraction;

            return Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: thumbLeft,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: thumbWidth,
                      decoration: BoxDecoration(
                        color: _scrollThumbColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 코드2 방식 적용
  // 헤더 셀 배경이 셀 전체를 채우도록 TableCell fill 과 ColoredBox 사용
  Widget _buildCornerHeaderCell() {
    return const TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: ColoredBox(
        color: Color(0xFFF3F3F3),
        child: SizedBox.expand(),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: ColoredBox(
        color: const Color(0xFFF3F3F3),
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRowHeaderCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: ColoredBox(
        color: const Color(0xFFF7F7F7),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(XlsxCell cell) {
    Alignment alignment;
    TextAlign textAlign;

    switch (cell.horizontalAlign) {
      case XlsxHorizontalAlign.center:
        alignment = Alignment.center;
        textAlign = TextAlign.center;
        break;
      case XlsxHorizontalAlign.right:
        alignment = Alignment.centerRight;
        textAlign = TextAlign.right;
        break;
      case XlsxHorizontalAlign.left:
      case XlsxHorizontalAlign.general:
      default:
        alignment = Alignment.centerLeft;
        textAlign = TextAlign.left;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      alignment: alignment,
      child: SelectableText(
        cell.text,
        textAlign: textAlign,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
          height: 1.25,
        ),
      ),
    );
  }

  String _columnLabel(int index) {
    int n = index;
    final StringBuffer buffer = StringBuffer();
    while (n >= 0) {
      final int code = n % 26;
      buffer.writeCharCode('A'.codeUnitAt(0) + code);
      n = n ~/ 26 - 1;
    }
    final String result = buffer.toString().split('').reversed.join();
    return result;
  }
}

// 전체 시트를 로드하고 정렬 정보까지 적용
Future<List<XlsxSheetData>> _loadAllSheetsFromXlsx(String path) async {
  final File file = File(path);
  final List<int> bytes = await file.readAsBytes();
  final Archive archive = ZipDecoder().decodeBytes(bytes);

  ArchiveFile? sharedStringsFile;
  ArchiveFile? workbookFile;
  ArchiveFile? relsFile;
  ArchiveFile? stylesFile;

  final Map<String, ArchiveFile> worksheetFiles = <String, ArchiveFile>{};

  for (final ArchiveFile f in archive.files) {
    final String name = f.name;
    if (name == 'xl/sharedStrings.xml') {
      sharedStringsFile = f;
    } else if (name == 'xl/workbook.xml') {
      workbookFile = f;
    } else if (name == 'xl/_rels/workbook.xml.rels') {
      relsFile = f;
    } else if (name == 'xl/styles.xml') {
      stylesFile = f;
    } else if (name.startsWith('xl/worksheets/')) {
      worksheetFiles[name] = f;
    }
  }

  final List<String> sharedStrings = <String>[];
  if (sharedStringsFile != null) {
    final String xmlString = utf8.decode(sharedStringsFile.content as List<int>);
    final xml.XmlDocument doc = xml.XmlDocument.parse(xmlString);
    final Iterable<xml.XmlElement> siList = doc.findAllElements('si');

    for (final xml.XmlElement si in siList) {
      final StringBuffer buffer = StringBuffer();
      for (final xml.XmlElement t in si.findAllElements('t')) {
        buffer.write(t.text);
      }
      sharedStrings.add(buffer.toString());
    }
  }

  final List<XlsxCellStyle> cellStyles = _parseCellStyles(stylesFile);

  final List<XlsxSheetData> result = <XlsxSheetData>[];

  if (workbookFile != null && relsFile != null) {
    final String workbookXml = utf8.decode(workbookFile.content as List<int>);
    final xml.XmlDocument workbookDoc = xml.XmlDocument.parse(workbookXml);

    final String relsXml = utf8.decode(relsFile.content as List<int>);
    final xml.XmlDocument relsDoc = xml.XmlDocument.parse(relsXml);

    final Iterable<xml.XmlElement> rels = relsDoc.findAllElements('Relationship');
    final Map<String, String> relMap = <String, String>{};

    for (final xml.XmlElement rel in rels) {
      final String? id = rel.getAttribute('Id');
      final String? target = rel.getAttribute('Target');
      if (id != null && target != null) {
        relMap[id] = target;
      }
    }

    final Iterable<xml.XmlElement> sheetElements = workbookDoc.findAllElements('sheet');
    for (final xml.XmlElement sheetElem in sheetElements) {
      final String sheetName = sheetElem.getAttribute('name') ?? 'Sheet';
      final String? rId = sheetElem.getAttribute('r:id');

      String? sheetPath;
      if (rId != null) {
        final String? target = relMap[rId];
        if (target != null && target.isNotEmpty) {
          sheetPath = 'xl/$target';
        }
      }

      sheetPath ??= 'xl/worksheets/sheet1.xml';

      ArchiveFile? sheetFile = archive.files.where((ArchiveFile f) => f.name == sheetPath).firstOrNull;
      sheetFile ??= worksheetFiles.values.firstOrNull;

      if (sheetFile == null) {
        continue;
      }

      final List<List<XlsxCell>> rows = _parseSheetRows(sheetFile, sharedStrings, cellStyles);
      result.add(
        XlsxSheetData(
          sheetName: sheetName,
          rows: rows,
        ),
      );
    }
  }

  if (result.isEmpty && worksheetFiles.isNotEmpty) {
    final ArchiveFile sheetFile = worksheetFiles.values.first;
    final List<List<XlsxCell>> rows = _parseSheetRows(sheetFile, sharedStrings, cellStyles);
    result.add(
      XlsxSheetData(
        sheetName: 'Sheet1',
        rows: rows,
      ),
    );
  }

  if (result.isEmpty) {
    result.add(
      XlsxSheetData(
        sheetName: 'Sheet1',
        rows: <List<XlsxCell>>[],
      ),
    );
  }

  return result;
}

// styles xml 에서 셀 정렬 정보 파싱
List<XlsxCellStyle> _parseCellStyles(ArchiveFile? stylesFile) {
  if (stylesFile == null) {
    return <XlsxCellStyle>[];
  }

  try {
    final String stylesXml = utf8.decode(stylesFile.content as List<int>);
    final xml.XmlDocument doc = xml.XmlDocument.parse(stylesXml);

    final xml.XmlElement? cellXfsElem = doc.findAllElements('cellXfs').firstOrNull;
    if (cellXfsElem == null) {
      return <XlsxCellStyle>[];
    }

    final List<XlsxCellStyle> result = <XlsxCellStyle>[];
    final Iterable<xml.XmlElement> xfElements = cellXfsElem.findAllElements('xf');

    for (final xml.XmlElement xf in xfElements) {
      XlsxHorizontalAlign align = XlsxHorizontalAlign.general;

      final String? applyAlignmentAttr = xf.getAttribute('applyAlignment');
      final bool applyAlignment = applyAlignmentAttr == null || applyAlignmentAttr == '1';

      if (applyAlignment) {
        final xml.XmlElement? alignmentElem = xf.getElement('alignment');
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

      result.add(
        XlsxCellStyle(
          horizontalAlign: align,
        ),
      );
    }

    return result;
  } catch (_) {
    return <XlsxCellStyle>[];
  }
}

// 시트 한 개 파싱
List<List<XlsxCell>> _parseSheetRows(
    ArchiveFile sheetFile,
    List<String> sharedStrings,
    List<XlsxCellStyle> cellStyles,
    ) {
  final String sheetXml = utf8.decode(sheetFile.content as List<int>);
  final xml.XmlDocument sheetDoc = xml.XmlDocument.parse(sheetXml);

  final xml.XmlElement? sheetData = sheetDoc.findAllElements('sheetData').firstOrNull;
  if (sheetData == null) {
    return <List<XlsxCell>>[];
  }

  final List<List<XlsxCell>> rows = <List<XlsxCell>>[];
  final Iterable<xml.XmlElement> rowElements = sheetData.findAllElements('row');

  for (final xml.XmlElement rowElem in rowElements) {
    final Map<int, XlsxCell> cellMap = <int, XlsxCell>{};
    int maxColIndex = -1;

    final Iterable<xml.XmlElement> cellElements = rowElem.findAllElements('c');
    for (final xml.XmlElement c in cellElements) {
      final String? ref = c.getAttribute('r');
      if (ref == null) {
        continue;
      }

      final int colIndex = _columnIndexFromRef(ref);
      if (colIndex < 0) {
        continue;
      }

      String value = '';
      final xml.XmlElement? vElem = c.getElement('v');
      if (vElem != null) {
        final String raw = vElem.text;
        final String? type = c.getAttribute('t');
        if (type == 's') {
          final int idx = int.tryParse(raw) ?? -1;
          if (idx >= 0 && idx < sharedStrings.length) {
            value = sharedStrings[idx];
          } else {
            value = raw;
          }
        } else {
          value = raw;
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

      final XlsxCell cell = XlsxCell(
        text: value,
        horizontalAlign: align,
      );

      cellMap[colIndex] = cell;
      if (colIndex > maxColIndex) {
        maxColIndex = colIndex;
      }
    }

    if (maxColIndex < 0) {
      rows.add(<XlsxCell>[]);
      continue;
    }

    final List<XlsxCell> rowValues = List<XlsxCell>.filled(maxColIndex + 1, XlsxCell.empty);
    cellMap.forEach((int col, XlsxCell v) {
      if (col >= 0 && col < rowValues.length) {
        rowValues[col] = v;
      }
    });

    rows.add(rowValues);
  }

  return rows;
}

// 열 인덱스 계산
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

// firstOrNull 유틸
extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull {
    final Iterator<E> it = iterator;
    if (!it.moveNext()) {
      return null;
    }
    return it.current;
  }
}
