// lib/xlsx/xlsx_viewer.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/file_service.dart';
import 'xlsx_models.dart';
import 'xlsx_parser.dart';
import 'xlsx_grid.dart';
import 'xlsx_sheet_tabs.dart';
import 'xlsx_zoom_controls.dart';

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

  bool showHorizontalIndicator = false;
  Timer? horizontalIndicatorTimer;

  double zoom = 1.0;
  static const double minZoom = 0.7;
  static const double maxZoom = 2.5;

  bool showZoomOverlay = false;
  Timer? zoomOverlayTimer;

  int selectionClearVersion = 0;

  final XlsxParser parser = XlsxParser();

  @override
  void initState() {
    super.initState();
    future = parser.loadAllSheetsFromXlsx(widget.file.path);
  }

  @override
  void didUpdateWidget(covariant XlsxViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      selectedSheetIndex = 0;
      zoom = 1.0;
      showZoomOverlay = false;
      showHorizontalIndicator = false;
      selectionClearVersion = 0;
      zoomOverlayTimer?.cancel();
      horizontalIndicatorTimer?.cancel();
      future = parser.loadAllSheetsFromXlsx(widget.file.path);
      _resetScrollToOrigin();
    }
  }

  @override
  void dispose() {
    horizontalIndicatorTimer?.cancel();
    zoomOverlayTimer?.cancel();
    horizontalController.dispose();
    verticalController.dispose();
    super.dispose();
  }

  void _resetScrollToOrigin() {
    if (horizontalController.hasClients) {
      horizontalController.jumpTo(0);
    }
    if (verticalController.hasClients) {
      verticalController.jumpTo(0);
    }
  }

  void _onUserHorizontalScroll() {
    if (!showHorizontalIndicator) {
      setState(() {
        showHorizontalIndicator = true;
      });
    }

    horizontalIndicatorTimer?.cancel();
    horizontalIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) {
        return;
      }
      setState(() {
        showHorizontalIndicator = false;
      });
    });
  }

  void _showZoomHud() {
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

  void _setZoom(double value, {required bool showHud}) {
    final double clamped = value.clamp(minZoom, maxZoom) as double;
    if (clamped == zoom) {
      return;
    }
    setState(() {
      zoom = clamped;
    });
    if (showHud) {
      _showZoomHud();
    }
  }

  void _zoomIn({required bool showHud}) {
    _setZoom(zoom + 0.15, showHud: showHud);
  }

  void _zoomOut({required bool showHud}) {
    _setZoom(zoom - 0.15, showHud: showHud);
  }

  void _selectSheet(int index) {
    if (index == selectedSheetIndex) {
      return;
    }
    setState(() {
      selectedSheetIndex = index;
      selectionClearVersion += 1;
    });
    _resetScrollToOrigin();
  }

  void _clearSelectionAndHideToolbar() {
    setState(() {
      selectionClearVersion += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XlsxSheetData>>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<List<XlsxSheetData>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
            final bool useLandscapeLayout = isLandscape && constraints.maxWidth >= 600;

            final XlsxSheetData currentSheet = sheets[selectedSheetIndex];
            final _SheetGridInfo gridInfo = _calcGridInfo(currentSheet.rows);

            if (useLandscapeLayout) {
              return _buildLandscape(
                constraints: constraints,
                sheets: sheets,
                currentSheet: currentSheet,
                gridInfo: gridInfo,
              );
            }

            return _buildPortrait(
              sheets: sheets,
              gridInfo: gridInfo,
            );
          },
        );
      },
    );
  }

  _SheetGridInfo _calcGridInfo(List<List<XlsxCell>> rows) {
    int columnCount = 0;
    for (final List<XlsxCell> row in rows) {
      if (row.length > columnCount) {
        columnCount = row.length;
      }
    }
    return _SheetGridInfo(rows: rows, columnCount: columnCount);
  }

  Widget _buildPortrait({
    required List<XlsxSheetData> sheets,
    required _SheetGridInfo gridInfo,
  }) {
    if (gridInfo.columnCount == 0 || gridInfo.rows.isEmpty) {
      return Column(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Text(
                  '내용이 없는 시트입니다',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ),
          XlsxSheetTabs(
            sheets: sheets,
            selectedIndex: selectedSheetIndex,
            onSelect: _selectSheet,
            axis: Axis.horizontal,
            headerTitle: null,
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: XlsxGrid(
            rows: gridInfo.rows,
            columnCount: gridInfo.columnCount,
            horizontalController: horizontalController,
            verticalController: verticalController,
            zoom: zoom,
            showHorizontalIndicator: showHorizontalIndicator,
            showZoomOverlay: showZoomOverlay,
            showZoomButtonsOverlay: true,
            onZoomIn: () => _zoomIn(showHud: true),
            onZoomOut: () => _zoomOut(showHud: true),
            onUserHorizontalScroll: _onUserHorizontalScroll,
            onBackgroundTap: _clearSelectionAndHideToolbar,
            selectionClearVersion: selectionClearVersion,
          ),
        ),
        XlsxSheetTabs(
          sheets: sheets,
          selectedIndex: selectedSheetIndex,
          onSelect: _selectSheet,
          axis: Axis.horizontal,
          headerTitle: null,
        ),
      ],
    );
  }

  Widget _buildLandscape({
    required BoxConstraints constraints,
    required List<XlsxSheetData> sheets,
    required XlsxSheetData currentSheet,
    required _SheetGridInfo gridInfo,
  }) {
    final double sidebarWidth = (constraints.maxWidth * 0.14).clamp(112.0, 142.0);

    final Widget gridArea;
    if (gridInfo.columnCount == 0 || gridInfo.rows.isEmpty) {
      gridArea = Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Text(
            '내용이 없는 시트입니다',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ),
      );
    } else {
      gridArea = XlsxGrid(
        rows: gridInfo.rows,
        columnCount: gridInfo.columnCount,
        horizontalController: horizontalController,
        verticalController: verticalController,
        zoom: zoom,
        showHorizontalIndicator: showHorizontalIndicator,
        showZoomOverlay: false,
        showZoomButtonsOverlay: false,
        onZoomIn: () => _zoomIn(showHud: false),
        onZoomOut: () => _zoomOut(showHud: false),
        onUserHorizontalScroll: _onUserHorizontalScroll,
        onBackgroundTap: _clearSelectionAndHideToolbar,
        selectionClearVersion: selectionClearVersion,
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: gridArea),
        SizedBox(
          width: math.min(sidebarWidth, constraints.maxWidth * 0.30),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0FF),
              border: Border(
                left: BorderSide(color: Colors.grey.shade300, width: 0.8),
              ),
            ),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: XlsxSheetTabs(
                    sheets: sheets,
                    selectedIndex: selectedSheetIndex,
                    onSelect: _selectSheet,
                    axis: Axis.vertical,
                    headerTitle: currentSheet.sheetName,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: XlsxZoomSidebarPanel(
                      zoom: zoom,
                      onZoomOut: () => _zoomOut(showHud: false),
                      onZoomIn: () => _zoomIn(showHud: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetGridInfo {
  final List<List<XlsxCell>> rows;
  final int columnCount;

  const _SheetGridInfo({
    required this.rows,
    required this.columnCount,
  });
}
