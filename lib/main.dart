import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'services/file_service.dart';
import 'services/recent_files_store.dart';
import 'pages/file_home_page.dart';
import 'pages/file_viewer_page.dart';

void main() {
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  static const MethodChannel _initChannel =
  MethodChannel('app.channel/file_intent_init');
  static const MethodChannel _eventsChannel =
  MethodChannel('app.channel/file_intent_events');

  final FileService fileService = FileService();
  final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  String? initialFileId;
  String? initialDisplayPath;

  bool initialLoaded = false;
  bool initialFileHandled = false;

  @override
  void initState() {
    super.initState();
    _loadInitialFile();
    _eventsChannel.setMethodCallHandler(_onEvent);
  }

  Future<void> _loadInitialFile() async {
    try {
      final dynamic result =
      await _initChannel.invokeMethod<dynamic>('getInitialFile');

      String? fileId;
      String? displayPath;

      if (result is Map<dynamic, dynamic>) {
        fileId = result['fileId'] as String?;
        displayPath = result['displayPath'] as String?;
      }

      setState(() {
        initialFileId =
        (fileId != null && fileId.isNotEmpty) ? fileId : null;
        initialDisplayPath =
        (displayPath != null && displayPath.isNotEmpty)
            ? displayPath
            : null;
        initialLoaded = true;
      });
    } on PlatformException {
      setState(() {
        initialLoaded = true;
      });
    } on MissingPluginException {
      setState(() {
        initialLoaded = true;
      });
    }
  }

  Future<void> _onEvent(MethodCall call) async {
    if (call.method == 'onFileShared') {
      final dynamic args = call.arguments;

      if (args is! Map<dynamic, dynamic>) {
        return;
      }

      final String? fileId = args['fileId'] as String?;
      final String? displayPath = args['displayPath'] as String?;

      if (fileId == null || fileId.isEmpty) {
        return;
      }

      await _openSharedFile(fileId, displayPath);
    }
  }

  Future<void> _openSharedFile(
      String fileId,
      String? displayPath,
      ) async {
    final ViewerPickResult result = await fileService.loadFileForViewer(
      fileId,
      displayPath: displayPath,
    );

    if (!mounted) {
      return;
    }

    if (result.hasError || result.file == null) {
      final String message =
          result.errorMessage ?? '파일을 여는 중 오류가 발생했습니다';
      final BuildContext? context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
      }
      return;
    }

    final ViewerFile file = result.file!;

    RecentFilesStore.instance.addFromViewerFile(file);

    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FileViewerPage(
          fileService: fileService,
          initialFile: file,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget app = MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('ko'),
        Locale('en'),
        Locale('ja'),
        Locale('zh'),
        Locale('zh', 'TW'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('ru'),
        Locale('ar'),
        Locale('hi'),
        Locale('pt'),
      ],
      onGenerateTitle: (BuildContext context) =>
      AppLocalizations.of(context)!.appTitle,
      home: initialLoaded
          ? FileHomePage(
        fileService: fileService,
      )
          : const SizedBox.shrink(),
    );

    if (initialLoaded &&
        !initialFileHandled &&
        initialFileId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
            (_) {
          _openSharedFile(
            initialFileId!,
            initialDisplayPath,
          );
        },
      );
      initialFileHandled = true;
    }

    return app;
  }
}
