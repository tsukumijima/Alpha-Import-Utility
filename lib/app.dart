/// アプリケーションのルートウィジェット
///
/// MaterialApp の設定とダークテーマを適用する。
/// ウィンドウの状態変更を監視し、終了時に設定を保存する。
library;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'models/settings.dart';
import 'services/settings_service.dart';
import 'services/logging_service.dart';
import 'ui/theme.dart';
import 'ui/home_screen.dart';

/// α Import Utility アプリケーション
class AlphaImportUtilityApp extends StatefulWidget {
  const AlphaImportUtilityApp({super.key});

  @override
  State<AlphaImportUtilityApp> createState() => _AlphaImportUtilityAppState();
}

class _AlphaImportUtilityAppState extends State<AlphaImportUtilityApp> with WindowListener {
  /// ロガー
  final _log = LoggingService.instance;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
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

      home: const HomeScreen(),
    );
  }
}
