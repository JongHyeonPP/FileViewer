import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool failed = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context)!;

    if (defaultTargetPlatform != TargetPlatform.android) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            t.unsupportedHere,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            t.errorOfficeDisplay,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final Map<String, dynamic> params = <String, dynamic>{
      'fileId': widget.file.fileId,
      'displayPath': widget.file.displayPath,
    };

    return AndroidView(
      viewType: 'lo_embedded_view',
      creationParams: params,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (_) {},
    );
  }
}
