// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Visualizador de arquivos';

  @override
  String get homeTitle => 'Início dos arquivos';

  @override
  String get buttonOpenExplorer => 'Abrir explorador';

  @override
  String get filterAllFiles => 'Todos os arquivos';

  @override
  String get noRecentFiles => 'Não há arquivos recentes';

  @override
  String get noFilteredFiles => 'Não há arquivos recentes para este filtro';

  @override
  String get exitDialogTitle => 'Sair do app';

  @override
  String get exitDialogContent => 'O app será fechado se você sair';

  @override
  String get exitDialogCancel => 'Cancelar';

  @override
  String get exitDialogConfirm => 'Sair';

  @override
  String get viewerTitle => 'Visualizador de arquivos';

  @override
  String get goHomeTooltip => 'Voltar ao início';

  @override
  String get openAnotherFileTooltip => 'Abrir outro arquivo';

  @override
  String get errorWhileOpeningFile => 'Ocorreu um erro ao abrir o arquivo';

  @override
  String get errorPdfDisplay => 'Ocorreu um erro ao exibir o PDF';

  @override
  String get errorOfficeDisplay =>
      'Ocorreu um erro ao carregar o documento do Office';

  @override
  String get errorTextEncodingUnknown =>
      'Não foi possível detectar a codificação do arquivo de texto';

  @override
  String get errorTextReload => 'Ocorreu um erro ao reabrir o arquivo de texto';

  @override
  String get errorUnsupportedFormat => 'Formato de arquivo não compatível';

  @override
  String externalOpenInfo(Object fileType) {
    return 'O arquivo $fileType foi aberto com o aplicativo padrão do sistema';
  }

  @override
  String get externalOnlyInfo =>
      'Este tipo de arquivo só pode ser aberto com um aplicativo do sistema';

  @override
  String get unsupportedHere =>
      'Este tipo de arquivo não é compatível nesta versão';
}
