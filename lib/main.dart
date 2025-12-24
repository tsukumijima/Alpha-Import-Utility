/// α Import Utility - エントリポイント
///
/// Sony α カメラの SD カードから未取り込みの写真・動画を
/// PC に自動インポートする Flutter Desktop アプリ。
library;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/settings_service.dart';
import 'services/logging_service.dart';

/// アプリケーションのエントリポイント
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ロギングサービスの初期化（最優先）
  await LoggingService.instance.initialize();

  // ウィンドウマネージャの初期化
  await windowManager.ensureInitialized();
  LoggingService.instance.debug('Window manager initialized.', tag: 'Main');

  // 設定サービスの初期化
  await SettingsService.instance.initialize();
  LoggingService.instance.debug('Settings service initialized.', tag: 'Main');

  // ウィンドウ設定を読み込んで適用
  final windowSettings = await SettingsService.instance.loadWindowSettings();
  LoggingService.instance.debug(
    'Window settings loaded: ${windowSettings.width}x${windowSettings.height}.',
    tag: 'Main',
  );

  // ウィンドウオプションの設定
  final windowOptions = WindowOptions(
    size: Size(windowSettings.width, windowSettings.height),
    minimumSize: const Size(640, 700),
    center: windowSettings.positionX == null,
    title: 'α Import Utility',
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 保存された位置があれば復元
    if (windowSettings.positionX != null && windowSettings.positionY != null) {
      await windowManager.setPosition(
        Offset(windowSettings.positionX!, windowSettings.positionY!),
      );
    }

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
