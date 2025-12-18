import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/file_service.dart';

import '../viewers/text_viewer.dart';
import '../viewers/docx_viewer.dart';
import '../viewers/pdf_viewer.dart';
import '../viewers/image_viewer.dart';

import '../xlsx/xlsx_viewer.dart';
import '../pptx/pptx_viewer.dart';

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
  bool isLandscapeLocked = false;

  @override
  void initState() {
    super.initState();
    currentFile = widget.initialFile;
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
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
    final ViewerPickResult? result = await widget.fileService.pickFileForViewer();

    if (!mounted) {
      return;
    }

    if (result == null) {
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      return;
    }

    if (result.hasError || result.file == null) {
      final AppLocalizations t = AppLocalizations.of(context)!;
      final String message = result.errorMessage ?? t.errorWhileOpeningFile;
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

  Future<void> handleToggleOrientation() async {
    if (isLandscapeLocked) {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      isLandscapeLocked = !isLandscapeLocked;
    });
  }

  Widget buildSideRail() {
    const double railWidth = 64;

    return Container(
      width: railWidth,
      color: const Color(0xFFF5F0FF),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: handleBackPressed,
              tooltip: '뒤로가기',
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                isLandscapeLocked ? Icons.stay_current_landscape : Icons.stay_current_portrait,
              ),
              onPressed: handleToggleOrientation,
              tooltip: '화면 회전',
            ),
            const SizedBox(height: 6),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: handleGoHome,
              tooltip: '홈',
            ),
            const SizedBox(height: 6),
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: handlePickAnotherFile,
              tooltip: '파일 열기',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget buildFileHeader(String fileName) {
    return Container(
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
    );
  }

  Widget buildContentArea() {
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
    if (currentFile.isPptx) {
      return PptxViewer(
        file: currentFile,
      );
    }
    if (currentFile.isTxt) {
      return TextViewer(
        file: currentFile,
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '현재 버전에서 이 파일 형식은 지원하지 않습니다',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget buildPortraitBody(BuildContext context) {
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
                  buildFileHeader(fileName),
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

  Widget buildLandscapeBody(BuildContext context) {
    return Row(
      children: <Widget>[
        buildSideRail(),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: buildContentArea(),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context, bool isLandscape) {
    final AppLocalizations t = AppLocalizations.of(context)!;

    if (isLandscape) {
      return AppBar(
        automaticallyImplyLeading: false,
        title: Text(t.viewerTitle),
      );
    }

    return AppBar(
      automaticallyImplyLeading: false,
      title: Text(t.viewerTitle),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: handleBackPressed,
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(
            isLandscapeLocked ? Icons.stay_current_landscape : Icons.stay_current_portrait,
          ),
          onPressed: handleToggleOrientation,
          tooltip: '화면 회전',
        ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: buildAppBar(context, isLandscape),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: Container(
                color: const Color(0xFFF2F2F2),
                child: isLandscape ? buildLandscapeBody(context) : buildPortraitBody(context),
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
