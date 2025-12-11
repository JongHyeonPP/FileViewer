import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:docx_viewer/docx_viewer.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../services/file_service.dart';
import '../services/supported_file_types.dart';

class FileViewerPage extends StatefulWidget {
  final FileService fileService;
  final ViewerFile initialFile;

  const FileViewerPage({
    super.key,
    required this.fileService,
    required this.initialFile,
  });

  @override
  State<FileViewerPage> createState() => FileViewerPageState();
}

class FileViewerPageState extends State<FileViewerPage> {
  late ViewerFile currentFile;

  @override
  void initState() {
    super.initState();
    currentFile = widget.initialFile;
  }

  String fileNameFromPath(String path) {
    final List<String> parts = path.split(RegExp(r'[\\/]+'));
    if (parts.isEmpty) {
      return '이름 없는 파일';
    }
    return parts.last;
  }

  Future<void> handleBackPressed() async {
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  Future<void> handleGoHome() async {
    await handleBackPressed();
  }

  Future<void> handlePickAnotherFile() async {
    final ViewerPickResult? result =
    await widget.fileService.pickFileForViewer();

    if (!mounted) {
      return;
    }

    if (result == null) {
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      return;
    }

    if (result.hasError || result.file == null) {
      final String message =
          result.errorMessage ?? '파일을 여는 중 오류가 발생했습니다';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
      return;
    }

    final ViewerFile file = result.file!;

    if (file.isSupportedForInAppView) {
      setState(() {
        currentFile = file;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('이 앱에서 지원하지 않는 파일 형식입니다'),
      ),
    );
  }

  Widget buildDocxContent() {
    final Uint8List? bytes = currentFile.binaryContent;
    if (bytes == null) {
      return const Center(
        child: Text('DOCX 데이터를 불러오지 못했습니다'),
      );
    }

    return DocxView(
      bytes: bytes,
      fontSize: 16,
      onError: (Object error) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('DOCX 표시 중 오류가 발생했습니다'),
          ),
        );
      },
    );
  }

  Widget buildTxtContent() {
    return SingleChildScrollView(
      child: Text(
        currentFile.textContent ?? '',
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget buildPdfContent() {
    final Uint8List? bytes = currentFile.binaryContent;
    if (bytes == null) {
      return const Center(
        child: Text('PDF 데이터를 불러오지 못했습니다'),
      );
    }

    return SfPdfViewer.memory(
      bytes,
      canShowScrollStatus: true,
      canShowScrollHead: true,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF 표시 중 오류가 발생했습니다  ${details.error}',
            ),
          ),
        );
      },
    );
  }

  Widget buildImageContent() {
    final Uint8List? bytes = currentFile.binaryContent;
    if (bytes == null) {
      return const Center(
        child: Text('이미지 데이터를 불러오지 못했습니다'),
      );
    }

    return Center(
      child: InteractiveViewer(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget buildContentArea() {
    if (currentFile.isDocx) {
      return buildDocxContent();
    }
    if (currentFile.isPdf) {
      return buildPdfContent();
    }
    if (currentFile.isImage) {
      return buildImageContent();
    }
    return buildTxtContent();
  }

  Widget buildPageBody(BuildContext context) {
    final String fileName = fileNameFromPath(currentFile.displayPath);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double maxWidth = 480;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: maxWidth,
            ),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: buildContentArea(),
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
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }
        await handleBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('파일 뷰어'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: handleGoHome,
              tooltip: '홈으로 돌아가기',
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: handlePickAnotherFile,
              tooltip: '다른 파일 열기',
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: Container(
                  color: const Color(0xFFF2F2F2),
                  child: buildPageBody(context),
                ),
              ),
            ),
            Container(
              height: 1,
              color: Colors.black26,
            ),
            SizedBox(
              height: bottomInset,
            ),
          ],
        ),
      ),
    );
  }
}
