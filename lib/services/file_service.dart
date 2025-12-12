// lib/services/file_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:charset_converter/charset_converter.dart';
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
  final String fileId;        // 최근 목록에서 사용할 파일 식별자
  final String path;          // 실제 파일 경로
  final String displayPath;   // 사용자에게 보여 줄 경로 텍스트
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
  // 지원하는 모든 확장자 목록
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

  // 안드로이드용 MIME 타입 필터
  List<String> _allSupportedMimeTypes() {
    return <String>[
      'text/plain', // txt
      'application/pdf', // pdf
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // docx
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // xlsx
      'image/*', // 이미지 전반
    ];
  }

  // 탐색기에서 파일 선택
  Future<ViewerPickResult?> pickFileForViewer() async {
    final List<String> exts = _allSupportedExtensions();

    // 확장자와 MIME 타입을 동시에 지정
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

    // 탐색기가 필터를 완벽히 지키지 않는 경우를 위한 2차 방어
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

  // 최근 목록이나 공유 인텐트에서 다시 여는 경우
  Future<ViewerPickResult> loadFileForViewer(
      String path, {
        String? displayPath,
      }) async {
    final String extension = _extractExtension(path);

    if (!SupportedFileTypes.isSupportedExtension(extension)) {
      return ViewerPickResult.error(
        '지원하지 않는 파일 형식입니다',
        FileServiceErrorType.unsupportedFormat,
      );
    }

    final String effectiveDisplayPath = displayPath ?? path;
    final String fileId = path;

    if (SupportedFileTypes.isTextExtension(extension)) {
      try {
        final Uint8List bytes = await File(path).readAsBytes();
        final _DecodedText decoded = await _decodeTxtBytes(bytes);

        return ViewerPickResult.success(
          ViewerFile(
            fileId: fileId,
            path: path,
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
          path: path,
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

  String _extractExtension(String path) {
    final int dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }
}
