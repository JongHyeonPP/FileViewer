import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import 'supported_file_types.dart';

enum TextEncoding {
  utf8,
  eucKr,
}

enum FileServiceErrorType {
  textEncodingUnknown,
  textReloadFailed,
  unsupportedFormat,
}

class ViewerFile {
  final String fileId;
  final String path;
  final String displayPath;
  final String extension;
  final String? textContent;

  ViewerFile({
    required this.fileId,
    required this.path,
    required this.displayPath,
    required this.extension,
    required this.textContent,
  });

  bool get isTxt {
    return SupportedFileTypes.isTextExtension(extension);
  }

  bool get isDocx {
    return SupportedFileTypes.isDocExtension(extension);
  }

  bool get isPdf {
    return SupportedFileTypes.isPdfExtension(extension);
  }

  bool get isImage {
    return SupportedFileTypes.isImageExtension(extension);
  }

  bool get isXlsx {
    return extension == 'xlsx';
  }

  bool get isSupportedForInAppView {
    return isTxt || isDocx || isPdf || isImage || isXlsx;
  }

  bool get isExternalOnly {
    return !isSupportedForInAppView &&
        SupportedFileTypes.isSupportedExtension(extension);
  }
}

class ViewerPickResult {
  final ViewerFile? file;
  final String? errorMessage;
  final FileServiceErrorType? errorType;

  ViewerPickResult.success(this.file)
      : errorMessage = null,
        errorType = null;

  ViewerPickResult.error(this.errorMessage, this.errorType) : file = null;

  bool get hasError {
    return errorMessage != null || errorType != null;
  }
}

class _DecodedText {
  final String text;
  final TextEncoding encoding;

  _DecodedText(this.text, this.encoding);
}

class FileService {
  static const MethodChannel _contentChannel =
  MethodChannel('app.channel/file_content');

  List<String> _allSupportedExtensions() {
    final Set<String> set = <String>{
      ...SupportedFileTypes.textExtensions,
      ...SupportedFileTypes.officeOpenXmlExtensions,
      ...SupportedFileTypes.pdfExtensions,
      ...SupportedFileTypes.imageExtensions,
    };
    final List<String> list = set.toList();
    list.sort();
    return list;
  }

  List<String> _allSupportedMimeTypes() {
    return <String>[
      'text/plain',
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'image/*',
    ];
  }

  Future<ViewerPickResult?> pickFileForViewer() async {
    final List<String> exts = _allSupportedExtensions();

    final XTypeGroup group = XTypeGroup(
      label: 'supported',
      extensions: exts,
      mimeTypes: _allSupportedMimeTypes(),
    );

    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        group,
      ],
    );

    if (file == null) {
      return null;
    }

    final String path = file.path;
    final String extension = _extractExtension(path);

    if (!SupportedFileTypes.isSupportedExtension(extension)) {
      return ViewerPickResult.error(
        '지원하지 않는 파일 형식입니다',
        FileServiceErrorType.unsupportedFormat,
      );
    }

    final String displayPath = path;
    final String fileId = path;

    if (SupportedFileTypes.isTextExtension(extension)) {
      final Uint8List bytes = await file.readAsBytes();
      try {
        final _DecodedText decoded = await _decodeTxtBytes(bytes);

        return ViewerPickResult.success(
          ViewerFile(
            fileId: fileId,
            path: path,
            displayPath: displayPath,
            extension: extension,
            textContent: decoded.text,
          ),
        );
      } catch (_) {
        return ViewerPickResult.error(
          '텍스트 파일의 인코딩을 알 수 없습니다',
          FileServiceErrorType.textEncodingUnknown,
        );
      }
    }

    return ViewerPickResult.success(
      ViewerFile(
        fileId: fileId,
        path: path,
        displayPath: displayPath,
        extension: extension,
        textContent: null,
      ),
    );
  }

  Future<ViewerPickResult> loadFileForViewer(
      String fileId, {
        String? displayPath,
      }) async {
    final String candidateForExt =
    (displayPath != null && displayPath.isNotEmpty) ? displayPath : fileId;
    final String extension = _extractExtension(candidateForExt);

    if (!SupportedFileTypes.isSupportedExtension(extension)) {
      return ViewerPickResult.error(
        '지원하지 않는 파일 형식입니다',
        FileServiceErrorType.unsupportedFormat,
      );
    }

    final String effectiveDisplayPath =
    (displayPath != null && displayPath.isNotEmpty)
        ? displayPath
        : candidateForExt;

    String actualPath = fileId;

    final bool isContentUri = fileId.startsWith('content://');
    final bool isFileUri = fileId.startsWith('file://');

    if (isContentUri || isFileUri) {
      final Uint8List? bytes = await _readBytesFromNative(fileId);
      if (bytes == null) {
        return ViewerPickResult.error(
          '파일을 여는 중 오류가 발생했습니다',
          FileServiceErrorType.textReloadFailed,
        );
      }

      actualPath = await _writeBytesToTempFile(bytes, extension);
    }

    if (SupportedFileTypes.isTextExtension(extension)) {
      try {
        final Uint8List bytes = await File(actualPath).readAsBytes();
        final _DecodedText decoded = await _decodeTxtBytes(bytes);

        return ViewerPickResult.success(
          ViewerFile(
            fileId: fileId,
            path: actualPath,
            displayPath: effectiveDisplayPath,
            extension: extension,
            textContent: decoded.text,
          ),
        );
      } catch (_) {
        return ViewerPickResult.error(
          '텍스트 파일을 다시 여는 중 오류가 발생했습니다',
          FileServiceErrorType.textReloadFailed,
        );
      }
    }

    if (SupportedFileTypes.isDocExtension(extension) ||
        SupportedFileTypes.isPdfExtension(extension) ||
        SupportedFileTypes.isImageExtension(extension) ||
        extension == 'xlsx') {
      return ViewerPickResult.success(
        ViewerFile(
          fileId: fileId,
          path: actualPath,
          displayPath: effectiveDisplayPath,
          extension: extension,
          textContent: null,
        ),
      );
    }

    return ViewerPickResult.error(
      '지원하지 않는 파일 형식입니다',
      FileServiceErrorType.unsupportedFormat,
    );
  }

  Future<void> openExternalFile(String path) async {
    await OpenFilex.open(path);
  }

  Future<_DecodedText> _decodeTxtBytes(Uint8List bytes) async {
    try {
      final String decoded = utf8.decode(bytes);
      return _DecodedText(decoded, TextEncoding.utf8);
    } catch (_) {
      try {
        final String decoded = await CharsetConverter.decode(
          'euc-kr',
          bytes,
        );
        return _DecodedText(decoded, TextEncoding.eucKr);
      } catch (_) {
        throw const FormatException('unknown encoding');
      }
    }
  }

  Future<Uint8List?> _readBytesFromNative(String fileId) async {
    try {
      final dynamic result = await _contentChannel.invokeMethod<dynamic>(
        'readBytes',
        <String, dynamic>{
          'fileId': fileId,
        },
      );
      if (result is Uint8List) {
        return result;
      }
      if (result is List<int>) {
        return Uint8List.fromList(result);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _writeBytesToTempFile(Uint8List bytes, String extension) async {
    final Directory dir = Directory.systemTemp;

    String suffix = '';
    if (extension.isNotEmpty) {
      suffix = '.$extension';
    }

    final String name = 'shared_${DateTime.now().millisecondsSinceEpoch}$suffix';
    final File out = File('${dir.path}/$name');

    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  }

  String _extractExtension(String path) {
    final int dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }
}
