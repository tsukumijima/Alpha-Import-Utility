/// アプリケーションのルートウィジェット
///
/// MaterialApp の設定とダークテーマを適用する。
/// ウィンドウの状態変更を監視し、終了時に設定を保存する。
/// ローカライゼーションの管理も行う。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/generated/app_localizations.dart';
import 'models/settings.dart';
import 'services/settings_service.dart';
import 'services/logging_service.dart';
import 'ui/theme.dart';
import 'ui/home_screen.dart';

/// アプリ全体のロケール変更用 GlobalKey
final _appKey = GlobalKey<_AlphaImportUtilityAppState>();

/// α Import Utility アプリケーション
class AlphaImportUtilityApp extends StatefulWidget {
  /// コンストラクタ
  ///
  /// GlobalKey を使用してアプリ全体のロケール変更をサポートする。
  AlphaImportUtilityApp() : super(key: _appKey);

  /// アプリ全体のロケールを変更
  ///
  /// [newLocale] に指定されたロケールに即座に切り替える。
  /// 設定ダイアログなどの子ウィジェットから呼び出す。
  static void updateLocale(Locale newLocale) {
    _appKey.currentState?.updateLocale(newLocale);
  }

  @override
  State<AlphaImportUtilityApp> createState() => _AlphaImportUtilityAppState();
}

class _AlphaImportUtilityAppState extends State<AlphaImportUtilityApp> with WindowListener {
  /// ロガー
  final _log = LoggingService.instance;

  /// 現在のロケール
  ///
  /// 初期値は日本語。initState で設定から読み込んで更新する。
  Locale _locale = const Locale('ja');

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadLanguageSetting();
  }

  /// 設定から言語設定を読み込んでロケールを更新
  Future<void> _loadLanguageSetting() async {
    try {
      final settings = await SettingsService.instance.loadImportSettings();
      if (mounted) {
        setState(() => _locale = settings.language.locale);
        _log.debug('Locale loaded from settings: ${settings.language.localeCode}.', tag: 'App');
      }
    } catch (ex, stackTrace) {
      _log.error('Failed to load language setting.', tag: 'App', error: ex, stackTrace: stackTrace);
    }
  }

  /// アプリ全体のロケールを更新
  ///
  /// [newLocale] に指定されたロケールに即座に切り替える。
  /// 設定ダイアログなどから呼び出される。
  void updateLocale(Locale newLocale) {
    if (_locale != newLocale) {
      setState(() => _locale = newLocale);
      _log.info('Locale changed to: ${newLocale.languageCode}.', tag: 'App');
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// 現在のウィンドウ状態を保存
  Future<void> _saveWindowSettings() async {
    try {
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      final isMaximized = await windowManager.isMaximized();

      final settings = WindowSettings(
        width: size.width,
        height: size.height,
        positionX: position.dx,
        positionY: position.dy,
        isMaximized: isMaximized,
      );

      await SettingsService.instance.saveWindowSettings(settings);
      _log.debug(
        'Window settings saved: ${size.width.toInt()}x${size.height.toInt()} at (${position.dx.toInt()}, ${position.dy.toInt()}).',
        tag: 'App',
      );
    } catch (ex, stackTrace) {
      _log.error(
        'Failed to save window settings.',
        tag: 'App',
        error: ex,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void onWindowResized() {
    // リサイズ時に設定を保存
    _saveWindowSettings();
  }

  @override
  void onWindowMoved() {
    // 移動時に設定を保存
    _saveWindowSettings();
  }

  @override
  void onWindowMaximize() {
    // 最大化時に設定を保存
    _saveWindowSettings();
  }

  @override
  void onWindowUnmaximize() {
    // 最大化解除時に設定を保存
    _saveWindowSettings();
  }

  @override
  void onWindowClose() {
    // ウィンドウを閉じる前に設定を保存
    _saveWindowSettings();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'α Import Utility',
      debugShowCheckedModeBanner: false,

      // ダークテーマのみ使用
      theme: getAppTheme(),
      darkTheme: getAppTheme(),
      themeMode: ThemeMode.dark,

      // ローカライゼーション設定
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja'), // 日本語
        Locale('en'), // 英語
      ],

      home: const HomeScreen(),
    );
  }
}
