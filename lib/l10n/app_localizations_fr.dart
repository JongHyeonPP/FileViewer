// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Visionneuse de fichiers';

  @override
  String get homeTitle => 'Accueil des fichiers';

  @override
  String get buttonOpenExplorer => 'Ouvrir l’explorateur';

  @override
  String get filterAllFiles => 'Tous les fichiers';

  @override
  String get noRecentFiles => 'Aucun fichier récent';

  @override
  String get noFilteredFiles => 'Aucun fichier récent pour ce filtre';

  @override
  String get exitDialogTitle => 'Quitter l’application';

  @override
  String get exitDialogContent => 'L’application se fermera si vous quittez';

  @override
  String get exitDialogCancel => 'Annuler';

  @override
  String get exitDialogConfirm => 'Quitter';

  @override
  String get viewerTitle => 'Visionneuse de fichiers';

  @override
  String get goHomeTooltip => 'Retour à l’accueil';

  @override
  String get openAnotherFileTooltip => 'Ouvrir un autre fichier';

  @override
  String get errorWhileOpeningFile =>
      'Une erreur est survenue lors de l’ouverture du fichier';

  @override
  String get errorPdfDisplay =>
      'Une erreur est survenue lors de l’affichage du PDF';

  @override
  String get errorOfficeDisplay =>
      'Une erreur est survenue lors du chargement du document Office';

  @override
  String get errorTextEncodingUnknown =>
      'Impossible de détecter l’encodage du fichier texte';

  @override
  String get errorTextReload =>
      'Une erreur est survenue lors de la réouverture du fichier texte';

  @override
  String get errorUnsupportedFormat => 'Format de fichier non pris en charge';

  @override
  String externalOpenInfo(Object fileType) {
    return 'Le fichier $fileType a été ouvert avec l’application système par défaut';
  }

  @override
  String get externalOnlyInfo =>
      'Ce type de fichier ne peut être ouvert qu’avec une application système';

  @override
  String get unsupportedHere =>
      'Ce type de fichier n’est pas pris en charge dans cette version';
}
