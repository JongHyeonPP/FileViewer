import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'파일 뷰어'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In ko, this message translates to:
  /// **'파일 홈'**
  String get homeTitle;

  /// No description provided for @buttonOpenExplorer.
  ///
  /// In ko, this message translates to:
  /// **'탐색기 열기'**
  String get buttonOpenExplorer;

  /// No description provided for @filterAllFiles.
  ///
  /// In ko, this message translates to:
  /// **'모든 파일'**
  String get filterAllFiles;

  /// No description provided for @noRecentFiles.
  ///
  /// In ko, this message translates to:
  /// **'최근 열린 파일이 없습니다'**
  String get noRecentFiles;

  /// No description provided for @noFilteredFiles.
  ///
  /// In ko, this message translates to:
  /// **'해당 조건의 최근 파일이 없습니다'**
  String get noFilteredFiles;

  /// No description provided for @exitDialogTitle.
  ///
  /// In ko, this message translates to:
  /// **'앱을 종료하시겠습니까'**
  String get exitDialogTitle;

  /// No description provided for @exitDialogContent.
  ///
  /// In ko, this message translates to:
  /// **'종료하기를 누르면 앱이 종료됩니다'**
  String get exitDialogContent;

  /// No description provided for @exitDialogCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get exitDialogCancel;

  /// No description provided for @exitDialogConfirm.
  ///
  /// In ko, this message translates to:
  /// **'종료하기'**
  String get exitDialogConfirm;

  /// No description provided for @viewerTitle.
  ///
  /// In ko, this message translates to:
  /// **'파일 뷰어'**
  String get viewerTitle;

  /// No description provided for @goHomeTooltip.
  ///
  /// In ko, this message translates to:
  /// **'홈으로 돌아가기'**
  String get goHomeTooltip;

  /// No description provided for @openAnotherFileTooltip.
  ///
  /// In ko, this message translates to:
  /// **'다른 파일 열기'**
  String get openAnotherFileTooltip;

  /// No description provided for @errorWhileOpeningFile.
  ///
  /// In ko, this message translates to:
  /// **'파일을 여는 중 오류가 발생했습니다'**
  String get errorWhileOpeningFile;

  /// No description provided for @errorPdfDisplay.
  ///
  /// In ko, this message translates to:
  /// **'PDF 표시 중 오류가 발생했습니다'**
  String get errorPdfDisplay;

  /// No description provided for @errorOfficeDisplay.
  ///
  /// In ko, this message translates to:
  /// **'오피스 문서를 불러오는 중 오류가 발생했습니다'**
  String get errorOfficeDisplay;

  /// No description provided for @errorTextEncodingUnknown.
  ///
  /// In ko, this message translates to:
  /// **'텍스트 파일의 인코딩을 알 수 없습니다'**
  String get errorTextEncodingUnknown;

  /// No description provided for @errorTextReload.
  ///
  /// In ko, this message translates to:
  /// **'텍스트 파일을 다시 여는 중 오류가 발생했습니다'**
  String get errorTextReload;

  /// No description provided for @errorUnsupportedFormat.
  ///
  /// In ko, this message translates to:
  /// **'지원하지 않는 파일 형식입니다'**
  String get errorUnsupportedFormat;

  /// No description provided for @externalOpenInfo.
  ///
  /// In ko, this message translates to:
  /// **'{fileType} 파일은 기기 기본 앱으로 열었습니다'**
  String externalOpenInfo(Object fileType);

  /// No description provided for @externalOnlyInfo.
  ///
  /// In ko, this message translates to:
  /// **'이 파일 형식은 기기 기본 앱에서만 열 수 있습니다'**
  String get externalOnlyInfo;

  /// No description provided for @unsupportedHere.
  ///
  /// In ko, this message translates to:
  /// **'현재 버전에서는 이 파일 형식을 열 수 없습니다'**
  String get unsupportedHere;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'ja',
    'ko',
    'pt',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
