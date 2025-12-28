/// α Import Utility - エントリポイント
///
/// Sony α カメラの SD カードから未取り込みの写真・動画を
/// PC に自動インポートする Flutter Desktop アプリ。
library;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'models/settings.dart';
import 'services/logging_service.dart';
import 'services/settings_service.dart';

/// アプリケーションのエントリポイント
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ロギングサービスの初期化（最優先）
  await LoggingService.instance.initialize();

  // 設定サービスの初期化
  await SettingsService.instance.initialize();
  LoggingService.instance.debug('Settings service initialized.', tag: 'Main');

  // ウィンドウマネージャの初期化
  await windowManager.ensureInitialized();
  LoggingService.instance.debug('Window manager initialized.', tag: 'Main');

  // ウィンドウ設定を読み込んで適用
  final windowSettings = await SettingsService.instance.loadWindowSettings();
  LoggingService.instance.debug(
    'Window settings loaded: ${windowSettings.width}x${windowSettings.height}.',
    tag: 'Main',
  );

  final hasSavedPosition = windowSettings.positionX != null && windowSettings.positionY != null;

  if (hasSavedPosition) {
    await windowManager.setPosition(
      Offset(windowSettings.positionX!, windowSettings.positionY!),
    );
  }

  // ウィンドウオプションの設定
  final windowOptions = WindowOptions(
    size: Size(windowSettings.width, windowSettings.height),
    minimumSize: Size(windowMinWidth, windowMinHeight),
    center: hasSavedPosition == false,
    title: 'α Import Utility',
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 最大化状態を復元
    if (windowSettings.isMaximized) {
      await windowManager.maximize();
    }

    await windowManager.show();
    await windowManager.focus();
  });

  LoggingService.instance.info('Window ready, starting application.', tag: 'Main');

  runApp(const AlphaImportUtilityApp());
}
