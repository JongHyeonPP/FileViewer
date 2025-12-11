// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '파일 뷰어';

  @override
  String get homeTitle => '파일 홈';

  @override
  String get buttonOpenExplorer => '탐색기 열기';

  @override
  String get filterAllFiles => '모든 파일';

  @override
  String get noRecentFiles => '최근 열린 파일이 없습니다';

  @override
  String get noFilteredFiles => '해당 조건의 최근 파일이 없습니다';

  @override
  String get exitDialogTitle => '앱을 종료하시겠습니까';

  @override
  String get exitDialogContent => '종료하기를 누르면 앱이 종료됩니다';

  @override
  String get exitDialogCancel => '취소';

  @override
  String get exitDialogConfirm => '종료하기';

  @override
  String get viewerTitle => '파일 뷰어';

  @override
  String get goHomeTooltip => '홈으로 돌아가기';

  @override
  String get openAnotherFileTooltip => '다른 파일 열기';

  @override
  String get errorWhileOpeningFile => '파일을 여는 중 오류가 발생했습니다';

  @override
  String get errorPdfDisplay => 'PDF 표시 중 오류가 발생했습니다';

  @override
  String get errorOfficeDisplay => '오피스 문서를 불러오는 중 오류가 발생했습니다';

  @override
  String get errorTextEncodingUnknown => '텍스트 파일의 인코딩을 알 수 없습니다';

  @override
  String get errorTextReload => '텍스트 파일을 다시 여는 중 오류가 발생했습니다';

  @override
  String get errorUnsupportedFormat => '지원하지 않는 파일 형식입니다';

  @override
  String externalOpenInfo(Object fileType) {
    return '$fileType 파일은 기기 기본 앱으로 열었습니다';
  }

  @override
  String get externalOnlyInfo => '이 파일 형식은 기기 기본 앱에서만 열 수 있습니다';

  @override
  String get unsupportedHere => '현재 버전에서는 이 파일 형식을 열 수 없습니다';
}
