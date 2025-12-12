// lib/services/recent_files_store.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_service.dart';
import 'supported_file_types.dart';

class RecentFileEntry {
  final String actualPath;
  final String displayPath;
  final String name;
  final String extension;
  final DateTime lastOpenedAt;

  RecentFileEntry({
    required this.actualPath,
    required this.displayPath,
    required this.name,
    required this.extension,
    required this.lastOpenedAt,
  });

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
      'actualPath': actualPath,
      'displayPath': displayPath,
      'name': name,
      'extension': extension,
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
    };
  }

  factory RecentFileEntry.fromJson(Map<String, dynamic> json) {
    return RecentFileEntry(
      actualPath: json['actualPath'] as String? ?? '',
      displayPath: json['displayPath'] as String? ?? '',
      name: json['name'] as String? ?? '',
      extension: json['extension'] as String? ?? '',
      lastOpenedAt: DateTime.tryParse(
        json['lastOpenedAt'] as String? ?? '',
      ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
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
          if (entry.actualPath.isNotEmpty && entry.name.isNotEmpty) {
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
    _cleanDisplayPath(file.displayPath, file.path);

    final String name = _fileNameFromPath(
      cleanedDisplayPath.isNotEmpty ? cleanedDisplayPath : file.path,
    );

    // 같은 실제 경로는 한 개만 유지
    _items.removeWhere(
          (RecentFileEntry e) => e.actualPath == file.path,
    );

    _items.insert(
      0,
      RecentFileEntry(
        actualPath: file.path,
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

  Future<void> removeByActualPath(String path) async {
    _items.removeWhere((RecentFileEntry e) => e.actualPath == path);
    await _saveToStorage();
    notifyListeners();
  }

  String _cleanDisplayPath(String displayPath, String actualPath) {
    String candidate = displayPath;

    if (candidate.isEmpty) {
      candidate = actualPath;
    }

    // 실제 경로랑 동일하면 파일 이름만 남김
    if (candidate == actualPath) {
      return _fileNameFromPath(actualPath);
    }

    // 내부 앱 데이터 경로면 파일 이름만 남김
    if (candidate.startsWith('/data/user/0/') ||
        candidate.startsWith('/data/data/')) {
      return _fileNameFromPath(actualPath);
    }

    return candidate;
  }

  String _fileNameFromPath(String path) {
    final List<String> parts = path.split(RegExp(r'[\\/]+'));
    if (parts.isEmpty) {
      return '이름 없는 파일';
    }
    return parts.last;
  }
}
