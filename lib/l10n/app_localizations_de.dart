// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Dateibetrachter';

  @override
  String get homeTitle => 'Datei Startseite';

  @override
  String get buttonOpenExplorer => 'Explorer öffnen';

  @override
  String get filterAllFiles => 'Alle Dateien';

  @override
  String get noRecentFiles => 'Keine zuletzt geöffneten Dateien';

  @override
  String get noFilteredFiles =>
      'Keine zuletzt geöffneten Dateien für diesen Filter';

  @override
  String get exitDialogTitle => 'App beenden';

  @override
  String get exitDialogContent =>
      'Die App wird geschlossen wenn Sie Beenden wählen';

  @override
  String get exitDialogCancel => 'Abbrechen';

  @override
  String get exitDialogConfirm => 'Beenden';

  @override
  String get viewerTitle => 'Dateibetrachter';

  @override
  String get goHomeTooltip => 'Zur Startseite';

  @override
  String get openAnotherFileTooltip => 'Andere Datei öffnen';

  @override
  String get errorWhileOpeningFile =>
      'Beim Öffnen der Datei ist ein Fehler aufgetreten';

  @override
  String get errorPdfDisplay =>
      'Beim Anzeigen der PDF ist ein Fehler aufgetreten';

  @override
  String get errorOfficeDisplay =>
      'Beim Laden des Office Dokuments ist ein Fehler aufgetreten';

  @override
  String get errorTextEncodingUnknown =>
      'Textkodierung der Datei kann nicht erkannt werden';

  @override
  String get errorTextReload =>
      'Beim erneuten Öffnen der Textdatei ist ein Fehler aufgetreten';

  @override
  String get errorUnsupportedFormat => 'Nicht unterstütztes Dateiformat';

  @override
  String externalOpenInfo(Object fileType) {
    return 'Die Datei $fileType wurde mit der Standard System App geöffnet';
  }

  @override
  String get externalOnlyInfo =>
      'Dieser Dateityp kann nur mit einer System App geöffnet werden';

  @override
  String get unsupportedHere =>
      'Dieser Dateityp wird in dieser Version nicht unterstützt';
}
