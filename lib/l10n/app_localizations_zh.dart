// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '文件查看器';

  @override
  String get homeTitle => '文件主页';

  @override
  String get buttonOpenExplorer => '打开文件管理器';

  @override
  String get filterAllFiles => '所有文件';

  @override
  String get noRecentFiles => '没有最近打开的文件';

  @override
  String get noFilteredFiles => '没有符合条件的最近文件';

  @override
  String get exitDialogTitle => '退出应用';

  @override
  String get exitDialogContent => '选择退出后应用将关闭';

  @override
  String get exitDialogCancel => '取消';

  @override
  String get exitDialogConfirm => '退出';

  @override
  String get viewerTitle => '文件查看器';

  @override
  String get goHomeTooltip => '返回主页';

  @override
  String get openAnotherFileTooltip => '打开其他文件';

  @override
  String get errorWhileOpeningFile => '打开文件时发生错误';

  @override
  String get errorPdfDisplay => '显示 PDF 时发生错误';

  @override
  String get errorOfficeDisplay => '加载 Office 文档时发生错误';

  @override
  String get errorTextEncodingUnknown => '无法识别文本文件的编码';

  @override
  String get errorTextReload => '重新打开文本文件时发生错误';

  @override
  String get errorUnsupportedFormat => '不支持的文件格式';

  @override
  String externalOpenInfo(Object fileType) {
    return '$fileType 文件已用系统默认应用打开';
  }

  @override
  String get externalOnlyInfo => '此文件格式只能用系统应用打开';

  @override
  String get unsupportedHere => '当前版本不支持此文件格式';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => '檔案檢視器';

  @override
  String get homeTitle => '檔案首頁';

  @override
  String get buttonOpenExplorer => '開啟檔案管理器';

  @override
  String get filterAllFiles => '所有檔案';

  @override
  String get noRecentFiles => '沒有最近開啟的檔案';

  @override
  String get noFilteredFiles => '沒有符合條件的最近檔案';

  @override
  String get exitDialogTitle => '結束應用程式';

  @override
  String get exitDialogContent => '選擇結束後應用程式將關閉';

  @override
  String get exitDialogCancel => '取消';

  @override
  String get exitDialogConfirm => '結束';

  @override
  String get viewerTitle => '檔案檢視器';

  @override
  String get goHomeTooltip => '返回首頁';

  @override
  String get openAnotherFileTooltip => '開啟其他檔案';

  @override
  String get errorWhileOpeningFile => '開啟檔案時發生錯誤';

  @override
  String get errorPdfDisplay => '顯示 PDF 時發生錯誤';

  @override
  String get errorOfficeDisplay => '載入 Office 文件時發生錯誤';

  @override
  String get errorTextEncodingUnknown => '無法辨識文字檔的編碼';

  @override
  String get errorTextReload => '重新開啟文字檔時發生錯誤';

  @override
  String get errorUnsupportedFormat => '不支援的檔案格式';

  @override
  String externalOpenInfo(Object fileType) {
    return '已使用系統預設應用程式開啟 $fileType 檔案';
  }

  @override
  String get externalOnlyInfo => '此檔案格式僅能使用系統應用程式開啟';

  @override
  String get unsupportedHere => '目前版本不支援此檔案格式';
}
