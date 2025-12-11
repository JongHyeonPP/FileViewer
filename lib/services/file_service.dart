import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
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
  final String id;            // 안드로이드에서는 Uri 문자열
  final String displayPath;   // 사용자 표시용 경로 또는 이름
  final String extension;
  final String? textContent;  // 텍스트 파일일 때만 사용
  final Uint8List? binaryContent; // pdf, docx, 이미지 등 바이너리 데이터

  ViewerFile({
    required this.id,
    required this.displayPath,
    required this.extension,
    required this.textContent,
    required this.binaryContent,
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

  bool get isSupportedForInAppView {
    return isTxt || isDocx || isPdf || isImage;
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
  static const MethodChannel _pickerChannel =
  MethodChannel('app.channel/file_picker');

  static const MethodChannel _contentChannel =
  MethodChannel('app.channel/file_content');

  Future<ViewerPickResult?> pickFileForViewer() async {
    try {
      final dynamic result =
      await _pickerChannel.invokeMethod<dynamic>('pickFile');

      if (result == null) {
        // 사용자가 취소한 경우
        return null;
      }

      if (result is! Map) {
        return ViewerPickResult.error(
          '파일을 여는 중 오류가 발생했습니다',
          FileServiceErrorType.unsupportedFormat,
        );
      }

      final String? fileId = result['fileId'] as String?;
      final String? displayPath = result['displayPath'] as String?;

      if (fileId == null || fileId.isEmpty) {
        return ViewerPickResult.error(
          '파일을 여는 중 오류가 발생했습니다',
          FileServiceErrorType.unsupportedFormat,
        );
      }

      final String effectiveDisplayPath =
      (displayPath != null && displayPath.isNotEmpty)
          ? displayPath
          : fileId;

      return await _loadFromNativeSource(
        fileId: fileId,
        displayPath: effectiveDisplayPath,
      );
    } on PlatformException {
      return ViewerPickResult.error(
        '파일을 여는 중 오류가 발생했습니다',
        FileServiceErrorType.unsupportedFormat,
      );
    } on MissingPluginException {
      return ViewerPickResult.error(
        '현재 플랫폼에서는 파일 열기를 지원하지 않습니다',
        FileServiceErrorType.unsupportedFormat,
      );
    }
  }

  Future<ViewerPickResult> loadFileForViewer(
      String fileId, {
        String? displayPath,
      }) async {
    final String effectiveDisplayPath =
    (displayPath != null && displayPath.isNotEmpty)
        ? displayPath
        : fileId;

    return _loadFromNativeSource(
      fileId: fileId,
      displayPath: effectiveDisplayPath,
    );
  }

  Future<ViewerPickResult> _loadFromNativeSource({
    required String fileId,
    required String displayPath,
  }) async {
    try {
      final Uint8List bytes =
      await _contentChannel.invokeMethod<Uint8List>(
        'readBytes',
        <String, dynamic>{
          'fileId': fileId,
        },
      ) as Uint8List;

      final String extension = _extractExtension(
        displayPath.isNotEmpty ? displayPath : fileId,
      );

      if (!SupportedFileTypes.isSupportedExtension(extension)) {
        return ViewerPickResult.error(
          '지원하지 않는 파일 형식입니다',
          FileServiceErrorType.unsupportedFormat,
        );
      }

      if (SupportedFileTypes.isTextExtension(extension)) {
        try {
          final _DecodedText decoded = await _decodeTxtBytes(bytes);

          return ViewerPickResult.success(
            ViewerFile(
              id: fileId,
              displayPath: displayPath,
              extension: extension,
              textContent: decoded.text,
              binaryContent: null,
            ),
          );
        } catch (_) {
          return ViewerPickResult.error(
            '텍스트 파일의 인코딩을 알 수 없습니다',
            FileServiceErrorType.textEncodingUnknown,
          );
        }
      }

      // docx, pdf, 이미지 등은 바이너리 그대로 전달
      return ViewerPickResult.success(
        ViewerFile(
          id: fileId,
          displayPath: displayPath,
          extension: extension,
          textContent: null,
          binaryContent: bytes,
        ),
      );
    } on PlatformException catch (_) {
      return ViewerPickResult.error(
        '파일을 여는 중 오류가 발생했습니다',
        FileServiceErrorType.textReloadFailed,
      );
    } on MissingPluginException {
      return ViewerPickResult.error(
        '현재 플랫폼에서는 파일 열기를 지원하지 않습니다',
        FileServiceErrorType.unsupportedFormat,
      );
    }
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

  String _extractExtension(String pathOrName) {
    final int dotIndex = pathOrName.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return pathOrName.substring(dotIndex + 1).toLowerCase();
  }
}
