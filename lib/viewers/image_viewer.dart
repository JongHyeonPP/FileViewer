// lib/viewers/image_viewer.dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/file_service.dart';

class ImageViewerBody extends StatelessWidget {
  final ViewerFile file;

  const ImageViewerBody({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        child: Image.file(File(file.path), fit: BoxFit.contain),
      ),
    );
  }
}
