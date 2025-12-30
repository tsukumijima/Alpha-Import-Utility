// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get tooltip_refresh => '更新';

  @override
  String get tooltip_settings => '設定';

  @override
  String get tooltip_selectFolder => 'フォルダを選択';

  @override
  String get tooltip_close => '閉じる';

  @override
  String get home_scanningDevices => 'デバイスをスキャン中...';

  @override
  String get home_sectionCamera_title => 'カメラから取り込み';

  @override
  String get home_sectionCamera_description => 'USB ケーブルで接続されたカメラから直接写真・動画を取り込みます。';

  @override
  String get home_sectionCamera_empty => 'カメラが接続されていません';

  @override
  String get home_sectionCamera_emptyHint => 'USB ケーブルでカメラを接続してください';

  @override
  String get home_sectionSDCard_title => 'SD カードから取り込み';

  @override
  String get home_sectionSDCard_description => 'SD カードリーダーを使用して、SD カードから写真・動画を取り込みます。';

  @override
  String get home_sectionSDCard_empty => 'SD カードが挿入されていません';

  @override
  String get home_sectionSDCard_emptyHint => 'SD カードをカードリーダーに挿入してください';

  @override
  String get home_sectionFolder_title => 'フォルダから取り込み';

  @override
  String get home_sectionFolder_description => 'PC 上のフォルダを直接選択して取り込みます。過去のバックアップからの取り込みに便利です。';

  @override
  String get home_sectionFolder_selectButton => 'フォルダを選択 ...';

  @override
  String get home_sectionFolder_selectHint => 'Sony α カメラの SD カードのバックアップフォルダを選択してください';

  @override
  String get home_filePicker_title => 'インポート元フォルダを選択';

  @override
  String get home_invalidSdCard => '選択されたフォルダは Sony α カメラの SD カード構造として認識できませんでした。';

  @override
  String get deviceCard_notRecognized => 'このデバイスは Sony α カメラの SD カード構造として認識できませんでした。';

  @override
  String get deviceCard_noDevices => 'デバイスが検出されていません';

  @override
  String get deviceCard_connectHint => 'SD カードまたはカメラを接続してください';

  @override
  String get deviceCard_manualSelect => 'フォルダを手動選択';

  @override
  String deviceCard_storageDetail(String total, String used, String free) {
    return '$total（使用: $used / 空き: $free）';
  }

  @override
  String get settings_title => '設定';

  @override
  String get settings_tab_basic => '基本設定';

  @override
  String get settings_tab_options => '取り込みオプション';

  @override
  String get settings_language_title => '言語';

  @override
  String get settings_language_description => 'アプリの表示言語を選択します。';

  @override
  String get settings_language_label => '言語';

  @override
  String get settings_language_option_japanese => '日本語';

  @override
  String get settings_language_option_english => '英語';

  @override
  String get settings_destinationFolder_title => '保存先フォルダ';

  @override
  String get settings_destinationFolder_description => '取り込んだ写真・動画を保存するフォルダを指定します。';

  @override
  String get settings_destinationFolder_hint => 'フォルダを選択してください';

  @override
  String get settings_destinationFolder_picker => '保存先フォルダを選択';

  @override
  String get settings_destinationFolder_notSet => '(保存先未設定)';

  @override
  String get settings_subfolder_title => 'サブフォルダ設定';

  @override
  String get settings_subfolder_description => '撮影日ごとにサブフォルダを作成するパターンを選択します。';

  @override
  String get settings_subfolder_label => 'パターン';

  @override
  String get settings_dateFormat_title => '日付フォーマット';

  @override
  String get settings_dateFormat_description => 'サブフォルダ名に使用する日付の表記形式を指定します。';

  @override
  String get settings_dateFormat_yearLabel => '年の形式';

  @override
  String get settings_dateFormat_separatorLabel => '区切り文字';

  @override
  String get settings_preview_title => 'プレビュー';

  @override
  String get settings_importPreview_title => '取り込み前プレビュー';

  @override
  String get settings_importPreview_description => 'スキャン完了後に取り込み対象の一覧を表示し、続行するか確認します。';

  @override
  String get settings_importPreview_switch => '取り込み前にプレビューを表示';

  @override
  String get settings_dateRestore_title => 'ファイル日時の復元';

  @override
  String get settings_dateRestore_description => 'コピー後のファイルの作成日時・更新日時を、EXIF に記録された撮影日時に合わせます。';

  @override
  String get settings_dateRestore_switch => 'EXIF から日時を復元';

  @override
  String get settings_timezone_title => 'カメラタイムゾーン';

  @override
  String get settings_timezone_description =>
      'ファイル日時の復元時に利用する、カメラに設定されているタイムゾーンを指定します。\nEXIF にタイムゾーン情報が含まれている場合は、その値を優先します。\nEXIF にタイムゾーン情報がない場合のみ、この設定がフォールバックとして利用されます。\n日本国内で使用している場合は「東京」を選択してください。';

  @override
  String get settings_timezone_label => 'タイムゾーン';

  @override
  String get settings_videoMeta_title => '動画メタデータ';

  @override
  String get settings_videoMeta_description =>
      '動画ファイル (.MP4) に付随する XML メタデータ (例: C0001M01.XML) も取り込みます。\n動画単体で利活用する分には不要ですが、ソニー純正ソフトとの互換性のため、取り込むことを推奨します。';

  @override
  String get settings_videoMeta_switch => '動画メタデータ (XML) を取り込む';

  @override
  String get settings_proxyVideo_title => 'プロキシー動画';

  @override
  String get settings_proxyVideo_description =>
      'オリジナルの動画ファイルと同時に生成された、低解像度のプロキシー動画\n(PRIVATE/M4ROOT/SUB/ フォルダ内) も取り込みます。';

  @override
  String get settings_proxyVideo_switch => 'プロキシー動画を取り込む';

  @override
  String get button_cancel => 'キャンセル';

  @override
  String get button_save => '保存';

  @override
  String get button_close => '閉じる';

  @override
  String get button_continue => '続行';

  @override
  String get button_openSettings => '設定を開く';

  @override
  String get button_openDestination => '保存先を開く';

  @override
  String get destinationNotSet_title => '保存先フォルダが未設定です';

  @override
  String get destinationNotSet_message => '取り込みを開始する前に、保存先フォルダを設定してください。';

  @override
  String get import_dialog_preview => '取り込み前プレビュー';

  @override
  String get import_dialog_completed => '取り込み完了';

  @override
  String get import_dialog_cancelled => '取り込み中断';

  @override
  String get import_dialog_error => '取り込みエラー';

  @override
  String get import_cancelConfirm_title => '取り込みをキャンセルしますか？';

  @override
  String get import_cancelConfirm_preparing => 'スキャンを中止してダイアログを閉じます。';

  @override
  String get import_cancelConfirm_preview => '取り込みを開始せずにプレビューを閉じます。';

  @override
  String get import_cancelConfirm_importing => '現在コピー中のファイルが完了してから停止します。';

  @override
  String import_previewTargetCount(String deviceName, int count) {
    return '$deviceName の取り込み対象: $count 件';
  }

  @override
  String import_fromDevice(String deviceName, String statusText) {
    return '$deviceName から$statusText';
  }

  @override
  String import_previewSource(String path) {
    return '取り込み元: $path';
  }

  @override
  String import_previewDestination(String path) {
    return '取り込み先: $path';
  }

  @override
  String get import_result_abortReason => '中断理由';

  @override
  String import_result_warnings(int count) {
    return '警告 ($count件)';
  }

  @override
  String progress_scanningCount(int count) {
    return 'スキャン中（$count 件）';
  }

  @override
  String get progress_scanning => 'スキャン中...';

  @override
  String progress_fileCount(int current, int total) {
    return '$current / $total 件';
  }

  @override
  String get progress_phase_scanningMediaFiles => 'メディアファイルをスキャン中...';

  @override
  String get progress_phase_checkingDiskSpace => '保存先の容量を確認中...';

  @override
  String get progress_phase_importing => '取り込み中...';

  @override
  String get progress_phase_checkingDestinationFolder => '保存先フォルダを確認中...';

  @override
  String get progress_phase_checkingDestinationDuplicate => '保存先の重複を確認中...';

  @override
  String get progress_phase_parsingExif => ' EXIF を解析中...';

  @override
  String get result_success => '成功';

  @override
  String get result_skipped => 'スキップ';

  @override
  String get result_warning => '警告';

  @override
  String get result_error => 'エラー';

  @override
  String result_countUnit(int count) {
    return '$count 件';
  }

  @override
  String result_duration(String duration) {
    return '処理時間: $duration';
  }

  @override
  String result_durationHoursMinutes(int hours, int minutes) {
    return '$hours時間$minutes分';
  }

  @override
  String result_durationMinutesSeconds(int minutes, int seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String result_durationSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String get result_status_cancelled => '取り込みがキャンセルされました';

  @override
  String get result_status_error => '取り込み中にエラーが発生しました';

  @override
  String get result_status_noNewFiles => '新しいファイルはありませんでした';

  @override
  String get result_status_completed => '取り込みが完了しました';

  @override
  String get error_metadataUpdateFailed => 'メタデータの更新に失敗したため取り込みを中断しました。';

  @override
  String get error_importCancelled => '取り込みがキャンセルされました。';

  @override
  String get error_nativeApiUnavailable => 'ファイル日時の取得または復元に必要なネイティブ API が利用できないため取り込みを中断しました。';

  @override
  String get error_fileIOFailed => 'ファイルの読み書きに失敗したため取り込みを中断しました。';

  @override
  String error_fileIOFailedWithName(String fileName) {
    return 'ファイルの読み書きに失敗したため取り込みを中断しました。ファイル: $fileName。';
  }

  @override
  String get error_genericImportFailed => '取り込み中にエラーが発生したため中断しました。';

  @override
  String get error_browserOpenFailed => 'ブラウザを開けませんでした。';

  @override
  String get error_diskSpaceReadFailed => '保存先の空き容量を取得できないため取り込みを中断しました。';

  @override
  String get error_noSpaceLeft => '保存先の空き容量が不足しているため取り込みを中断しました。';

  @override
  String error_noSpaceLeftWithName(String fileName) {
    return '保存先の空き容量が不足しているため取り込みを中断しました。ファイル: $fileName。';
  }

  @override
  String error_noSpaceLeftWithSize(String required, String available) {
    return '保存先の空き容量が不足しているため取り込みを中断しました。必要: $required、空き: $available。';
  }

  @override
  String get error_destinationPathFailed => 'コピー先パスを確定できないため取り込みを中断しました。';

  @override
  String get update_error_checkFailed => 'アップデートの確認に失敗しました。';

  @override
  String get update_error_releaseNotFound => 'リリースが見つかりませんでした。';

  @override
  String update_error_apiFailed(int statusCode) {
    return 'GitHub API エラー ($statusCode)';
  }

  @override
  String update_message(String version) {
    return '新しいバージョン $version が利用可能です。';
  }

  @override
  String get update_message_prefix => '新しいバージョン ';

  @override
  String get update_message_suffix => ' が利用可能です。';

  @override
  String get update_download => ' ダウンロード';

  @override
  String get enum_SubfolderPattern_DateOnly => '日付のみ';

  @override
  String get enum_SubfolderPattern_YearAndDate => '年/日付';

  @override
  String get enum_SubfolderPattern_YearMonthAndDate => '年/月/日付';

  @override
  String get enum_DateFormatStyle_YYYYMMDD => 'YYYY_MM_DD（4桁年）';

  @override
  String get enum_DateFormatStyle_YYMMDD => 'YY_MM_DD（2桁年）';

  @override
  String get enum_DateSeparator_None => 'なし（20251224）';

  @override
  String get enum_DateSeparator_Underscore => 'アンダースコア（2025_12_24）';

  @override
  String get enum_DateSeparator_Hyphen => 'ハイフン（2025-12-24）';

  @override
  String get enum_MediaType_JPEGPhoto => 'JPEG 写真';

  @override
  String get enum_MediaType_RAWPhoto => 'RAW 写真';

  @override
  String get enum_MediaType_HEIFPhoto => 'HEIF 写真';

  @override
  String get enum_MediaType_Video => '動画';

  @override
  String get enum_MediaType_ProxyVideo => 'プロキシー動画';

  @override
  String get enum_MediaType_VideoMeta => '動画メタデータ';

  @override
  String get enum_MediaType_Unknown => '未知のファイル';

  @override
  String get enum_ImportWarningType_DuplicateRenamed => '別名で保存';

  @override
  String get enum_ImportWarningType_ExifReadFailed => 'EXIF 読み取り失敗';

  @override
  String get enum_ImportWarningType_DateRestoreFailed => '日時復元失敗';

  @override
  String get enum_ImportWarningType_HashVerificationFailed => 'ハッシュ検証失敗';

  @override
  String get enum_ImportWarningType_MetadataUpdateSkipped => 'メタデータ更新スキップ';

  @override
  String get enum_ImportWarningType_UnknownExtensionFound => '未知の拡張子';

  @override
  String get enum_ImportWarningType_FileInUseSkipped => '使用中ファイルをスキップ';

  @override
  String get enum_ImportPhase_Initializing_dialogTitle => '準備中...';

  @override
  String get enum_ImportPhase_ValidatingSDCard_dialogTitle => 'SD カードを検証中...';

  @override
  String get enum_ImportPhase_CheckingWritePermission_dialogTitle => 'SD カードを検証中...';

  @override
  String get enum_ImportPhase_ScanningMediaFiles_dialogTitle => 'メディアをスキャン中...';

  @override
  String get enum_ImportPhase_DeterminingTargets_dialogTitle => '取り込み対象を判定中...';

  @override
  String get enum_ImportPhase_ParsingExif_dialogTitle => 'EXIF を解析中...';

  @override
  String get enum_ImportPhase_CheckingDestination_dialogTitle => '保存先を確認中...';

  @override
  String get enum_ImportPhase_CheckingDiskSpace_dialogTitle => '容量を確認中...';

  @override
  String get enum_ImportPhase_Importing_dialogTitle => '取り込み中...';

  @override
  String get enum_ImportPhase_Initializing_statusText => '準備中...';

  @override
  String get enum_ImportPhase_ValidatingSDCard_statusText => 'SD カード構造を検証中...';

  @override
  String get enum_ImportPhase_CheckingWritePermission_statusText => '書き込み可能性を確認中...';

  @override
  String get enum_ImportPhase_ScanningMediaFiles_statusText => 'スキャン中...';

  @override
  String get enum_ImportPhase_DeterminingTargets_statusText => '取り込み対象を判定中...';

  @override
  String get enum_ImportPhase_ParsingExif_statusText => 'EXIF を解析中...';

  @override
  String get enum_ImportPhase_CheckingDestination_statusText => '保存先を確認中...';

  @override
  String get enum_ImportPhase_CheckingDiskSpace_statusText => '容量を確認中...';

  @override
  String get enum_ImportPhase_Importing_statusText => 'コピー中...';

  @override
  String get tz_honolulu => 'ホノルル';

  @override
  String get tz_anchorage => 'アンカレッジ';

  @override
  String get tz_losAngeles => 'ロサンゼルス';

  @override
  String get tz_denver => 'デンバー';

  @override
  String get tz_chicago => 'シカゴ';

  @override
  String get tz_newYork => 'ニューヨーク';

  @override
  String get tz_saoPaulo => 'サンパウロ';

  @override
  String get tz_azores => 'アゾレス';

  @override
  String get tz_utc => 'UTC';

  @override
  String get tz_london => 'ロンドン';

  @override
  String get tz_paris => 'パリ';

  @override
  String get tz_berlin => 'ベルリン';

  @override
  String get tz_athens => 'アテネ';

  @override
  String get tz_moscow => 'モスクワ';

  @override
  String get tz_dubai => 'ドバイ';

  @override
  String get tz_karachi => 'カラチ';

  @override
  String get tz_kolkata => 'コルカタ';

  @override
  String get tz_dhaka => 'ダッカ';

  @override
  String get tz_bangkok => 'バンコク';

  @override
  String get tz_singapore => 'シンガポール';

  @override
  String get tz_hongKong => '香港';

  @override
  String get tz_shanghai => '上海';

  @override
  String get tz_tokyo => '東京';

  @override
  String get tz_seoul => 'ソウル';

  @override
  String get tz_sydney => 'シドニー';

  @override
  String get tz_auckland => 'オークランド';
}
