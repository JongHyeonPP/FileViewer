// lib/viewers/pptx_viewer.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/file_service.dart';
import '../pptx/pptx_models.dart';
import '../pptx/pptx_parser.dart';
import '../pptx/pptx_renderer.dart';

class PptxViewer extends StatefulWidget {
  final ViewerFile file;

  const PptxViewer({
    super.key,
    required this.file,
  });

  @override
  State<PptxViewer> createState() => _PptxViewerState();
}

class _PptxViewerState extends State<PptxViewer> {
  late Future<PptxPresentationData> future;
  final PageController pageController = PageController();
  int currentIndex = 0;

  final PptxParser parser = PptxParser();

  @override
  void initState() {
    super.initState();
    future = parser.loadPresentation(widget.file.path);
  }

  @override
  void didUpdateWidget(covariant PptxViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      currentIndex = 0;
      future = parser.loadPresentation(widget.file.path);
      if (pageController.hasClients) {
        pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Future<void> jumpToSlide(int index) async {
    if (!pageController.hasClients) {
      return;
    }
    await pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> openPageJumpSheet({
    required int totalSlides,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: '${currentIndex + 1}',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final double safeBottom = MediaQuery.of(context).padding.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: math.max(safeBottom, bottomInset)),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '페이지 이동',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '1부터 $totalSlides 사이 번호를 입력해 주세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: '페이지 번호',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade400, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final int? page = int.tryParse(controller.text.trim());
                            if (page == null) {
                              return;
                            }
                            final int clamped = page.clamp(1, totalSlides);
                            Navigator.of(context).pop();
                            await jumpToSlide(clamped - 1);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C4DFF),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('이동'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PptxPresentationData>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<PptxPresentationData> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'PPTX 파일을 불러오는 중 오류가 발생했습니다',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          );
        }

        final PptxPresentationData data = snapshot.data!;
        if (data.slides.isEmpty) {
          return const Center(
            child: Text(
              '슬라이드가 비어 있습니다',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          );
        }

        if (currentIndex < 0 || currentIndex >= data.slides.length) {
          currentIndex = 0;
        }

        return Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: data.slides.length,
                onPageChanged: (int index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  return _buildSlidePage(
                    data: data,
                    slide: data.slides[index],
                  );
                },
              ),
            ),
            _buildBottomBar(data),
          ],
        );
      },
    );
  }

  Widget _buildSlidePage({
    required PptxPresentationData data,
    required PptxSlideData slide,
  }) {
    const double frameRadius = 10;
    const double frameMargin = 14;
    const double frameBorderWidth = 1.2;

    const double innerPadding = 12;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(frameMargin),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(frameRadius),
            border: Border.all(color: Colors.grey.shade400, width: frameBorderWidth),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(frameRadius),
            child: Padding(
              padding: const EdgeInsets.all(innerPadding),
              child: IgnorePointer(
                child: PptxSlideWidget(
                  presentation: data,
                  slide: slide,
                  isThumbnail: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildBottomBar(PptxPresentationData data) {
    const double barHeight = 86;

    return Container(
      height: barHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FF),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () async {
              await openPageJumpSheet(totalSlides: data.slides.length);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${currentIndex + 1} / ${data.slides.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
              itemCount: data.slides.length,
              itemBuilder: (BuildContext context, int index) {
                final bool selected = index == currentIndex;
                final PptxSlideData slide = data.slides[index];
                final String title = (slide.title != null && slide.title!.trim().isNotEmpty)
                    ? slide.title!.trim()
                    : 'Slide ${index + 1}';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () async {
                      await jumpToSlide(index);
                    },
                    child: _buildThumbCard(
                      data: data,
                      slide: slide,
                      title: title,
                      selected: selected,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbCard({
    required PptxPresentationData data,
    required PptxSlideData slide,
    required String title,
    required bool selected,
  }) {
    final Color borderColor = selected ? const Color(0xFF7C4DFF) : Colors.grey.shade400;
    final double borderWidth = selected ? 1.6 : 1.2;

    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 3),
                  child: IgnorePointer(
                    child: PptxSlideWidget(
                      presentation: data,
                      slide: slide,
                      isThumbnail: true,
                    ),
                  ),
                ),
              ),
              Container(
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
