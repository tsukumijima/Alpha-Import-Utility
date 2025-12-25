/// 設定関連のモデル定義
///
/// 取り込み設定やアプリケーション設定を保持する。
library;

import 'package:json_annotation/json_annotation.dart';

part 'settings.g.dart';

/// サブフォルダのパターン
///
/// 取り込み先でのフォルダ階層構造を決定する。
enum SubfolderPattern {
  /// 日付のみ（例: 2025_12_24/）
  DateOnly,

  /// 年/日付（例: 2025/2025_12_24/）
  YearAndDate,

  /// 年/月/日付（例: 2025/12/2025_12_24/）
  YearMonthAndDate,
}

/// SubfolderPattern の拡張メソッド
extension SubfolderPatternExtension on SubfolderPattern {
  /// 日本語での表示名
  String get displayName {
    switch (this) {
      case SubfolderPattern.DateOnly:
        return '日付のみ';
      case SubfolderPattern.YearAndDate:
        return '年/日付';
      case SubfolderPattern.YearMonthAndDate:
        return '年/月/日付';
    }
  }

  /// パターンの例を取得
  ///
  /// [dateFormat] と [separator] を使用して実際の例を生成する
  String getExample(DateFormatStyle dateFormat, DateSeparator separator) {
    // 2025/12/24 を例として使用
    final dateStr = dateFormat.formatDate(2025, 12, 24, separator);

    switch (this) {
      case SubfolderPattern.DateOnly:
        return dateStr;
      case SubfolderPattern.YearAndDate:
        return '2025/$dateStr';
      case SubfolderPattern.YearMonthAndDate:
        return '2025/12/$dateStr';
    }
  }
}

/// 日付フォーマットのスタイル
enum DateFormatStyle {
  /// 4 桁年（例: 2025_12_24）
  YYYYMMDD,

  /// 2 桁年（例: 25_12_24）
  YYMMDD,
}

/// DateFormatStyle の拡張メソッド
extension DateFormatStyleExtension on DateFormatStyle {
  /// 日本語での表示名
  String get displayName {
    switch (this) {
      case DateFormatStyle.YYYYMMDD:
        return 'YYYY_MM_DD（4桁年）';
      case DateFormatStyle.YYMMDD:
        return 'YY_MM_DD（2桁年）';
    }
  }

  /// 日付をフォーマットする
  ///
  /// [year], [month], [day] を指定された [separator] で結合する
  String formatDate(int year, int month, int day, DateSeparator separator) {
    final sep = separator.character;
    final yearStr = this == DateFormatStyle.YYYYMMDD ? year.toString() : (year % 100).toString().padLeft(2, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final dayStr = day.toString().padLeft(2, '0');

    return '$yearStr$sep$monthStr$sep$dayStr';
  }
}

/// 日付の区切り文字
enum DateSeparator {
  /// 区切りなし（例: 20251224）
  None,

  /// アンダースコア（例: 2025_12_24）
  Underscore,

  /// ハイフン（例: 2025-12-24）
  Hyphen,
}

/// DateSeparator の拡張メソッド
extension DateSeparatorExtension on DateSeparator {
  /// 区切り文字を取得
  String get character {
    switch (this) {
      case DateSeparator.None:
        return '';
      case DateSeparator.Underscore:
        return '_';
      case DateSeparator.Hyphen:
        return '-';
    }
  }

  /// 日本語での表示名
  String get displayName {
    switch (this) {
      case DateSeparator.None:
        return 'なし（20251224）';
      case DateSeparator.Underscore:
        return 'アンダースコア（2025_12_24）';
      case DateSeparator.Hyphen:
        return 'ハイフン（2025-12-24）';
    }
  }
}

/// 取り込み設定を保持するクラス
///
/// ユーザーが設定する取り込み動作のパラメータ。
@JsonSerializable()
class ImportSettings {
  /// 保存先ベースフォルダ
  ///
  /// Windows: 'D:\カメラ写真' など
  /// macOS: '/Volumes/JISAKU9/D/カメラ写真' など
  final String destinationFolder;

  /// サブフォルダのパターン
  final SubfolderPattern subfolderPattern;

  /// 日付フォーマットのスタイル
  final DateFormatStyle dateFormat;

  /// 日付の区切り文字
  final DateSeparator dateSeparator;

  /// 取り込み前のプレビューを表示するか
  ///
  /// スキャン完了後に取り込み対象の一覧を表示し、続行するか確認する。
  final bool isShowImportPreview;

  /// EXIF からファイル日時を復元するか
  ///
  /// true の場合、コピー後のファイルの作成日時・更新日時を EXIF の撮影日時に合わせる。
  final bool isRestoreDateTimeFromExif;

  /// 日時復元の許容誤差（秒）
  ///
  /// ファイル日時と EXIF 日時の差がこの秒数以内であれば復元済みとみなしてスキップする。
  final int dateRestoreToleranceSeconds;

  /// カメラのタイムゾーン（IANA 形式、例: 'Asia/Tokyo'）
  ///
  /// カメラ内部時刻がどのタイムゾーンで記録されているかを指定する。
  /// 通常はカメラの設定と一致させるべき。
  final String cameraTimezone;

  /// 動画 XML ファイルを取り込むか
  ///
  /// NonRealTimeMeta 形式の XML ファイル。
  /// 内容は MP4 本体にも埋め込まれているため、通常は不要。
  final bool isImportVideoXML;

  /// プロキシー動画を取り込むか
  ///
  /// PRIVATE/M4ROOT/SUB/ にある低解像度動画。
  /// 編集ソフトでのプレビュー用途に使用される。
  final bool isImportProxyVideos;

  ImportSettings({
    required this.destinationFolder,
    this.subfolderPattern = SubfolderPattern.DateOnly,
    this.dateFormat = DateFormatStyle.YYYYMMDD,
    this.dateSeparator = DateSeparator.Underscore,
    this.isShowImportPreview = false,
    this.isRestoreDateTimeFromExif = true,
    this.dateRestoreToleranceSeconds = 30,
    this.cameraTimezone = 'Asia/Tokyo',
    this.isImportVideoXML = true,
    this.isImportProxyVideos = true,
  });

  /// デフォルト設定を取得
  ///
  /// 保存先フォルダは空文字列（初回起動時に設定を促す）
  factory ImportSettings.defaults() {
    return ImportSettings(destinationFolder: '');
  }

  /// JSON からデシリアライズ
  factory ImportSettings.fromJson(Map<String, dynamic> json) => _$ImportSettingsFromJson(json);

  /// JSON にシリアライズ
  Map<String, dynamic> toJson() => _$ImportSettingsToJson(this);

  /// 設定をコピーして一部を変更した新しいインスタンスを作成
  ImportSettings copyWith({
    String? destinationFolder,
    SubfolderPattern? subfolderPattern,
    DateFormatStyle? dateFormat,
    DateSeparator? dateSeparator,
    bool? isShowImportPreview,
    bool? isRestoreDateTimeFromExif,
    int? dateRestoreToleranceSeconds,
    String? cameraTimezone,
    bool? isImportVideoXML,
    bool? isImportProxyVideos,
  }) {
    return ImportSettings(
      destinationFolder: destinationFolder ?? this.destinationFolder,
      subfolderPattern: subfolderPattern ?? this.subfolderPattern,
      dateFormat: dateFormat ?? this.dateFormat,
      dateSeparator: dateSeparator ?? this.dateSeparator,
      isShowImportPreview: isShowImportPreview ?? this.isShowImportPreview,
      isRestoreDateTimeFromExif: isRestoreDateTimeFromExif ?? this.isRestoreDateTimeFromExif,
      dateRestoreToleranceSeconds: dateRestoreToleranceSeconds ?? this.dateRestoreToleranceSeconds,
      cameraTimezone: cameraTimezone ?? this.cameraTimezone,
      isImportVideoXML: isImportVideoXML ?? this.isImportVideoXML,
      isImportProxyVideos: isImportProxyVideos ?? this.isImportProxyVideos,
    );
  }

  /// 保存先フォルダが設定されているか
  bool get hasDestinationFolder => destinationFolder.isNotEmpty;

  /// 指定した日時からサブフォルダパスを生成
  ///
  /// [dateTime] を元に設定に従ったフォルダパスを返す
  String generateSubfolderPath(DateTime dateTime) {
    final dateStr = dateFormat.formatDate(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateSeparator,
    );

    switch (subfolderPattern) {
      case SubfolderPattern.DateOnly:
        return dateStr;
      case SubfolderPattern.YearAndDate:
        return '${dateTime.year}/$dateStr';
      case SubfolderPattern.YearMonthAndDate:
        final monthStr = dateTime.month.toString().padLeft(2, '0');
        return '${dateTime.year}/$monthStr/$dateStr';
    }
  }

  @override
  String toString() {
    return 'ImportSettings(destination: $destinationFolder, pattern: $subfolderPattern)';
  }
}

/// ウィンドウ設定を保持するクラス
///
/// ウィンドウのサイズと位置を保存・復元するために使用。
@JsonSerializable()
class WindowSettings {
  /// ウィンドウの幅
  final double width;

  /// ウィンドウの高さ
  final double height;

  /// ウィンドウの X 座標（左端からの距離）
  final double? positionX;

  /// ウィンドウの Y 座標（上端からの距離）
  final double? positionY;

  /// ウィンドウが最大化されているか
  final bool isMaximized;

  WindowSettings({
    this.width = 640,
    this.height = 700,
    this.positionX,
    this.positionY,
    this.isMaximized = false,
  });

  /// デフォルト設定を取得
  factory WindowSettings.defaults() {
    return WindowSettings();
  }

  /// JSON からデシリアライズ
  factory WindowSettings.fromJson(Map<String, dynamic> json) => _$WindowSettingsFromJson(json);

  /// JSON にシリアライズ
  Map<String, dynamic> toJson() => _$WindowSettingsToJson(this);

  /// 設定をコピーして一部を変更
  WindowSettings copyWith({
    double? width,
    double? height,
    double? positionX,
    double? positionY,
    bool? isMaximized,
  }) {
    return WindowSettings(
      width: width ?? this.width,
      height: height ?? this.height,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      isMaximized: isMaximized ?? this.isMaximized,
    );
  }
}
