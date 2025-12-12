import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_service.dart';
import 'supported_file_types.dart';

class RecentFileEntry {
  final String fileId;
  final String displayPath;
  final String name;
  final String extension;
  final DateTime lastOpenedAt;

  RecentFileEntry({
    required this.fileId,
    required this.displayPath,
    required this.name,
    required this.extension,
    required this.lastOpenedAt,
  });

  // 예전 코드 호환용
  String get actualPath {
    return fileId;
  }

  bool get isTxt {
    return SupportedFileTypes.isTextExtension(extension);
  }

  bool get isPdf {
    return SupportedFileTypes.isPdfExtension(extension);
  }

  bool get isDocOpenXml {
    return SupportedFileTypes.isOfficeOpenXmlExtension(extension);
  }

  bool get isImage {
    return SupportedFileTypes.isImageExtension(extension);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fileId': fileId,
      'displayPath': displayPath,
      'name': name,
      'extension': extension,
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
    };
  }

  factory RecentFileEntry.fromJson(Map<String, dynamic> json) {
    final String fileId =
        json['fileId'] as String? ?? json['actualPath'] as String? ?? '';
    final String displayPath =
        json['displayPath'] as String? ?? fileId;
    final String name =
        json['name'] as String? ?? '';
    final String extension =
        json['extension'] as String? ?? '';
    final String rawTime =
        json['lastOpenedAt'] as String? ?? '';

    final DateTime parsedTime =
        DateTime.tryParse(rawTime) ??
            DateTime.fromMillisecondsSinceEpoch(0);

    return RecentFileEntry(
      fileId: fileId,
      displayPath: displayPath,
      name: name,
      extension: extension,
      lastOpenedAt: parsedTime,
    );
  }
}

class RecentFilesStore extends ChangeNotifier {
  RecentFilesStore._internal();

  static final RecentFilesStore instance = RecentFilesStore._internal();

  static const String _storageKey = 'recent_files_v1';

  final List<RecentFileEntry> _items = <RecentFileEntry>[];
  bool _loaded = false;

  List<RecentFileEntry> get items {
    return List<RecentFileEntry>.unmodifiable(_items);
  }

  Future<void> loadFromStorage() async {
    if (_loaded) {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? rawList = prefs.getStringList(_storageKey);

    if (rawList != null) {
      _items.clear();
      for (final String raw in rawList) {
        try {
          final Map<String, dynamic> map =
          jsonDecode(raw) as Map<String, dynamic>;
          final RecentFileEntry entry = RecentFileEntry.fromJson(map);
          if (entry.fileId.isNotEmpty && entry.name.isNotEmpty) {
            _items.add(entry);
          }
        } catch (_) {
          // 무시
        }
      }
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawList = _items
        .map(
          (RecentFileEntry e) => jsonEncode(e.toJson()),
    )
        .toList();
    await prefs.setStringList(_storageKey, rawList);
  }

  Future<void> addFromViewerFile(ViewerFile file) async {
    final String cleanedDisplayPath =
    _cleanDisplayPath(file.displayPath);

    final String name = _fileNameFromPath(
      cleanedDisplayPath.isNotEmpty ? cleanedDisplayPath : file.displayPath,
    );

    _items.removeWhere(
          (RecentFileEntry e) => e.fileId == file.fileId,
    );

    _items.insert(
      0,
      RecentFileEntry(
        fileId: file.fileId,
        displayPath: cleanedDisplayPath,
        name: name,
        extension: file.extension,
        lastOpenedAt: DateTime.now(),
      ),
    );

    const int maxCount = 50;
    if (_items.length > maxCount) {
      _items.removeRange(maxCount, _items.length);
    }

    await _saveToStorage();
    notifyListeners();
  }

  Future<void> removeByFileId(String fileId) async {
    _items.removeWhere((RecentFileEntry e) => e.fileId == fileId);
    await _saveToStorage();
    notifyListeners();
  }

  // 예전 코드 호환용
  Future<void> removeByActualPath(String path) async {
    await removeByFileId(path);
  }

  String _cleanDisplayPath(String displayPath) {
    if (displayPath.isEmpty) {
      return '';
    }
    return displayPath;
  }

  String _fileNameFromPath(String path) {
    final List<String> parts = path.split(RegExp(r'[\\/]+'));
    if (parts.isEmpty) {
      return '이름 없는 파일';
    }
    return parts.last;
  }
}
