// lib/viewers/docx_viewer.dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../l10n/app_localizations.dart';
import '../services/file_service.dart';

class DocxViewer extends StatefulWidget {
  final FileService fileService;
  final ViewerFile file;

  const DocxViewer({
    super.key,
    required this.fileService,
    required this.file,
  });

  @override
  State<DocxViewer> createState() => _DocxViewerState();
}

class _DocxViewerState extends State<DocxViewer> {
  bool _errorShown = false;

  Future<String> _loadDocxText(String path) async {
    try {
      final List<int> bytes = await File(path).readAsBytes();
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      final ArchiveFile? documentXmlFile =
      _findArchiveFile(archive, 'word/document.xml');

      if (documentXmlFile == null) {
        throw const FormatException('document.xml not found');
      }

      final String xmlString = _readArchiveFileAsString(documentXmlFile);
      final XmlDocument xmlDocument = XmlDocument.parse(xmlString);
      final StringBuffer buffer = StringBuffer();

      final Iterable<XmlElement> paragraphs =
      xmlDocument.findAllElements('w:p');

      for (final XmlElement paragraph in paragraphs) {
        final Iterable<XmlElement> texts =
        paragraph.findAllElements('w:t');
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

  ArchiveFile? _findArchiveFile(Archive archive, String name) {
    for (final ArchiveFile file in archive) {
      if (file.name == name) {
        return file;
      }
    }
    return null;
  }

  String _readArchiveFileAsString(ArchiveFile file) {
    final Object? content = file.content;
    if (content is List<int>) {
      return utf8.decode(content);
    }
    if (content is String) {
      return content;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context)!;
    final String path = widget.file.path;
    final Key key = ValueKey<String>('docx_$path');

    return FutureBuilder<String>(
      key: key,
      future: _loadDocxText(path),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          if (!_errorShown) {
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
            _errorShown = true;
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
}
