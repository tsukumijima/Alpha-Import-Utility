/// 設定の永続化サービス
///
/// SharedPreferences を使用して設定を保存・読み込みする。
/// アプリケーション設定とウィンドウ設定を管理する。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

/// SharedPreferences のキー定数
const String _importSettingsKey = 'import_settings';
const String _windowSettingsKey = 'window_settings';

/// 設定サービス
///
/// SharedPreferences を使用して設定を永続化する。
/// シングルトンパターンで実装し、アプリ全体で共有する。
class SettingsService {
  /// シングルトンインスタンス
  static SettingsService? _instance;

  /// SharedPreferences インスタンス
  SharedPreferences? _prefs;

  /// キャッシュされた取り込み設定
  ImportSettings? _importSettings;

  /// キャッシュされたウィンドウ設定
  WindowSettings? _windowSettings;

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
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// SharedPreferences が初期化されているかを確認
  void _ensureInitialized() {
    if (_prefs == null) {
      throw StateError(
        'SettingsService is not initialized. Call initialize() first.',
      );
    }
  }

  /// 取り込み設定を読み込む
  ///
  /// 保存された設定がない場合はデフォルト設定を返す。
  Future<ImportSettings> loadImportSettings() async {
    _ensureInitialized();

    // キャッシュがあればそれを返す
    if (_importSettings != null) {
      return _importSettings!;
    }

    final jsonString = _prefs!.getString(_importSettingsKey);
    if (jsonString == null) {
      _importSettings = ImportSettings.defaults();
      return _importSettings!;
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _importSettings = ImportSettings.fromJson(json);
      return _importSettings!;
    } catch (_) {
      // JSON パースエラー - デフォルト設定を返す
      _importSettings = ImportSettings.defaults();
      return _importSettings!;
    }
  }

  /// 取り込み設定を保存する
  Future<void> saveImportSettings(ImportSettings settings) async {
    _ensureInitialized();

    final jsonString = jsonEncode(settings.toJson());
    await _prefs!.setString(_importSettingsKey, jsonString);

    // キャッシュを更新
    _importSettings = settings;
  }

  /// ウィンドウ設定を読み込む
  ///
  /// 保存された設定がない場合はデフォルト設定を返す。
  Future<WindowSettings> loadWindowSettings() async {
    _ensureInitialized();

    // キャッシュがあればそれを返す
    if (_windowSettings != null) {
      return _windowSettings!;
    }

    final jsonString = _prefs!.getString(_windowSettingsKey);
    if (jsonString == null) {
      _windowSettings = WindowSettings.defaults();
      return _windowSettings!;
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _windowSettings = WindowSettings.fromJson(json);
      return _windowSettings!;
    } catch (_) {
      // JSON パースエラー - デフォルト設定を返す
      _windowSettings = WindowSettings.defaults();
      return _windowSettings!;
    }
  }

  /// ウィンドウ設定を保存する
  Future<void> saveWindowSettings(WindowSettings settings) async {
    _ensureInitialized();

    final jsonString = jsonEncode(settings.toJson());
    await _prefs!.setString(_windowSettingsKey, jsonString);

    // キャッシュを更新
    _windowSettings = settings;
  }

  /// キャッシュをクリア
  ///
  /// 次回の読み込みで SharedPreferences から再読み込みする。
  void clearCache() {
    _importSettings = null;
    _windowSettings = null;
  }

  /// 全ての設定を削除（デバッグ用）
  Future<void> clearAll() async {
    _ensureInitialized();

    await _prefs!.remove(_importSettingsKey);
    await _prefs!.remove(_windowSettingsKey);

    clearCache();
  }
}
