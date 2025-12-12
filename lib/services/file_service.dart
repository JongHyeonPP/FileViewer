import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

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
  final String fileId;        // 안드로이드에서는 content uri 문자열, 그 외에서는 파일 경로
  final String displayPath;   // 사용자에게 보여 줄 경로 문자열
  final String extension;
  final String? textContent;

  ViewerFile({
    required this.fileId,
    required this.displayPath,
    required this.extension,
    required this.textContent,
  });

  // 예전 코드 호환용
  String get path {
    return fileId;
  }

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

  bool get isSupportedForInAppView {
    return isTxt || isDocx || isPdf || isImage;
  }

  // 현재는 외부 전용 형식 없음
  bool get isExternalOnly {
    return false;
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
  static const MethodChannel _pickerChannel =
  MethodChannel('app.channel/file_picker');
  static const MethodChannel _contentChannel =
  MethodChannel('app.channel/file_content');

  Future<ViewerPickResult?> pickFileForViewer() async {
    if (Platform.isAndroid) {
      try {
        final dynamic result =
        await _pickerChannel.invokeMethod<dynamic>('pickFile');

        if (result == null) {
          return null;
        }

        if (result is! Map) {
          return ViewerPickResult.error(
            '파일을 여는 중 오류가 발생했습니다',
            FileServiceErrorType.textReloadFailed,
          );
        }

        final String? fileId = result['fileId'] as String?;
        final String? displayPath = result['displayPath'] as String?;

        if (fileId == null || fileId.isEmpty) {
          return ViewerPickResult.error(
            '파일을 여는 중 오류가 발생했습니다',
            FileServiceErrorType.textReloadFailed,
          );
        }

        final String ext =
        _extractExtensionFromDisplayPath(displayPath ?? fileId);

        if (!SupportedFileTypes.isSupportedExtension(ext)) {
          return ViewerPickResult.error(
            '지원하지 않는 파일 형식입니다',
            FileServiceErrorType.unsupportedFormat,
          );
        }

        final ViewerFile file = await _buildViewerFileFromId(
          fileId: fileId,
          displayPath: displayPath ?? fileId,
          extension: ext,
        );

        return ViewerPickResult.success(file);
      } catch (_) {
        return ViewerPickResult.error(
          '파일을 여는 중 오류가 발생했습니다',
          FileServiceErrorType.textReloadFailed,
        );
      }
    }

    // 안드로이드가 아닌 경우에는 기존 file_selector 사용
    const XTypeGroup anyGroup = XTypeGroup(
      label: 'any',
      extensions: <String>[],
    );

    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[anyGroup],
    );

    if (file == null) {
      return null;
    }

    final String path = file.path;
    final String ext = _extractExtensionFromDisplayPath(path);

    if (!SupportedFileTypes.isSupportedExtension(ext)) {
      return ViewerPickResult.error(
        '지원하지 않는 파일 형식입니다',
        FileServiceErrorType.unsupportedFormat,
      );
    }

    ViewerFile viewerFile;
    if (SupportedFileTypes.isTextExtension(ext)) {
      try {
        final Uint8List bytes = await file.readAsBytes();
        final _DecodedText decoded = await _decodeTxtBytes(bytes);
        viewerFile = ViewerFile(
          fileId: path,
          displayPath: path,
          extension: ext,
          textContent: decoded.text,
        );
      } catch (_) {
        return ViewerPickResult.error(
          '텍스트 파일의 인코딩을 알 수 없습니다',
          FileServiceErrorType.textEncodingUnknown,
        );
      }
    } else {
      viewerFile = ViewerFile(
        fileId: path,
        displayPath: path,
        extension: ext,
        textContent: null,
      );
    }

    return ViewerPickResult.success(viewerFile);
  }

  Future<ViewerPickResult> loadFileForViewer(
      String fileId, {
        String? displayPath,
      }) async {
    final String effectiveDisplayPath = displayPath ?? fileId;
    final String ext = _extractExtensionFromDisplayPath(effectiveDisplayPath);

    if (!SupportedFileTypes.isSupportedExtension(ext)) {
      return ViewerPickResult.error(
        '지원하지 않는 파일 형식입니다',
        FileServiceErrorType.unsupportedFormat,
      );
    }

    try {
      final ViewerFile file = await _buildViewerFileFromId(
        fileId: fileId,
        displayPath: effectiveDisplayPath,
        extension: ext,
      );

      return ViewerPickResult.success(file);
    } catch (_) {
      return ViewerPickResult.error(
        '텍스트 파일을 다시 여는 중 오류가 발생했습니다',
        FileServiceErrorType.textReloadFailed,
      );
    }
  }

  Future<ViewerFile> _buildViewerFileFromId({
    required String fileId,
    required String displayPath,
    required String extension,
  }) async {
    String? textContent;

    if (SupportedFileTypes.isTextExtension(extension)) {
      final Uint8List bytes = await readRawBytes(fileId);
      final _DecodedText decoded = await _decodeTxtBytes(bytes);
      textContent = decoded.text;
    }

    return ViewerFile(
      fileId: fileId,
      displayPath: displayPath,
      extension: extension,
      textContent: textContent,
    );
  }

  Future<Uint8List> readRawBytes(String fileId) async {
    if (Platform.isAndroid) {
      final Uint8List? bytes =
      await _contentChannel.invokeMethod<Uint8List>(
        'readBytes',
        <String, dynamic>{'fileId': fileId},
      );
      if (bytes == null) {
        throw const FormatException('no bytes');
      }
      return bytes;
    }

    final File file = File(fileId);
    return file.readAsBytes();
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

  String _extractExtensionFromDisplayPath(String path) {
    final int dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }
}
