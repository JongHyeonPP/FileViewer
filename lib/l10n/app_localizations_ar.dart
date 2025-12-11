// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'عارض الملفات';

  @override
  String get homeTitle => 'الصفحة الرئيسية للملفات';

  @override
  String get buttonOpenExplorer => 'فتح المستكشف';

  @override
  String get filterAllFiles => 'كل الملفات';

  @override
  String get noRecentFiles => 'لا توجد ملفات حديثة';

  @override
  String get noFilteredFiles => 'لا توجد ملفات حديثة لهذا المرشح';

  @override
  String get exitDialogTitle => 'إنهاء التطبيق';

  @override
  String get exitDialogContent => 'سيتم إغلاق التطبيق إذا اخترت الإنهاء';

  @override
  String get exitDialogCancel => 'إلغاء';

  @override
  String get exitDialogConfirm => 'إنهاء';

  @override
  String get viewerTitle => 'عارض الملفات';

  @override
  String get goHomeTooltip => 'الرجوع إلى الصفحة الرئيسية';

  @override
  String get openAnotherFileTooltip => 'فتح ملف آخر';

  @override
  String get errorWhileOpeningFile => 'حدث خطأ أثناء فتح الملف';

  @override
  String get errorPdfDisplay => 'حدث خطأ أثناء عرض ملف PDF';

  @override
  String get errorOfficeDisplay => 'حدث خطأ أثناء تحميل مستند Office';

  @override
  String get errorTextEncodingUnknown => 'يتعذر تحديد ترميز ملف النص';

  @override
  String get errorTextReload => 'حدث خطأ أثناء إعادة فتح ملف النص';

  @override
  String get errorUnsupportedFormat => 'تنسيق ملف غير مدعوم';

  @override
  String externalOpenInfo(Object fileType) {
    return 'تم فتح ملف $fileType باستخدام تطبيق النظام الافتراضي';
  }

  @override
  String get externalOnlyInfo =>
      'لا يمكن فتح هذا النوع من الملفات إلا باستخدام تطبيق النظام';

  @override
  String get unsupportedHere => 'هذا النوع من الملفات غير مدعوم في هذا الإصدار';
}
