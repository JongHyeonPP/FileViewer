// lib/viewers/pdf_viewer.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../l10n/app_localizations.dart';
import '../services/file_service.dart';

class PdfViewerBody extends StatefulWidget {
  final ViewerFile file;

  const PdfViewerBody({super.key, required this.file});

  @override
  State<PdfViewerBody> createState() => _PdfViewerBodyState();
}

class _PdfViewerBodyState extends State<PdfViewerBody> {
  bool _errorShown = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context)!;

    return SfPdfViewer.file(
      File(widget.file.path),
      canShowScrollStatus: true,
      canShowScrollHead: true,
      enableTextSelection: true,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        if (!_errorShown) {
          _errorShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t.errorPdfDisplay}  ${details.error}')),
          );
        }
      },
    );
  }
}
