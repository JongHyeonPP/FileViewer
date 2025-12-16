import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/file_service.dart';
import '../services/supported_file_types.dart';
import '../services/recent_files_store.dart';
import 'file_viewer_page.dart';

class FileHomePage extends StatefulWidget {
  final FileService fileService;

  const FileHomePage({
    super.key,
    required this.fileService,
  });

  @override
  State<FileHomePage> createState() => FileHomePageState();
}

class FileHomePageState extends State<FileHomePage> {
  final RecentFilesStore recentStore = RecentFilesStore.instance;

  String selectedFilter = 'all';

  List<RecentFileEntry> get recentFiles {
    return recentStore.items;
  }

  @override
  void initState() {
    super.initState();
    recentStore.addListener(_onRecentChanged);
    _initRecent();
  }

  Future<void> _initRecent() async {
    await recentStore.loadFromStorage();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    recentStore.removeListener(_onRecentChanged);
    super.dispose();
  }

  void _onRecentChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  String _extensionLabel(String ext) {
    return SupportedFileTypes.labelForExtension(ext);
  }

  String _errorMessageFor(
      FileServiceErrorType errorType,
      BuildContext context,
      ) {
    final AppLocalizations t = AppLocalizations.of(context)!;
    switch (errorType) {
      case FileServiceErrorType.textEncodingUnknown:
        return t.errorTextEncodingUnknown;
      case FileServiceErrorType.textReloadFailed:
        return t.errorTextReload;
      case FileServiceErrorType.unsupportedFormat:
        return t.errorUnsupportedFormat;
      case FileServiceErrorType.fileReadFailed:
        return t.errorWhileOpeningFile;
    }
  }

  Future<void> _addRecent(ViewerFile file) async {
    await recentStore.addFromViewerFile(file);
  }

  bool _canOpenInApp(ViewerFile file) {
    return file.isSupportedForInAppView;
  }

  Future<void> _openFileViewer(ViewerFile file) async {
    final AppLocalizations t = AppLocalizations.of(context)!;

    await _addRecent(file);

    if (!mounted) {
      return;
    }

    if (_canOpenInApp(file)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => FileViewerPage(
            fileService: widget.fileService,
            initialFile: file,
          ),
        ),
      );
    } else {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.unsupportedHere),
        ),
      );
    }
  }

  Future<void> _openExplorer() async {
    final ViewerPickResult? result =
    await widget.fileService.pickFileForViewer();

    if (result == null) {
      return;
    }

    if (result.hasError || result.file == null) {
      if (!mounted) {
        return;
      }
      final AppLocalizations t = AppLocalizations.of(context)!;
      String message = t.errorWhileOpeningFile;
      if (result.errorType != null) {
        message = _errorMessageFor(
          result.errorType!,
          context,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
      return;
    }

    final ViewerFile file = result.file!;
    await _openFileViewer(file);
  }

  Future<void> _openRecent(RecentFileEntry entry) async {
    final ViewerPickResult result =
    await widget.fileService.loadFileForViewer(
      entry.actualPath,
      displayPath: entry.displayPath,
    );

    if (result.hasError || result.file == null) {
      if (!mounted) {
        return;
      }
      final AppLocalizations t = AppLocalizations.of(context)!;
      String message = t.errorWhileOpeningFile;
      if (result.errorType != null) {
        message = _errorMessageFor(
          result.errorType!,
          context,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );

      await recentStore.removeByActualPath(entry.actualPath);
      return;
    }

    final ViewerFile file = result.file!;
    await _openFileViewer(file);
  }

  Future<void> _removeRecentEntry(RecentFileEntry entry) async {
    await recentStore.removeByActualPath(entry.actualPath);
  }

  Widget _buildRecentTile(RecentFileEntry entry) {
    IconData icon;

    if (entry.extension == 'pptx') {
      icon = Icons.slideshow_outlined;
    } else if (entry.isPdf) {
      icon = Icons.picture_as_pdf_outlined;
    } else if (entry.isDocOpenXml) {
      icon = Icons.description_outlined;
    } else if (entry.isImage) {
      icon = Icons.image_outlined;
    } else if (entry.isTxt) {
      icon = Icons.notes_outlined;
    } else {
      icon = Icons.insert_drive_file_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black87,
          width: 1,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 22,
          color: Colors.grey.shade800,
        ),
        title: Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _openRecent(entry),
        trailing: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: InkWell(
            onTap: () async {
              await _removeRecentEntry(entry);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade600,
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.close,
                size: 16,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    final AppLocalizations t = AppLocalizations.of(context)!;

    final Set<String> extSet = <String>{};
    for (final RecentFileEntry e in recentFiles) {
      extSet.add(e.extension);
    }

    final List<String> sortedExt = extSet.toList()..sort();

    String effectiveFilter = selectedFilter;
    if (effectiveFilter != 'all' && !extSet.contains(effectiveFilter)) {
      effectiveFilter = 'all';
    }

    final String currentLabel =
    effectiveFilter == 'all' ? t.filterAllFiles : _extensionLabel(effectiveFilter);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double menuWidth = constraints.maxWidth;

          final List<PopupMenuEntry<String>> menuItems = <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'all',
              child: SizedBox(
                width: menuWidth,
                child: Text(t.filterAllFiles),
              ),
            ),
            for (final String ext in sortedExt)
              PopupMenuItem<String>(
                value: ext,
                child: SizedBox(
                  width: menuWidth,
                  child: Text(_extensionLabel(ext)),
                ),
              ),
          ];

          return PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                selectedFilter = value;
              });
            },
            itemBuilder: (BuildContext context) => menuItems,
            offset: const Offset(0, 40),
            constraints: BoxConstraints(
              minWidth: menuWidth,
              maxWidth: menuWidth,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      currentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredList() {
    final AppLocalizations t = AppLocalizations.of(context)!;

    List<RecentFileEntry> source = recentFiles;

    if (selectedFilter != 'all') {
      source = recentFiles
          .where((RecentFileEntry e) => e.extension == selectedFilter)
          .toList();
    }

    if (source.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            t.noFilteredFiles,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: source.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildRecentTile(source[index]);
      },
    );
  }

  Widget _buildRecentSection() {
    final AppLocalizations t = AppLocalizations.of(context)!;
    final bool hasAny = recentFiles.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          _buildFilterDropdown(),
          const Divider(height: 1),
          Expanded(
            child: hasAny
                ? _buildFilteredList()
                : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t.noRecentFiles,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExitDialog() async {
    final AppLocalizations t = AppLocalizations.of(context)!;

    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.exitDialogTitle),
          content: Text(t.exitDialogContent),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(t.exitDialogCancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(t.exitDialogConfirm),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context)!;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }
        await _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.homeTitle),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openExplorer,
                  icon: const Icon(Icons.folder_open),
                  label: Text(t.buttonOpenExplorer),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _buildRecentSection(),
              ),
            ),
            Container(
              height: 1,
              color: Colors.black26,
            ),
            SizedBox(
              height: bottomInset,
            ),
          ],
        ),
      ),
    );
  }
}
