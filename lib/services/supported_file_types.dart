// lib/services/supported_file_types.dart
class SupportedFileTypes {
  static const List<String> textExtensions = <String>[
    'txt',
    'json',
    'xml',
    'csv',
    'yaml',
    'yml',
    'ini',
    'cfg',
    'log',
    'md',
  ];

  static const List<String> officeOpenXmlExtensions = <String>[
    'docx',
    'xlsx',
    'pptx',
  ];

  static const List<String> pdfExtensions = <String>['pdf'];

  static const List<String> imageExtensions = <String>[
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
    'tif',
    'tiff',
  ];

  static bool isTextExtension(String ext) {
    return textExtensions.contains(ext);
  }

  static bool isOfficeOpenXmlExtension(String ext) {
    return officeOpenXmlExtensions.contains(ext);
  }

  static bool isDocExtension(String ext) {
    return ext == 'docx';
  }

  static bool isXlsxExtension(String ext) {
    return ext == 'xlsx';
  }

  static bool isPdfExtension(String ext) {
    return pdfExtensions.contains(ext);
  }

  static bool isImageExtension(String ext) {
    return imageExtensions.contains(ext);
  }

  static bool isSupportedExtension(String ext) {
    return isTextExtension(ext) ||
        isOfficeOpenXmlExtension(ext) ||
        isPdfExtension(ext) ||
        isImageExtension(ext);
  }

  static String labelForExtension(String ext) {
    if (ext.isEmpty) {
      return 'FILE';
    }
    return ext.toUpperCase();
  }
}
