// lib/xlsx/xlsx_grid.dart
import 'package:flutter/material.dart';

import 'xlsx_models.dart';
import 'xlsx_zoom_controls.dart';

class XlsxGrid extends StatelessWidget {
  final List<List<XlsxCell>> rows;
  final int columnCount;
  final ScrollController horizontalController;
  final ScrollController verticalController;

  final double zoom;
  final bool showHorizontalIndicator;

  final bool showZoomOverlay;
  final bool showZoomButtonsOverlay;

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  final VoidCallback onUserHorizontalScroll;
  final VoidCallback onBackgroundTap;

  final int selectionClearVersion;

  const XlsxGrid({
    super.key,
    required this.rows,
    required this.columnCount,
    required this.horizontalController,
    required this.verticalController,
    required this.zoom,
    required this.showHorizontalIndicator,
    required this.showZoomOverlay,
    required this.showZoomButtonsOverlay,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onUserHorizontalScroll,
    required this.onBackgroundTap,
    required this.selectionClearVersion,
  });

  double scaled(double v) => v * zoom;

  @override
  Widget build(BuildContext context) {
    final double cellWidth = 90 * zoom;
    final double tableWidth = cellWidth * (columnCount + 1);

    final List<TableRow> tableRows = <TableRow>[];
    tableRows.add(_buildHeaderRow());

    for (int r = 0; r < rows.length; r += 1) {
      final bool isFirstDataRow = r == 0;
      final List<XlsxCell> row = rows[r];

      final List<Widget> rowCells = <Widget>[];
      rowCells.add(
        _buildRowHeaderCell(
          (r + 1).toString(),
          isFirstDataRow: isFirstDataRow,
        ),
      );

      for (int c = 0; c < columnCount; c += 1) {
        final XlsxCell cell = c < row.length ? row[c] : XlsxCell.empty;
        rowCells.add(
          _buildDataCell(
            cell,
            isFirstDataRow: isFirstDataRow,
          ),
        );
      }

      tableRows.add(TableRow(children: rowCells));
    }

    final Widget table = KeyedSubtree(
      key: ValueKey<int>(selectionClearVersion),
      child: Table(
        defaultColumnWidth: FixedColumnWidth(cellWidth),
        border: TableBorder.all(
          color: Colors.grey.shade300,
          width: 0.5,
        ),
        children: tableRows,
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double topPadding = 28;
        const double sidePadding = 14;
        const double bottomPadding = 18;

        final Widget content = ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: Align(
            alignment: Alignment.topLeft,
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(sidePadding, topPadding, sidePadding, bottomPadding),
                  child: SizedBox(
                    width: tableWidth,
                    child: table,
                  ),
                ),
              ),
            ),
          ),
        );

        final Widget gridBody = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) => onBackgroundTap(),
          child: RawScrollbar(
            controller: verticalController,
            thumbColor: Colors.grey.shade600,
            radius: const Radius.circular(3),
            thickness: 4,
            notificationPredicate: (ScrollNotification notification) {
              return notification.metrics.axis == Axis.vertical;
            },
            child: SingleChildScrollView(
              controller: verticalController,
              scrollDirection: Axis.vertical,
              child: content,
            ),
          ),
        );

        return Stack(
          children: <Widget>[
            gridBody,
            if (showHorizontalIndicator)
              Positioned(
                left: 8,
                right: 8,
                bottom: 2,
                child: _HorizontalScrollIndicator(
                  controller: horizontalController,
                  thumbColor: Colors.grey.shade600,
                ),
              ),
            if (showZoomButtonsOverlay)
              Positioned(
                top: 10,
                right: 10,
                child: XlsxZoomOverlayChip(
                  zoom: zoom,
                  visible: showZoomOverlay,
                ),
              ),
            if (showZoomButtonsOverlay)
              Positioned(
                right: 6,
                bottom: 6,
                child: XlsxZoomButtonBar(
                  onZoomOut: onZoomOut,
                  onZoomIn: onZoomIn,
                ),
              ),
          ],
        );
      },
    );
  }

  TableRow _buildHeaderRow() {
    final List<Widget> headerCells = <Widget>[];
    headerCells.add(_buildCornerHeaderCell());
    for (int c = 0; c < columnCount; c += 1) {
      headerCells.add(_buildHeaderCell(_columnLabel(c)));
    }
    return TableRow(children: headerCells);
  }

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

  Widget _buildRowHeaderCell(
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

  Widget _buildDataCell(
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

  String _columnLabel(int index) {
    int n = index;
    final StringBuffer buffer = StringBuffer();
    while (n >= 0) {
      final int code = n % 26;
      buffer.writeCharCode('A'.codeUnitAt(0) + code);
      n = n ~/ 26 - 1;
    }
    return buffer.toString().split('').reversed.join();
  }
}

class _HorizontalScrollIndicator extends StatelessWidget {
  final ScrollController controller;
  final Color thumbColor;

  const _HorizontalScrollIndicator({
    required this.controller,
    required this.thumbColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        if (!controller.hasClients) {
          return const SizedBox.shrink();
        }

        final ScrollPosition position = controller.position;
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
                        color: thumbColor,
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
}
