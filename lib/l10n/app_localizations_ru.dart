// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Просмотрщик файлов';

  @override
  String get homeTitle => 'Главная файлов';

  @override
  String get buttonOpenExplorer => 'Открыть проводник';

  @override
  String get filterAllFiles => 'Все файлы';

  @override
  String get noRecentFiles => 'Нет недавних файлов';

  @override
  String get noFilteredFiles => 'Нет недавних файлов для этого фильтра';

  @override
  String get exitDialogTitle => 'Выйти из приложения';

  @override
  String get exitDialogContent =>
      'Приложение будет закрыто если вы выберете выход';

  @override
  String get exitDialogCancel => 'Отмена';

  @override
  String get exitDialogConfirm => 'Выйти';

  @override
  String get viewerTitle => 'Просмотрщик файлов';

  @override
  String get goHomeTooltip => 'На главный экран';

  @override
  String get openAnotherFileTooltip => 'Открыть другой файл';

  @override
  String get errorWhileOpeningFile => 'Произошла ошибка при открытии файла';

  @override
  String get errorPdfDisplay => 'Произошла ошибка при отображении PDF';

  @override
  String get errorOfficeDisplay =>
      'Произошла ошибка при загрузке документа Office';

  @override
  String get errorTextEncodingUnknown =>
      'Не удалось определить кодировку текстового файла';

  @override
  String get errorTextReload =>
      'Произошла ошибка при повторном открытии текстового файла';

  @override
  String get errorUnsupportedFormat => 'Неподдерживаемый формат файла';

  @override
  String externalOpenInfo(Object fileType) {
    return 'Файл $fileType открыт стандартным приложением системы';
  }

  @override
  String get externalOnlyInfo =>
      'Этот тип файла можно открыть только системным приложением';

  @override
  String get unsupportedHere =>
      'Этот тип файла не поддерживается в этой версии';
}
