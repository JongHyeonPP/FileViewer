// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'File Viewer';

  @override
  String get homeTitle => 'File Home';

  @override
  String get buttonOpenExplorer => 'Open explorer';

  @override
  String get filterAllFiles => 'All files';

  @override
  String get noRecentFiles => 'No recent files';

  @override
  String get noFilteredFiles => 'No files for this filter';

  @override
  String get exitDialogTitle => 'Exit app';

  @override
  String get exitDialogContent => 'The app will close if you choose to exit';

  @override
  String get exitDialogCancel => 'Cancel';

  @override
  String get exitDialogConfirm => 'Exit';

  @override
  String get viewerTitle => 'File viewer';

  @override
  String get goHomeTooltip => 'Back to home';

  @override
  String get openAnotherFileTooltip => 'Open another file';

  @override
  String get errorWhileOpeningFile =>
      'An error occurred while opening the file';

  @override
  String get errorPdfDisplay => 'An error occurred while displaying the PDF';

  @override
  String get errorOfficeDisplay =>
      'An error occurred while loading the office document';

  @override
  String get errorTextEncodingUnknown => 'Cannot detect text file encoding';

  @override
  String get errorTextReload =>
      'An error occurred while reopening the text file';

  @override
  String get errorUnsupportedFormat => 'Unsupported file format';

  @override
  String externalOpenInfo(Object fileType) {
    return '$fileType file was opened with default system app';
  }

  @override
  String get externalOnlyInfo =>
      'This file type can only be opened with a system viewer';

  @override
  String get unsupportedHere =>
      'This file type is not supported in this version';
}
