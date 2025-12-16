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
  late Future<List<XlsxSheetData>> future;
  int selectedSheetIndex = 0;

  final ScrollController horizontalController = ScrollController();
  final ScrollController verticalController = ScrollController();

  bool showHorizontalBar = false;
  Timer? horizontalBarTimer;

  double zoom = 1.0;
  static const double minZoom = 0.7;
  static const double maxZoom = 2.5;

  bool showZoomOverlay = false;
  Timer? zoomOverlayTimer;

  Color get scrollThumbColor {
    return Colors.grey.shade600;
  }

  double scaled(double v) {
    return v * zoom;
  }

  void setZoom(double value) {
    final double clamped = value.clamp(minZoom, maxZoom) as double;
    if (clamped == zoom) {
      return;
    }
    setState(() {
      zoom = clamped;
    });
  }

  void showZoomHud() {
    if (!showZoomOverlay) {
      setState(() {
        showZoomOverlay = true;
      });
    }

    zoomOverlayTimer?.cancel();
    zoomOverlayTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() {
        showZoomOverlay = false;
      });
    });
  }

  void zoomIn() {
    setZoom(zoom + 0.15);
    showZoomHud();
  }

  void zoomOut() {
    setZoom(zoom - 0.15);
    showZoomHud();
  }

  @override
  void initState() {
    super.initState();
    future = loadAllSheetsFromXlsx(widget.file.path);
  }

  @override
  void didUpdateWidget(covariant XlsxViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      selectedSheetIndex = 0;
      zoom = 1.0;
      showZoomOverlay = false;
      zoomOverlayTimer?.cancel();
      future = loadAllSheetsFromXlsx(widget.file.path);
    }
  }

  @override
  void dispose() {
    horizontalBarTimer?.cancel();
    zoomOverlayTimer?.cancel();
    horizontalController.dispose();
    verticalController.dispose();
    super.dispose();
  }

  void onUserHorizontalScroll() {
    if (!showHorizontalBar) {
      setState(() {
        showHorizontalBar = true;
      });
    }

    horizontalBarTimer?.cancel();
    horizontalBarTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) {
        return;
      }
      setState(() {
        showHorizontalBar = false;
      });
    });
  }

  void resetScrollToOrigin() {
    if (horizontalController.hasClients) {
      horizontalController.jumpTo(0);
    }
    if (verticalController.hasClients) {
      verticalController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XlsxSheetData>>(
      future: future,
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

        if (selectedSheetIndex < 0 || selectedSheetIndex >= sheets.length) {
          selectedSheetIndex = 0;
        }

        final XlsxSheetData currentSheet = sheets[selectedSheetIndex];
        return buildSheetView(context, sheets, currentSheet);
      },
    );
  }

  Widget buildSheetView(
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
          buildSheetTabs(sheets),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: buildGrid(rows, columnCount),
        ),
        buildSheetTabs(sheets),
      ],
    );
  }

  Widget buildSheetTabs(List<XlsxSheetData> sheets) {
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
          final bool selected = index == selectedSheetIndex;
          final XlsxSheetData sheet = sheets[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                if (!selected) {
                  setState(() {
                    selectedSheetIndex = index;
                  });
                  resetScrollToOrigin();
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

  Widget buildGrid(List<List<XlsxCell>> rows, int columnCount) {
    final double cellWidth = 90 * zoom;
    final List<TableRow> tableRows = <TableRow>[];

    final List<Widget> headerCells = <Widget>[];
    headerCells.add(buildCornerHeaderCell());
    for (int c = 0; c < columnCount; c += 1) {
      headerCells.add(
        buildHeaderCell(columnLabel(c)),
      );
    }
    tableRows.add(
      TableRow(
        children: headerCells,
      ),
    );

    for (int r = 0; r < rows.length; r += 1) {
      final bool isFirstDataRow = r == 0;
      final List<XlsxCell> row = rows[r];
      final List<Widget> rowCells = <Widget>[];

      rowCells.add(
        buildRowHeaderCell(
          (r + 1).toString(),
          isFirstDataRow: isFirstDataRow,
        ),
      );

      for (int c = 0; c < columnCount; c += 1) {
        final XlsxCell cell = c < row.length ? row[c] : XlsxCell.empty;
        rowCells.add(
          buildDataCell(
            cell,
            isFirstDataRow: isFirstDataRow,
          ),
        );
      }

      tableRows.add(
        TableRow(
          children: rowCells,
        ),
      );
    }

    final Widget gridBody = RawScrollbar(
      controller: verticalController,
      thumbColor: scrollThumbColor,
      radius: const Radius.circular(3),
      thickness: 4,
      notificationPredicate: (ScrollNotification notification) {
        return notification.metrics.axis == Axis.vertical;
      },
      child: SingleChildScrollView(
        controller: verticalController,
        scrollDirection: Axis.vertical,
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification.metrics.axis == Axis.horizontal && notification is ScrollUpdateNotification) {
              onUserHorizontalScroll();
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: cellWidth * (columnCount + 1),
              child: Table(
                defaultColumnWidth: FixedColumnWidth(cellWidth),
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
    );

    return Stack(
      children: <Widget>[
        gridBody,
        if (showHorizontalBar)
          Positioned(
            left: 8,
            right: 8,
            bottom: 2,
            child: buildHorizontalIndicator(),
          ),
        Positioned(
          top: 10,
          right: 10,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: showZoomOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 260),
              child: buildZoomOverlayChip(),
            ),
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: buildZoomButtons(),
        ),
      ],
    );
  }

  Widget buildZoomOverlayChip() {
    return Container(
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
    );
  }

  Widget buildZoomButtons() {
    const double buttonWidth = 32;
    const double buttonHeight = 30;
    const double iconSize = 16;

    Widget buildOneButton({
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        child: SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.black87,
            ),
          ),
        ),
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
              buildOneButton(
                icon: Icons.remove,
                onTap: zoomOut,
              ),
              Container(
                width: 1,
                height: 18,
                color: Colors.black.withOpacity(0.22),
              ),
              buildOneButton(
                icon: Icons.add,
                onTap: zoomIn,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHorizontalIndicator() {
    return AnimatedBuilder(
      animation: horizontalController,
      builder: (BuildContext context, Widget? child) {
        if (!horizontalController.hasClients) {
          return const SizedBox.shrink();
        }

        final ScrollPosition position = horizontalController.position;
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
                        color: scrollThumbColor,
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

  Widget buildCornerHeaderCell() {
    return const TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: ColoredBox(
        color: Color(0xFFF3F3F3),
        child: SizedBox.expand(),
      ),
    );
  }

  Widget buildHeaderCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: Container(
        color: const Color(0xFFF3F3F3),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          vertical: scaled(4),
          horizontal: scaled(2),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: scaled(11),
          ),
        ),
      ),
    );
  }

  Widget buildRowHeaderCell(
      String text, {
        required bool isFirstDataRow,
      }) {
    final Color bg = isFirstDataRow ? const Color(0xFFF3F3F3) : const Color(0xFFF7F7F7);

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: Container(
        color: bg,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(
          vertical: scaled(4),
          horizontal: scaled(2),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: scaled(10),
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget buildDataCell(
      XlsxCell cell, {
        required bool isFirstDataRow,
      }) {
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

    final Color? bg = isFirstDataRow ? const Color(0xFFF3F3F3) : null;

    return Container(
      color: bg,
      padding: EdgeInsets.symmetric(
        vertical: scaled(4),
        horizontal: scaled(4),
      ),
      alignment: alignment,
      child: SelectableText(
        cell.text,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: scaled(11),
          color: Colors.black87,
          height: 1.25,
        ),
      ),
    );
  }

  String columnLabel(int index) {
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

class _XlsxSheetRef {
  final String sheetName;
  final String? sheetPath;

  const _XlsxSheetRef({
    required this.sheetName,
    required this.sheetPath,
  });
}

Future<List<XlsxSheetData>> loadAllSheetsFromXlsx(String path) async {
  final File file = File(path);
  final List<int> bytes = await file.readAsBytes();
  final Archive archive = ZipDecoder().decodeBytes(bytes);

  final Map<String, ArchiveFile> fileMap = <String, ArchiveFile>{};
  for (final ArchiveFile f in archive.files) {
    fileMap[f.name] = f;
  }

  ArchiveFile? sharedStringsFile = fileMap['xl/sharedStrings.xml'];
  ArchiveFile? workbookFile = fileMap['xl/workbook.xml'];
  ArchiveFile? relsFile = fileMap['xl/_rels/workbook.xml.rels'];
  ArchiveFile? stylesFile = fileMap['xl/styles.xml'];

  final Map<String, ArchiveFile> worksheetFiles = <String, ArchiveFile>{};
  for (final ArchiveFile f in archive.files) {
    if (f.name.startsWith('xl/worksheets/')) {
      worksheetFiles[f.name] = f;
    }
  }

  final List<String> sharedStrings = <String>[];
  if (sharedStringsFile != null) {
    final String xmlString = utf8.decode(sharedStringsFile.content as List<int>);
    final xml.XmlDocument doc = xml.XmlDocument.parse(xmlString);
    for (final xml.XmlElement si in doc.findAllElements('si')) {
      final StringBuffer buffer = StringBuffer();
      for (final xml.XmlElement t in si.descendants.whereType<xml.XmlElement>()) {
        if (t.name.local == 't') {
          buffer.write(t.text);
        }
      }
      sharedStrings.add(buffer.toString());
    }
  }

  final List<XlsxCellStyle> cellStyles = parseCellStyles(stylesFile);

  final List<_XlsxSheetRef> sheetRefs = <_XlsxSheetRef>[];

  if (workbookFile != null && relsFile != null) {
    final String workbookXml = utf8.decode(workbookFile.content as List<int>);
    final xml.XmlDocument workbookDoc = xml.XmlDocument.parse(workbookXml);

    final String relsXml = utf8.decode(relsFile.content as List<int>);
    final xml.XmlDocument relsDoc = xml.XmlDocument.parse(relsXml);

    final Map<String, String> relMap = <String, String>{};
    for (final xml.XmlElement rel in relsDoc.findAllElements('Relationship')) {
      final String? id = rel.getAttribute('Id');
      final String? target = rel.getAttribute('Target');
      if (id != null && target != null) {
        relMap[id] = target;
      }
    }

    for (final xml.XmlElement sheetElem in workbookDoc.findAllElements('sheet')) {
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
        _XlsxSheetRef(
          sheetName: sheetName,
          sheetPath: sheetPath,
        ),
      );
    }
  }

  if (sheetRefs.isEmpty && worksheetFiles.isNotEmpty) {
    final List<String> keys = worksheetFiles.keys.toList()..sort();
    for (int i = 0; i < keys.length; i += 1) {
      sheetRefs.add(
        _XlsxSheetRef(
          sheetName: 'Sheet${i + 1}',
          sheetPath: keys[i],
        ),
      );
    }
  }

  final List<XlsxSheetData> result = <XlsxSheetData>[];
  final List<String> sortedWorksheetKeys = worksheetFiles.keys.toList()..sort();

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

    final List<List<XlsxCell>> rows = parseSheetRows(
      sheetFile,
      sharedStrings,
      cellStyles,
    );

    result.add(
      XlsxSheetData(
        sheetName: ref.sheetName,
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

List<XlsxCellStyle> parseCellStyles(ArchiveFile? stylesFile) {
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

List<List<XlsxCell>> parseSheetRows(
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

      final int colIndex = columnIndexFromRef(ref);
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
          final xml.XmlElement? isElem = _firstChildElementByLocalName(c, 'is');
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

String _extractInlineStringFromCell(xml.XmlElement cell) {
  final xml.XmlElement? isElem = _firstChildElementByLocalName(cell, 'is');
  if (isElem == null) {
    return '';
  }

  final StringBuffer buffer = StringBuffer();
  for (final xml.XmlElement t in isElem.descendants.whereType<xml.XmlElement>()) {
    if (t.name.local == 't') {
      buffer.write(t.text);
    }
  }
  return buffer.toString();
}

xml.XmlElement? _firstChildElementByLocalName(xml.XmlElement parent, String local) {
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

int columnIndexFromRef(String ref) {
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

extension FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull {
    final Iterator<E> it = iterator;
    if (!it.moveNext()) {
      return null;
    }
    return it.current;
  }
}
