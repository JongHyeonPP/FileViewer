import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:xml/xml.dart';

import '../l10n/app_localizations.dart';
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

  bool _docxErrorShownForCurrentFile = false;
  bool _pdfErrorShownForCurrentFile = false;
  bool _imageErrorShownForCurrentFile = false;

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
      _docxErrorShownForCurrentFile = false;
      _pdfErrorShownForCurrentFile = false;
      _imageErrorShownForCurrentFile = false;
    });
  }

  Future<String> _loadDocxText(String fileId) async {
    try {
      final Uint8List bytes = await widget.fileService.readRawBytes(fileId);
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      ArchiveFile? documentXmlFile;
      for (final ArchiveFile file in archive) {
        if (file.name == 'word/document.xml') {
          documentXmlFile = file;
          break;
        }
      }

      if (documentXmlFile == null) {
        throw const FormatException('document.xml not found');
      }

      final List<int> contentBytes = documentXmlFile.content as List<int>;
      final String xmlString = utf8.decode(contentBytes);

      final XmlDocument xmlDocument = XmlDocument.parse(xmlString);
      final StringBuffer buffer = StringBuffer();

      final Iterable<XmlElement> paragraphs =
      xmlDocument.findAllElements('w:p');

      for (final XmlElement paragraph in paragraphs) {
        final Iterable<XmlElement> texts = paragraph.findAllElements('w:t');
        for (final XmlElement textNode in texts) {
          buffer.write(textNode.text);
        }
        buffer.write('\n\n');
      }

      final String result = buffer.toString().trimRight();
      return result;
    } catch (_) {
      throw const FormatException('docx parse failed');
    }
  }

  Widget buildDocxContent() {
    final key = ValueKey<String>('docx_${currentFile.fileId}');

    return FutureBuilder<String>(
      key: key,
      future: _loadDocxText(currentFile.fileId),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final AppLocalizations t = AppLocalizations.of(context)!;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          if (!_docxErrorShownForCurrentFile) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t.errorOfficeDisplay),
                ),
              );
            });
            _docxErrorShownForCurrentFile = true;
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t.errorOfficeDisplay,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final String text = snapshot.data ?? '';
        if (text.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '문서에 표시할 텍스트가 없습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: SelectableText(
            text,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        );
      },
    );
  }

  Widget buildTxtContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: SelectableText(
        currentFile.textContent ?? '',
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget buildPdfContent() {
    final key = ValueKey<String>('pdf_${currentFile.fileId}');

    return FutureBuilder<Uint8List>(
      key: key,
      future: widget.fileService.readRawBytes(currentFile.fileId),
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        final AppLocalizations t = AppLocalizations.of(context)!;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.hasError) {
          if (!_pdfErrorShownForCurrentFile) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t.errorPdfDisplay),
                ),
              );
            });
            _pdfErrorShownForCurrentFile = true;
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t.errorPdfDisplay,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final Uint8List bytes = snapshot.data!;

        return SfPdfViewer.memory(
          bytes,
          canShowScrollStatus: true,
          canShowScrollHead: true,
          enableTextSelection: true,
          canShowTextSelectionMenu: true,
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            if (!_pdfErrorShownForCurrentFile) {
              _pdfErrorShownForCurrentFile = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${t.errorPdfDisplay}  ${details.error}',
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget buildImageContent() {
    final key = ValueKey<String>('image_${currentFile.fileId}');

    return FutureBuilder<Uint8List>(
      key: key,
      future: widget.fileService.readRawBytes(currentFile.fileId),
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.hasError) {
          if (!_imageErrorShownForCurrentFile) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('이미지 표시 중 오류가 발생했습니다'),
                ),
              );
            });
            _imageErrorShownForCurrentFile = true;
          }

          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '이미지 파일을 불러오는 중 오류가 발생했습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final Uint8List bytes = snapshot.data!;

        return Center(
          child: InteractiveViewer(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
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
