// lib/xlsx/xlsx_sheet_tabs.dart
import 'package:flutter/material.dart';

import 'xlsx_models.dart';

class XlsxSheetTabs extends StatelessWidget {
  final List<XlsxSheetData> sheets;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Axis axis;
  final String? headerTitle;

  const XlsxSheetTabs({
    super.key,
    required this.sheets,
    required this.selectedIndex,
    required this.onSelect,
    required this.axis,
    required this.headerTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (axis == Axis.horizontal) {
      return _buildHorizontalBar();
    }
    return _buildVerticalSidebar();
  }

  Widget _buildHorizontalBar() {
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
          final bool selected = index == selectedIndex;
          final XlsxSheetData sheet = sheets[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                if (!selected) {
                  onSelect(index);
                }
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: _buildSheetChipHorizontal(
                  sheetName: sheet.sheetName,
                  selected: selected,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalSidebar() {
    return Container(
      color: const Color(0xFFF5F0FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (headerTitle != null && headerTitle!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                child: Text(
                  headerTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                itemCount: sheets.length,
                itemBuilder: (BuildContext context, int index) {
                  final bool selected = index == selectedIndex;
                  final XlsxSheetData sheet = sheets[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: GestureDetector(
                      onTap: () {
                        if (!selected) {
                          onSelect(index);
                        }
                      },
                      child: _buildSheetChipVertical(
                        sheetName: sheet.sheetName,
                        selected: selected,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetChipHorizontal({
    required String sheetName,
    required bool selected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFFFFF) : const Color(0xFFF0E6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFF7C4DFF) : Colors.grey.shade400,
          width: selected ? 1.3 : 1.0,
        ),
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
            sheetName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? const Color(0xFF5E35B1) : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetChipVertical({
    required String sheetName,
    required bool selected,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFFFFF) : const Color(0xFFF0E6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF7C4DFF) : Colors.grey.shade400,
            width: selected ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.grid_on,
              size: 15,
              color: selected ? const Color(0xFF5E35B1) : Colors.grey.shade700,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sheetName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? const Color(0xFF5E35B1) : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
