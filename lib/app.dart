/// アプリケーションのルートウィジェット
///
/// MaterialApp の設定とダークテーマを適用する。
library;

import 'package:flutter/material.dart';

import 'ui/theme.dart';
import 'ui/home_screen.dart';

/// α Import Utility アプリケーション
class AlphaImportUtilityApp extends StatelessWidget {
  const AlphaImportUtilityApp({super.key});

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
