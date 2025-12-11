// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'फ़ाइल व्यूअर';

  @override
  String get homeTitle => 'फ़ाइल होम';

  @override
  String get buttonOpenExplorer => 'एक्सप्लोरर खोलें';

  @override
  String get filterAllFiles => 'सभी फ़ाइलें';

  @override
  String get noRecentFiles => 'हाल की कोई फ़ाइल नहीं';

  @override
  String get noFilteredFiles => 'इस फ़िल्टर के लिए हाल की कोई फ़ाइल नहीं';

  @override
  String get exitDialogTitle => 'ऐप से बाहर निकलें';

  @override
  String get exitDialogContent => 'बाहर निकलने पर ऐप बंद हो जाएगा';

  @override
  String get exitDialogCancel => 'रद्द करें';

  @override
  String get exitDialogConfirm => 'बाहर निकलें';

  @override
  String get viewerTitle => 'फ़ाइल व्यूअर';

  @override
  String get goHomeTooltip => 'होम पर वापस जाएँ';

  @override
  String get openAnotherFileTooltip => 'दूसरी फ़ाइल खोलें';

  @override
  String get errorWhileOpeningFile => 'फ़ाइल खोलते समय त्रुटि हुई';

  @override
  String get errorPdfDisplay => 'PDF दिखाते समय त्रुटि हुई';

  @override
  String get errorOfficeDisplay => 'Office दस्तावेज़ लोड करते समय त्रुटि हुई';

  @override
  String get errorTextEncodingUnknown =>
      'टेक्स्ट फ़ाइल की एन्कोडिंग का पता नहीं चला';

  @override
  String get errorTextReload => 'टेक्स्ट फ़ाइल फिर से खोलते समय त्रुटि हुई';

  @override
  String get errorUnsupportedFormat => 'असमर्थित फ़ाइल फ़ॉर्मैट';

  @override
  String externalOpenInfo(Object fileType) {
    return '$fileType फ़ाइल सिस्टम की डिफ़ॉल्ट ऐप से खोली गई';
  }

  @override
  String get externalOnlyInfo =>
      'इस फ़ाइल प्रकार को केवल सिस्टम ऐप से खोला जा सकता है';

  @override
  String get unsupportedHere =>
      'यह फ़ाइल प्रकार इस संस्करण में समर्थित नहीं है';
}
