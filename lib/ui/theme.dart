/// アプリケーションテーマ定義
///
/// ダークモードオンリーの黒基調 UI テーマを定義する。
library;

import 'package:flutter/material.dart';

/// アプリケーションのダークテーマを取得
ThemeData getAppTheme() {
  // Sony α のイメージカラー（オレンジ）をアクセントカラーとして使用
  const sonyOrange = Color(0xfff26c2b);

  // Flutter は明示的に日本語フォントを指定しないと fontWeight の指定が効かないらしい
  // ref: https://github.com/flutter/flutter/issues/179104#issuecomment-3580632879
  const fontFamilyFallback = <String>['Hiragino Sans', 'Noto Sans JP', 'Noto Sans CJK JP'];

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamilyFallback: fontFamilyFallback,

    // カラースキーム
    colorScheme: ColorScheme.fromSeed(
      seedColor: sonyOrange,
      brightness: Brightness.dark,
      // カスタマイズ
      surface: const Color(0xFF1A1A1A),
      onSurface: Colors.white,
      primary: sonyOrange,
      onPrimary: Colors.black,
      secondary: const Color(0xFF90CAF9),
      onSecondary: Colors.black,
      error: const Color(0xFFCF6679),
      onError: Colors.black,
    ),

    // スキャフォールド背景色（グラデーション用のベース）
    scaffoldBackgroundColor: const Color(0xFF121212),

    // アプリバー
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        fontFamilyFallback: fontFamilyFallback,
      ),
    ),

    // カード
    cardTheme: CardThemeData(
      color: const Color(0xFF2A2A2A),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // エレベーテッドボタン
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: sonyOrange,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamilyFallback: fontFamilyFallback,
        ),
      ),
    ),

    // テキストボタン
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: sonyOrange,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),

    // アウトラインボタン
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    // プログレスインジケーター
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: sonyOrange,
      linearTrackColor: Color(0xFF3A3A3A),
    ),

    // ダイアログ
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF2A2A2A),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        fontFamilyFallback: fontFamilyFallback,
      ),
    ),

    // スナックバー
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF3A3A3A),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),

    // 入力フィールド
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: sonyOrange, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.white70, fontFamilyFallback: fontFamilyFallback),
      hintStyle: const TextStyle(color: Colors.white38, fontFamilyFallback: fontFamilyFallback),
    ),

    // ドロップダウン
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    ),

    // スイッチ
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return sonyOrange;
        }
        return Colors.white70;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return sonyOrange.withValues(alpha: 0.5);
        }
        return Colors.white24;
      }),
    ),

    // リスト
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white70,
    ),

    // 分割線
    dividerTheme: const DividerThemeData(
      color: Colors.white12,
      thickness: 1,
    ),

    // アイコン
    iconTheme: const IconThemeData(
      color: Colors.white70,
      size: 24,
    ),

    // テキストテーマ
    // height は line-height の設定。1.5 は 150% を意味する。
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        height: 1.3,
        fontFamilyFallback: fontFamilyFallback,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        height: 1.3,
        fontFamilyFallback: fontFamilyFallback,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        height: 1.3,
        fontFamilyFallback: fontFamilyFallback,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.4,
        fontFamilyFallback: fontFamilyFallback,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.4,
        fontFamilyFallback: fontFamilyFallback,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.4,
        fontFamilyFallback: fontFamilyFallback,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.4,
        fontFamilyFallback: fontFamilyFallback,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.5,
        fontFamilyFallback: fontFamilyFallback,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.5,
        fontFamilyFallback: fontFamilyFallback,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Colors.white,
        height: 1.6,
        fontFamilyFallback: fontFamilyFallback,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Colors.white,
        height: 1.6,
        fontFamilyFallback: fontFamilyFallback,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: Colors.white70,
        height: 1.6,
        fontFamilyFallback: fontFamilyFallback,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.5,
        fontFamilyFallback: fontFamilyFallback,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.5,
        fontFamilyFallback: fontFamilyFallback,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Colors.white70,
        height: 1.5,
        fontFamilyFallback: fontFamilyFallback,
      ),
    ),
  );
}

/// グラデーション背景を持つコンテナを作成
///
/// ダークモードでの奥行き感を出すための微妙なグラデーション。
BoxDecoration getGradientBackground() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1C1C1C),
        Color(0xFF121212),
        Color(0xFF080808),
      ],
    ),
  );
}
