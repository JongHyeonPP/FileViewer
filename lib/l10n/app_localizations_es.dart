// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Visor de archivos';

  @override
  String get homeTitle => 'Inicio de archivos';

  @override
  String get buttonOpenExplorer => 'Abrir explorador';

  @override
  String get filterAllFiles => 'Todos los archivos';

  @override
  String get noRecentFiles => 'No hay archivos recientes';

  @override
  String get noFilteredFiles => 'No hay archivos recientes para este filtro';

  @override
  String get exitDialogTitle => 'Salir de la app';

  @override
  String get exitDialogContent => 'La app se cerrará si eliges salir';

  @override
  String get exitDialogCancel => 'Cancelar';

  @override
  String get exitDialogConfirm => 'Salir';

  @override
  String get viewerTitle => 'Visor de archivos';

  @override
  String get goHomeTooltip => 'Volver al inicio';

  @override
  String get openAnotherFileTooltip => 'Abrir otro archivo';

  @override
  String get errorWhileOpeningFile => 'Se produjo un error al abrir el archivo';

  @override
  String get errorPdfDisplay => 'Se produjo un error al mostrar el PDF';

  @override
  String get errorOfficeDisplay =>
      'Se produjo un error al cargar el documento de Office';

  @override
  String get errorTextEncodingUnknown =>
      'No se puede detectar la codificación del archivo de texto';

  @override
  String get errorTextReload =>
      'Se produjo un error al volver a abrir el archivo de texto';

  @override
  String get errorUnsupportedFormat => 'Formato de archivo no compatible';

  @override
  String externalOpenInfo(Object fileType) {
    return 'El archivo $fileType se abrió con la aplicación predeterminada del sistema';
  }

  @override
  String get externalOnlyInfo =>
      'Este tipo de archivo solo puede abrirse con una aplicación del sistema';

  @override
  String get unsupportedHere =>
      'Este tipo de archivo no es compatible en esta versión';
}
