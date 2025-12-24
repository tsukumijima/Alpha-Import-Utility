/// 設定の永続化サービス
///
/// Application Support ディレクトリ以下に JSON ファイルとして設定を保存する。
/// アプリケーション設定とウィンドウ設定を管理する。
///
/// 保存場所:
/// - macOS: ~/Library/Application Support/Alpha-Import-Utility/
/// - Windows: %APPDATA%/Alpha-Import-Utility/
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/settings.dart';
import 'logging_service.dart';

/// 設定ファイル名定数
const String _importSettingsFileName = 'import_settings.json';
const String _windowSettingsFileName = 'window_settings.json';

/// 設定サービス
///
/// Application Support ディレクトリに JSON ファイルとして設定を永続化する。
/// シングルトンパターンで実装し、アプリ全体で共有する。
class SettingsService {
  /// シングルトンインスタンス
  static SettingsService? _instance;

  /// 設定ディレクトリのパス
  String? _settingsDirectoryPath;

  /// キャッシュされた取り込み設定
  ImportSettings? _importSettings;

  /// キャッシュされたウィンドウ設定
  WindowSettings? _windowSettings;

  /// ロガー
  final _log = LoggingService.instance;

  /// プライベートコンストラクタ
  SettingsService._();

  /// シングルトンインスタンスを取得
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  /// 初期化
  ///
  /// アプリ起動時に一度呼び出す必要がある。
  /// 設定ディレクトリを作成し、パスを確定する。
  Future<void> initialize() async {
    _log.debug('Initializing SettingsService.', tag: 'Settings');

    final settingsDir = await _getSettingsDirectory();
    if (!await settingsDir.exists()) {
      _log.debug(
        'Creating settings directory: ${settingsDir.path}.',
        tag: 'Settings',
      );
      await settingsDir.create(recursive: true);
    }
    _settingsDirectoryPath = settingsDir.path;

    _log.info(
      'SettingsService initialized. Settings directory: $_settingsDirectoryPath.',
      tag: 'Settings',
    );
  }

  /// 設定ディレクトリを取得
  ///
  /// macOS: ~/Library/Application Support/Alpha-Import-Utility/
  /// Windows: %APPDATA%/Alpha-Import-Utility/
  Future<Directory> _getSettingsDirectory() async {
    final String basePath;

    if (Platform.isMacOS) {
      // macOS: ~/Library/Application Support/
      final home = Platform.environment['HOME'] ?? '/tmp';
      basePath = p.join(home, 'Library', 'Application Support');
    } else if (Platform.isWindows) {
      // Windows: %APPDATA%
      basePath =
          Platform.environment['APPDATA'] ??
          p.join(
            Platform.environment['USERPROFILE'] ?? '',
            'AppData',
            'Roaming',
          );
    } else {
      // Linux/その他: ~/.local/share/
      final home = Platform.environment['HOME'] ?? '/tmp';
      basePath = p.join(home, '.local', 'share');
    }

    return Directory(p.join(basePath, 'Alpha-Import-Utility'));
  }

  /// 設定サービスが初期化されているかを確認
  void _ensureInitialized() {
    if (_settingsDirectoryPath == null) {
      throw StateError(
        'SettingsService is not initialized. Call initialize() first.',
      );
    }
  }

  /// 取り込み設定のファイルパスを取得
  String get _importSettingsPath => p.join(_settingsDirectoryPath!, _importSettingsFileName);

  /// ウィンドウ設定のファイルパスを取得
  String get _windowSettingsPath => p.join(_settingsDirectoryPath!, _windowSettingsFileName);

  /// 取り込み設定を読み込む
  ///
  /// 保存された設定がない場合はデフォルト設定を返す。
  Future<ImportSettings> loadImportSettings() async {
    _ensureInitialized();

    // キャッシュがあればそれを返す
    if (_importSettings != null) {
      _log.debug('Using cached import settings.', tag: 'Settings');
      return _importSettings!;
    }

    final file = File(_importSettingsPath);
    if (!await file.exists()) {
      _log.debug(
        'No saved import settings found, using defaults.',
        tag: 'Settings',
      );
      _importSettings = ImportSettings.defaults();
      return _importSettings!;
    }

    try {
      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _importSettings = ImportSettings.fromJson(json);
      _log.info(
        'Import settings loaded: destination=${_importSettings!.destinationFolder}.',
        tag: 'Settings',
      );
      return _importSettings!;
    } catch (ex, stackTrace) {
      // JSON パースエラー - デフォルト設定を返す
      _log.error(
        'Failed to parse import settings, using defaults.',
        tag: 'Settings',
        error: ex,
        stackTrace: stackTrace,
      );
      _importSettings = ImportSettings.defaults();
      return _importSettings!;
    }
  }

  /// 取り込み設定を保存する
  Future<void> saveImportSettings(ImportSettings settings) async {
    _ensureInitialized();

    _log.debug(
      'Saving import settings: destination=${settings.destinationFolder}.',
      tag: 'Settings',
    );

    final file = File(_importSettingsPath);
    final encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(settings.toJson());
    await file.writeAsString(jsonString);

    // キャッシュを更新
    _importSettings = settings;

    _log.info('Import settings saved.', tag: 'Settings');
  }

  /// ウィンドウ設定を読み込む
  ///
  /// 保存された設定がない場合はデフォルト設定を返す。
  Future<WindowSettings> loadWindowSettings() async {
    _ensureInitialized();

    // キャッシュがあればそれを返す
    if (_windowSettings != null) {
      _log.debug('Using cached window settings.', tag: 'Settings');
      return _windowSettings!;
    }

    final file = File(_windowSettingsPath);
    if (!await file.exists()) {
      _log.debug(
        'No saved window settings found, using defaults.',
        tag: 'Settings',
      );
      _windowSettings = WindowSettings.defaults();
      return _windowSettings!;
    }

    try {
      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _windowSettings = WindowSettings.fromJson(json);
      _log.info(
        'Window settings loaded: ${_windowSettings!.width}x${_windowSettings!.height}.',
        tag: 'Settings',
      );
      return _windowSettings!;
    } catch (ex, stackTrace) {
      // JSON パースエラー - デフォルト設定を返す
      _log.error(
        'Failed to parse window settings, using defaults.',
        tag: 'Settings',
        error: ex,
        stackTrace: stackTrace,
      );
      _windowSettings = WindowSettings.defaults();
      return _windowSettings!;
    }
  }

  /// ウィンドウ設定を保存する
  Future<void> saveWindowSettings(WindowSettings settings) async {
    _ensureInitialized();

    _log.debug(
      'Saving window settings: ${settings.width}x${settings.height}.',
      tag: 'Settings',
    );

    final file = File(_windowSettingsPath);
    final encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(settings.toJson());
    await file.writeAsString(jsonString);

    // キャッシュを更新
    _windowSettings = settings;

    _log.debug('Window settings saved.', tag: 'Settings');
  }

  /// キャッシュをクリア
  ///
  /// 次回の読み込みでファイルから再読み込みする。
  void clearCache() {
    _importSettings = null;
    _windowSettings = null;
  }

  /// 設定ディレクトリのパスを取得（UI 表示用）
  String? get settingsDirectoryPath => _settingsDirectoryPath;

  /// 全ての設定を削除（デバッグ用）
  Future<void> clearAll() async {
    _ensureInitialized();

    _log.warning('Clearing all settings.', tag: 'Settings');

    final importFile = File(_importSettingsPath);
    final windowFile = File(_windowSettingsPath);

    if (await importFile.exists()) {
      await importFile.delete();
    }
    if (await windowFile.exists()) {
      await windowFile.delete();
    }

    clearCache();

    _log.info('All settings cleared.', tag: 'Settings');
  }
}
