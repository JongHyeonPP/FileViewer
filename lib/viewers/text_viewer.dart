// lib/viewers/text_viewer.dart
import 'package:flutter/material.dart';

import '../services/file_service.dart';

class TextViewer extends StatelessWidget {
  final ViewerFile file;

  const TextViewer({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: SelectableText(
        file.textContent ?? '',
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }
}
