// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ファイルビューア';

  @override
  String get homeTitle => 'ファイルホーム';

  @override
  String get buttonOpenExplorer => 'エクスプローラーを開く';

  @override
  String get filterAllFiles => 'すべてのファイル';

  @override
  String get noRecentFiles => '最近開いたファイルはありません';

  @override
  String get noFilteredFiles => '条件に一致する最近のファイルはありません';

  @override
  String get exitDialogTitle => 'アプリを終了しますか';

  @override
  String get exitDialogContent => '終了を選択するとアプリが閉じられます';

  @override
  String get exitDialogCancel => 'キャンセル';

  @override
  String get exitDialogConfirm => '終了';

  @override
  String get viewerTitle => 'ファイルビューア';

  @override
  String get goHomeTooltip => 'ホームに戻る';

  @override
  String get openAnotherFileTooltip => '別のファイルを開く';

  @override
  String get errorWhileOpeningFile => 'ファイルを開く際にエラーが発生しました';

  @override
  String get errorPdfDisplay => 'PDF の表示中にエラーが発生しました';

  @override
  String get errorOfficeDisplay => 'Office 文書の読み込み中にエラーが発生しました';

  @override
  String get errorTextEncodingUnknown => 'テキストファイルのエンコーディングを判別できません';

  @override
  String get errorTextReload => 'テキストファイルを再読み込み中にエラーが発生しました';

  @override
  String get errorUnsupportedFormat => 'サポートされていないファイル形式です';

  @override
  String externalOpenInfo(Object fileType) {
    return '$fileType ファイルは端末の既定アプリで開きました';
  }

  @override
  String get externalOnlyInfo => 'このファイル形式は端末のアプリでのみ開けます';

  @override
  String get unsupportedHere => 'このバージョンではこのファイル形式をサポートしていません';
}
