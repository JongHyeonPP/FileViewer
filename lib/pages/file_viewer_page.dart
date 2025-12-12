// lib/pages/file_viewer_page.dart
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/file_service.dart';

import '../viewers/text_viewer.dart';
import '../viewers/docx_viewer.dart';
import '../viewers/pdf_viewer.dart';
import '../viewers/image_viewer.dart';
import '../viewers/xlsx_viewer.dart';

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
    Navigator.of(context).pop();
  }

  Future<void> handleGoHome() async {
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
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
      final AppLocalizations t = AppLocalizations.of(context)!;
      final String message =
          result.errorMessage ?? t.errorWhileOpeningFile;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
      return;
    }

    final ViewerFile file = result.file!;

    if (!file.isSupportedForInAppView) {
      final AppLocalizations t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.unsupportedHere),
        ),
      );
      return;
    }

    setState(() {
      currentFile = file;
    });
  }

  Widget _buildContentArea() {
    if (currentFile.isDocx) {
      return DocxViewer(
        fileService: widget.fileService,
        file: currentFile,
      );
    }
    if (currentFile.isPdf) {
      return PdfViewerBody(
        file: currentFile,
      );
    }
    if (currentFile.isImage) {
      return ImageViewerBody(
        file: currentFile,
      );
    }
    if (currentFile.isXlsx) {
      return XlsxViewer(
        file: currentFile,
      );
    }
    if (currentFile.isTxt) {
      return TextViewer(
        file: currentFile,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '현재 버전에서 이 파일 형식은 지원하지 않습니다',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
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
                    child: _buildContentArea(),
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
    final AppLocalizations t = AppLocalizations.of(context)!;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(t.viewerTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: handleBackPressed,
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: handleGoHome,
            tooltip: t.goHomeTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: handlePickAnotherFile,
            tooltip: t.openAnotherFileTooltip,
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
    );
  }
}
