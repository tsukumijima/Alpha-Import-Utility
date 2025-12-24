/// 基本的なウィジェットテスト
///
/// アプリケーションの起動テストを行う。
///
/// 注意: このテストは HomeScreen が DeviceDetector を起動するため、
/// タイマーのクリーンアップに特別な処理が必要。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alpha_import_utility/app.dart';
import 'package:alpha_import_utility/services/settings_service.dart';

void main() {
  /// テスト前に SharedPreferences をモックする
  setUpAll(() async {
    // テスト用の空の SharedPreferences をセットアップ
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App starts correctly', (WidgetTester tester) async {
    // SettingsService を初期化
    await SettingsService.instance.initialize();

    // アプリをビルド
    await tester.pumpWidget(const AlphaImportUtilityApp());

    // 初期化処理の完了を待つ
    await tester.pump(const Duration(milliseconds: 100));

    // アプリタイトルが表示されていることを確認
    expect(find.text('α Import Utility'), findsOneWidget);

    // ウィジェットツリーを適切にクリーンアップ（ペンディングタイマーを解消）
    // 空のウィジェットに置き換えて HomeScreen を dispose させ、
    // DeviceDetector のポーリングを停止させる
    await tester.pumpWidget(const SizedBox.shrink());

    // DeviceDetector のスキャンタイムアウト（10秒）と
    // ポーリング間隔（5秒）のタイマーを全て消化する
    // runAsync を使用して実際の Future を完了させる
    await tester.runAsync(() async {
      // タイマーを消化するために十分な時間待機
      await Future.delayed(const Duration(milliseconds: 50));
    });

    // 残りのフレームを処理
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));
  });
}
