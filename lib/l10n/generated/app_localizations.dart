import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('ja')];

  /// No description provided for @tooltip_refresh.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get tooltip_refresh;

  /// No description provided for @tooltip_settings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get tooltip_settings;

  /// No description provided for @tooltip_selectFolder.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを選択'**
  String get tooltip_selectFolder;

  /// No description provided for @tooltip_close.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get tooltip_close;

  /// No description provided for @home_scanningDevices.
  ///
  /// In ja, this message translates to:
  /// **'デバイスをスキャン中...'**
  String get home_scanningDevices;

  /// No description provided for @home_sectionCamera_title.
  ///
  /// In ja, this message translates to:
  /// **'カメラから取り込み'**
  String get home_sectionCamera_title;

  /// No description provided for @home_sectionCamera_description.
  ///
  /// In ja, this message translates to:
  /// **'USB ケーブルで接続されたカメラから直接写真・動画を取り込みます。'**
  String get home_sectionCamera_description;

  /// No description provided for @home_sectionCamera_empty.
  ///
  /// In ja, this message translates to:
  /// **'カメラが接続されていません'**
  String get home_sectionCamera_empty;

  /// No description provided for @home_sectionCamera_emptyHint.
  ///
  /// In ja, this message translates to:
  /// **'USB ケーブルでカメラを接続してください'**
  String get home_sectionCamera_emptyHint;

  /// No description provided for @home_sectionSDCard_title.
  ///
  /// In ja, this message translates to:
  /// **'SD カードから取り込み'**
  String get home_sectionSDCard_title;

  /// No description provided for @home_sectionSDCard_description.
  ///
  /// In ja, this message translates to:
  /// **'SD カードリーダーを使用して、SD カードから写真・動画を取り込みます。'**
  String get home_sectionSDCard_description;

  /// No description provided for @home_sectionSDCard_empty.
  ///
  /// In ja, this message translates to:
  /// **'SD カードが挿入されていません'**
  String get home_sectionSDCard_empty;

  /// No description provided for @home_sectionSDCard_emptyHint.
  ///
  /// In ja, this message translates to:
  /// **'SD カードをカードリーダーに挿入してください'**
  String get home_sectionSDCard_emptyHint;

  /// No description provided for @home_sectionFolder_title.
  ///
  /// In ja, this message translates to:
  /// **'フォルダから取り込み'**
  String get home_sectionFolder_title;

  /// No description provided for @home_sectionFolder_description.
  ///
  /// In ja, this message translates to:
  /// **'PC 上のフォルダを直接選択して取り込みます。過去のバックアップからの取り込みに便利です。'**
  String get home_sectionFolder_description;

  /// No description provided for @home_sectionFolder_selectButton.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを選択 ...'**
  String get home_sectionFolder_selectButton;

  /// No description provided for @home_sectionFolder_selectHint.
  ///
  /// In ja, this message translates to:
  /// **'Sony α カメラの SD カードのバックアップフォルダを選択してください'**
  String get home_sectionFolder_selectHint;

  /// No description provided for @home_filePicker_title.
  ///
  /// In ja, this message translates to:
  /// **'インポート元フォルダを選択'**
  String get home_filePicker_title;

  /// No description provided for @home_invalidSdCard.
  ///
  /// In ja, this message translates to:
  /// **'選択されたフォルダは Sony α カメラの SD カード構造として認識できませんでした。'**
  String get home_invalidSdCard;

  /// No description provided for @deviceCard_notRecognized.
  ///
  /// In ja, this message translates to:
  /// **'このデバイスは Sony α カメラの SD カード構造として認識できませんでした。'**
  String get deviceCard_notRecognized;

  /// No description provided for @deviceCard_noDevices.
  ///
  /// In ja, this message translates to:
  /// **'デバイスが検出されていません'**
  String get deviceCard_noDevices;

  /// No description provided for @deviceCard_connectHint.
  ///
  /// In ja, this message translates to:
  /// **'SD カードまたはカメラを接続してください'**
  String get deviceCard_connectHint;

  /// No description provided for @deviceCard_manualSelect.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを手動選択'**
  String get deviceCard_manualSelect;

  /// No description provided for @deviceCard_storageDetail.
  ///
  /// In ja, this message translates to:
  /// **'{total}（使用: {used} / 空き: {free}）'**
  String deviceCard_storageDetail(String total, String used, String free);

  /// No description provided for @settings_title.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settings_title;

  /// No description provided for @settings_tab_basic.
  ///
  /// In ja, this message translates to:
  /// **'基本設定'**
  String get settings_tab_basic;

  /// No description provided for @settings_tab_options.
  ///
  /// In ja, this message translates to:
  /// **'取り込みオプション'**
  String get settings_tab_options;

  /// No description provided for @settings_language_title.
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get settings_language_title;

  /// No description provided for @settings_language_description.
  ///
  /// In ja, this message translates to:
  /// **'アプリの表示言語を選択します。'**
  String get settings_language_description;

  /// No description provided for @settings_language_label.
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get settings_language_label;

  /// No description provided for @settings_language_option_japanese.
  ///
  /// In ja, this message translates to:
  /// **'日本語'**
  String get settings_language_option_japanese;

  /// No description provided for @settings_language_option_english.
  ///
  /// In ja, this message translates to:
  /// **'英語'**
  String get settings_language_option_english;

  /// No description provided for @settings_destinationFolder_title.
  ///
  /// In ja, this message translates to:
  /// **'保存先フォルダ'**
  String get settings_destinationFolder_title;

  /// No description provided for @settings_destinationFolder_description.
  ///
  /// In ja, this message translates to:
  /// **'取り込んだ写真・動画を保存するフォルダを指定します。'**
  String get settings_destinationFolder_description;

  /// No description provided for @settings_destinationFolder_hint.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを選択してください'**
  String get settings_destinationFolder_hint;

  /// No description provided for @settings_destinationFolder_picker.
  ///
  /// In ja, this message translates to:
  /// **'保存先フォルダを選択'**
  String get settings_destinationFolder_picker;

  /// No description provided for @settings_destinationFolder_notSet.
  ///
  /// In ja, this message translates to:
  /// **'(保存先未設定)'**
  String get settings_destinationFolder_notSet;

  /// No description provided for @settings_subfolder_title.
  ///
  /// In ja, this message translates to:
  /// **'サブフォルダ設定'**
  String get settings_subfolder_title;

  /// No description provided for @settings_subfolder_description.
  ///
  /// In ja, this message translates to:
  /// **'撮影日ごとにサブフォルダを作成するパターンを選択します。'**
  String get settings_subfolder_description;

  /// No description provided for @settings_subfolder_label.
  ///
  /// In ja, this message translates to:
  /// **'パターン'**
  String get settings_subfolder_label;

  /// No description provided for @settings_dateFormat_title.
  ///
  /// In ja, this message translates to:
  /// **'日付フォーマット'**
  String get settings_dateFormat_title;

  /// No description provided for @settings_dateFormat_description.
  ///
  /// In ja, this message translates to:
  /// **'サブフォルダ名に使用する日付の表記形式を指定します。'**
  String get settings_dateFormat_description;

  /// No description provided for @settings_dateFormat_yearLabel.
  ///
  /// In ja, this message translates to:
  /// **'年の形式'**
  String get settings_dateFormat_yearLabel;

  /// No description provided for @settings_dateFormat_separatorLabel.
  ///
  /// In ja, this message translates to:
  /// **'区切り文字'**
  String get settings_dateFormat_separatorLabel;

  /// No description provided for @settings_preview_title.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー'**
  String get settings_preview_title;

  /// No description provided for @settings_importPreview_title.
  ///
  /// In ja, this message translates to:
  /// **'取り込み前プレビュー'**
  String get settings_importPreview_title;

  /// No description provided for @settings_importPreview_description.
  ///
  /// In ja, this message translates to:
  /// **'スキャン完了後に取り込み対象の一覧を表示し、続行するか確認します。'**
  String get settings_importPreview_description;

  /// No description provided for @settings_importPreview_switch.
  ///
  /// In ja, this message translates to:
  /// **'取り込み前にプレビューを表示'**
  String get settings_importPreview_switch;

  /// No description provided for @settings_dateRestore_title.
  ///
  /// In ja, this message translates to:
  /// **'ファイル日時の復元'**
  String get settings_dateRestore_title;

  /// No description provided for @settings_dateRestore_description.
  ///
  /// In ja, this message translates to:
  /// **'コピー後のファイルの作成日時・更新日時を、EXIF に記録された撮影日時に合わせます。'**
  String get settings_dateRestore_description;

  /// No description provided for @settings_dateRestore_switch.
  ///
  /// In ja, this message translates to:
  /// **'EXIF から日時を復元'**
  String get settings_dateRestore_switch;

  /// No description provided for @settings_timezone_title.
  ///
  /// In ja, this message translates to:
  /// **'カメラタイムゾーン'**
  String get settings_timezone_title;

  /// No description provided for @settings_timezone_description.
  ///
  /// In ja, this message translates to:
  /// **'ファイル日時の復元時に利用する、カメラに設定されているタイムゾーンを指定します。\nEXIF にタイムゾーン情報が含まれている場合は、その値を優先します。\nEXIF にタイムゾーン情報がない場合のみ、この設定がフォールバックとして利用されます。\n日本国内で使用している場合は「東京」を選択してください。'**
  String get settings_timezone_description;

  /// No description provided for @settings_timezone_label.
  ///
  /// In ja, this message translates to:
  /// **'タイムゾーン'**
  String get settings_timezone_label;

  /// No description provided for @settings_videoMeta_title.
  ///
  /// In ja, this message translates to:
  /// **'動画メタデータ'**
  String get settings_videoMeta_title;

  /// No description provided for @settings_videoMeta_description.
  ///
  /// In ja, this message translates to:
  /// **'動画ファイル (.MP4) に付随する XML メタデータ (例: C0001M01.XML) も取り込みます。\n動画単体で利活用する分には不要ですが、ソニー純正ソフトとの互換性のため、取り込むことを推奨します。'**
  String get settings_videoMeta_description;

  /// No description provided for @settings_videoMeta_switch.
  ///
  /// In ja, this message translates to:
  /// **'動画メタデータ (XML) を取り込む'**
  String get settings_videoMeta_switch;

  /// No description provided for @settings_proxyVideo_title.
  ///
  /// In ja, this message translates to:
  /// **'プロキシー動画'**
  String get settings_proxyVideo_title;

  /// No description provided for @settings_proxyVideo_description.
  ///
  /// In ja, this message translates to:
  /// **'オリジナルの動画ファイルと同時に生成された、低解像度のプロキシー動画\n(PRIVATE/M4ROOT/SUB/ フォルダ内) も取り込みます。'**
  String get settings_proxyVideo_description;

  /// No description provided for @settings_proxyVideo_switch.
  ///
  /// In ja, this message translates to:
  /// **'プロキシー動画を取り込む'**
  String get settings_proxyVideo_switch;

  /// No description provided for @button_cancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get button_cancel;

  /// No description provided for @button_save.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get button_save;

  /// No description provided for @button_close.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get button_close;

  /// No description provided for @button_continue.
  ///
  /// In ja, this message translates to:
  /// **'続行'**
  String get button_continue;

  /// No description provided for @button_openSettings.
  ///
  /// In ja, this message translates to:
  /// **'設定を開く'**
  String get button_openSettings;

  /// No description provided for @button_openDestination.
  ///
  /// In ja, this message translates to:
  /// **'保存先を開く'**
  String get button_openDestination;

  /// No description provided for @destinationNotSet_title.
  ///
  /// In ja, this message translates to:
  /// **'保存先フォルダが未設定です'**
  String get destinationNotSet_title;

  /// No description provided for @destinationNotSet_message.
  ///
  /// In ja, this message translates to:
  /// **'取り込みを開始する前に、保存先フォルダを設定してください。'**
  String get destinationNotSet_message;

  /// No description provided for @import_dialog_preview.
  ///
  /// In ja, this message translates to:
  /// **'取り込み前プレビュー'**
  String get import_dialog_preview;

  /// No description provided for @import_dialog_completed.
  ///
  /// In ja, this message translates to:
  /// **'取り込み完了'**
  String get import_dialog_completed;

  /// No description provided for @import_dialog_cancelled.
  ///
  /// In ja, this message translates to:
  /// **'取り込み中断'**
  String get import_dialog_cancelled;

  /// No description provided for @import_cancelConfirm_title.
  ///
  /// In ja, this message translates to:
  /// **'取り込みをキャンセルしますか？'**
  String get import_cancelConfirm_title;

  /// No description provided for @import_cancelConfirm_preparing.
  ///
  /// In ja, this message translates to:
  /// **'スキャンを中止してダイアログを閉じます。'**
  String get import_cancelConfirm_preparing;

  /// No description provided for @import_cancelConfirm_preview.
  ///
  /// In ja, this message translates to:
  /// **'取り込みを開始せずにプレビューを閉じます。'**
  String get import_cancelConfirm_preview;

  /// No description provided for @import_cancelConfirm_importing.
  ///
  /// In ja, this message translates to:
  /// **'現在コピー中のファイルが完了してから停止します。'**
  String get import_cancelConfirm_importing;

  /// No description provided for @import_previewTargetCount.
  ///
  /// In ja, this message translates to:
  /// **'{deviceName} の取り込み対象: {count} 件'**
  String import_previewTargetCount(String deviceName, int count);

  /// No description provided for @import_fromDevice.
  ///
  /// In ja, this message translates to:
  /// **'{deviceName} から{statusText}'**
  String import_fromDevice(String deviceName, String statusText);

  /// No description provided for @import_previewSource.
  ///
  /// In ja, this message translates to:
  /// **'取り込み元: {path}'**
  String import_previewSource(String path);

  /// No description provided for @import_previewDestination.
  ///
  /// In ja, this message translates to:
  /// **'取り込み先: {path}'**
  String import_previewDestination(String path);

  /// No description provided for @import_result_abortReason.
  ///
  /// In ja, this message translates to:
  /// **'中断理由'**
  String get import_result_abortReason;

  /// No description provided for @import_result_warnings.
  ///
  /// In ja, this message translates to:
  /// **'警告 ({count}件)'**
  String import_result_warnings(int count);

  /// No description provided for @progress_scanningCount.
  ///
  /// In ja, this message translates to:
  /// **'スキャン中（{count} 件）'**
  String progress_scanningCount(int count);

  /// No description provided for @progress_scanning.
  ///
  /// In ja, this message translates to:
  /// **'スキャン中...'**
  String get progress_scanning;

  /// No description provided for @progress_fileCount.
  ///
  /// In ja, this message translates to:
  /// **'{current} / {total} 件'**
  String progress_fileCount(int current, int total);

  /// No description provided for @progress_phase_scanningMediaFiles.
  ///
  /// In ja, this message translates to:
  /// **'メディアファイルをスキャン中...'**
  String get progress_phase_scanningMediaFiles;

  /// No description provided for @progress_phase_checkingDiskSpace.
  ///
  /// In ja, this message translates to:
  /// **'保存先の容量を確認中...'**
  String get progress_phase_checkingDiskSpace;

  /// No description provided for @progress_phase_importing.
  ///
  /// In ja, this message translates to:
  /// **'取り込み中...'**
  String get progress_phase_importing;

  /// No description provided for @progress_phase_checkingDestinationFolder.
  ///
  /// In ja, this message translates to:
  /// **'保存先フォルダを確認中...'**
  String get progress_phase_checkingDestinationFolder;

  /// No description provided for @progress_phase_checkingDestinationDuplicate.
  ///
  /// In ja, this message translates to:
  /// **'保存先の重複を確認中...'**
  String get progress_phase_checkingDestinationDuplicate;

  /// No description provided for @progress_phase_parsingExif.
  ///
  /// In ja, this message translates to:
  /// **' EXIF を解析中...'**
  String get progress_phase_parsingExif;

  /// No description provided for @result_success.
  ///
  /// In ja, this message translates to:
  /// **'成功'**
  String get result_success;

  /// No description provided for @result_skipped.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get result_skipped;

  /// No description provided for @result_warning.
  ///
  /// In ja, this message translates to:
  /// **'警告'**
  String get result_warning;

  /// No description provided for @result_error.
  ///
  /// In ja, this message translates to:
  /// **'エラー'**
  String get result_error;

  /// No description provided for @result_countUnit.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件'**
  String result_countUnit(int count);

  /// No description provided for @result_duration.
  ///
  /// In ja, this message translates to:
  /// **'処理時間: {duration}'**
  String result_duration(String duration);

  /// No description provided for @result_durationHoursMinutes.
  ///
  /// In ja, this message translates to:
  /// **'{hours}時間{minutes}分'**
  String result_durationHoursMinutes(int hours, int minutes);

  /// No description provided for @result_durationMinutesSeconds.
  ///
  /// In ja, this message translates to:
  /// **'{minutes}分{seconds}秒'**
  String result_durationMinutesSeconds(int minutes, int seconds);

  /// No description provided for @result_durationSeconds.
  ///
  /// In ja, this message translates to:
  /// **'{seconds}秒'**
  String result_durationSeconds(int seconds);

  /// No description provided for @result_status_cancelled.
  ///
  /// In ja, this message translates to:
  /// **'取り込みがキャンセルされました'**
  String get result_status_cancelled;

  /// No description provided for @result_status_error.
  ///
  /// In ja, this message translates to:
  /// **'取り込み中にエラーが発生しました'**
  String get result_status_error;

  /// No description provided for @result_status_noNewFiles.
  ///
  /// In ja, this message translates to:
  /// **'新しいファイルはありませんでした'**
  String get result_status_noNewFiles;

  /// No description provided for @result_status_completed.
  ///
  /// In ja, this message translates to:
  /// **'取り込みが完了しました'**
  String get result_status_completed;

  /// No description provided for @error_metadataUpdateFailed.
  ///
  /// In ja, this message translates to:
  /// **'メタデータの更新に失敗したため取り込みを中断しました。'**
  String get error_metadataUpdateFailed;

  /// No description provided for @error_importCancelled.
  ///
  /// In ja, this message translates to:
  /// **'取り込みがキャンセルされました。'**
  String get error_importCancelled;

  /// No description provided for @error_nativeApiUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'ファイル日時の取得または復元に必要なネイティブ API が利用できないため取り込みを中断しました。'**
  String get error_nativeApiUnavailable;

  /// No description provided for @error_fileIOFailed.
  ///
  /// In ja, this message translates to:
  /// **'ファイルの読み書きに失敗したため取り込みを中断しました。'**
  String get error_fileIOFailed;

  /// No description provided for @error_fileIOFailedWithName.
  ///
  /// In ja, this message translates to:
  /// **'ファイルの読み書きに失敗したため取り込みを中断しました。ファイル: {fileName}。'**
  String error_fileIOFailedWithName(String fileName);

  /// No description provided for @error_genericImportFailed.
  ///
  /// In ja, this message translates to:
  /// **'取り込み中にエラーが発生したため中断しました。'**
  String get error_genericImportFailed;

  /// No description provided for @error_browserOpenFailed.
  ///
  /// In ja, this message translates to:
  /// **'ブラウザを開けませんでした。'**
  String get error_browserOpenFailed;

  /// No description provided for @error_diskSpaceReadFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存先の空き容量を取得できないため取り込みを中断しました。'**
  String get error_diskSpaceReadFailed;

  /// No description provided for @error_noSpaceLeft.
  ///
  /// In ja, this message translates to:
  /// **'保存先の空き容量が不足しているため取り込みを中断しました。'**
  String get error_noSpaceLeft;

  /// No description provided for @error_noSpaceLeftWithName.
  ///
  /// In ja, this message translates to:
  /// **'保存先の空き容量が不足しているため取り込みを中断しました。ファイル: {fileName}。'**
  String error_noSpaceLeftWithName(String fileName);

  /// No description provided for @error_noSpaceLeftWithSize.
  ///
  /// In ja, this message translates to:
  /// **'保存先の空き容量が不足しているため取り込みを中断しました。必要: {required}、空き: {available}。'**
  String error_noSpaceLeftWithSize(String required, String available);

  /// No description provided for @error_destinationPathFailed.
  ///
  /// In ja, this message translates to:
  /// **'コピー先パスを確定できないため取り込みを中断しました。'**
  String get error_destinationPathFailed;

  /// No description provided for @update_error_checkFailed.
  ///
  /// In ja, this message translates to:
  /// **'アップデートの確認に失敗しました。'**
  String get update_error_checkFailed;

  /// No description provided for @update_error_releaseNotFound.
  ///
  /// In ja, this message translates to:
  /// **'リリースが見つかりませんでした。'**
  String get update_error_releaseNotFound;

  /// No description provided for @update_error_apiFailed.
  ///
  /// In ja, this message translates to:
  /// **'GitHub API エラー ({statusCode})'**
  String update_error_apiFailed(int statusCode);

  /// No description provided for @update_message.
  ///
  /// In ja, this message translates to:
  /// **'新しいバージョン {version} が利用可能です。'**
  String update_message(String version);

  /// No description provided for @update_message_prefix.
  ///
  /// In ja, this message translates to:
  /// **'新しいバージョン '**
  String get update_message_prefix;

  /// No description provided for @update_message_suffix.
  ///
  /// In ja, this message translates to:
  /// **' が利用可能です。'**
  String get update_message_suffix;

  /// No description provided for @update_download.
  ///
  /// In ja, this message translates to:
  /// **' ダウンロード'**
  String get update_download;

  /// No description provided for @enum_SubfolderPattern_DateOnly.
  ///
  /// In ja, this message translates to:
  /// **'日付のみ'**
  String get enum_SubfolderPattern_DateOnly;

  /// No description provided for @enum_SubfolderPattern_YearAndDate.
  ///
  /// In ja, this message translates to:
  /// **'年/日付'**
  String get enum_SubfolderPattern_YearAndDate;

  /// No description provided for @enum_SubfolderPattern_YearMonthAndDate.
  ///
  /// In ja, this message translates to:
  /// **'年/月/日付'**
  String get enum_SubfolderPattern_YearMonthAndDate;

  /// No description provided for @enum_DateFormatStyle_YYYYMMDD.
  ///
  /// In ja, this message translates to:
  /// **'YYYY_MM_DD（4桁年）'**
  String get enum_DateFormatStyle_YYYYMMDD;

  /// No description provided for @enum_DateFormatStyle_YYMMDD.
  ///
  /// In ja, this message translates to:
  /// **'YY_MM_DD（2桁年）'**
  String get enum_DateFormatStyle_YYMMDD;

  /// No description provided for @enum_DateSeparator_None.
  ///
  /// In ja, this message translates to:
  /// **'なし（20251224）'**
  String get enum_DateSeparator_None;

  /// No description provided for @enum_DateSeparator_Underscore.
  ///
  /// In ja, this message translates to:
  /// **'アンダースコア（2025_12_24）'**
  String get enum_DateSeparator_Underscore;

  /// No description provided for @enum_DateSeparator_Hyphen.
  ///
  /// In ja, this message translates to:
  /// **'ハイフン（2025-12-24）'**
  String get enum_DateSeparator_Hyphen;

  /// No description provided for @enum_MediaType_JPEGPhoto.
  ///
  /// In ja, this message translates to:
  /// **'JPEG 写真'**
  String get enum_MediaType_JPEGPhoto;

  /// No description provided for @enum_MediaType_RAWPhoto.
  ///
  /// In ja, this message translates to:
  /// **'RAW 写真'**
  String get enum_MediaType_RAWPhoto;

  /// No description provided for @enum_MediaType_HEIFPhoto.
  ///
  /// In ja, this message translates to:
  /// **'HEIF 写真'**
  String get enum_MediaType_HEIFPhoto;

  /// No description provided for @enum_MediaType_Video.
  ///
  /// In ja, this message translates to:
  /// **'動画'**
  String get enum_MediaType_Video;

  /// No description provided for @enum_MediaType_ProxyVideo.
  ///
  /// In ja, this message translates to:
  /// **'プロキシー動画'**
  String get enum_MediaType_ProxyVideo;

  /// No description provided for @enum_MediaType_VideoMeta.
  ///
  /// In ja, this message translates to:
  /// **'動画メタデータ'**
  String get enum_MediaType_VideoMeta;

  /// No description provided for @enum_MediaType_Unknown.
  ///
  /// In ja, this message translates to:
  /// **'未知のファイル'**
  String get enum_MediaType_Unknown;

  /// No description provided for @enum_ImportWarningType_DuplicateRenamed.
  ///
  /// In ja, this message translates to:
  /// **'別名で保存'**
  String get enum_ImportWarningType_DuplicateRenamed;

  /// No description provided for @enum_ImportWarningType_ExifReadFailed.
  ///
  /// In ja, this message translates to:
  /// **'EXIF 読み取り失敗'**
  String get enum_ImportWarningType_ExifReadFailed;

  /// No description provided for @enum_ImportWarningType_DateRestoreFailed.
  ///
  /// In ja, this message translates to:
  /// **'日時復元失敗'**
  String get enum_ImportWarningType_DateRestoreFailed;

  /// No description provided for @enum_ImportWarningType_HashVerificationFailed.
  ///
  /// In ja, this message translates to:
  /// **'ハッシュ検証失敗'**
  String get enum_ImportWarningType_HashVerificationFailed;

  /// No description provided for @enum_ImportWarningType_MetadataUpdateSkipped.
  ///
  /// In ja, this message translates to:
  /// **'メタデータ更新スキップ'**
  String get enum_ImportWarningType_MetadataUpdateSkipped;

  /// No description provided for @enum_ImportWarningType_UnknownExtensionFound.
  ///
  /// In ja, this message translates to:
  /// **'未知の拡張子'**
  String get enum_ImportWarningType_UnknownExtensionFound;

  /// No description provided for @enum_ImportWarningType_FileInUseSkipped.
  ///
  /// In ja, this message translates to:
  /// **'使用中ファイルをスキップ'**
  String get enum_ImportWarningType_FileInUseSkipped;

  /// No description provided for @enum_ImportPhase_Initializing_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'準備中...'**
  String get enum_ImportPhase_Initializing_dialogTitle;

  /// No description provided for @enum_ImportPhase_ValidatingSDCard_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'SD カードを検証中...'**
  String get enum_ImportPhase_ValidatingSDCard_dialogTitle;

  /// No description provided for @enum_ImportPhase_CheckingWritePermission_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'SD カードを検証中...'**
  String get enum_ImportPhase_CheckingWritePermission_dialogTitle;

  /// No description provided for @enum_ImportPhase_ScanningMediaFiles_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'メディアをスキャン中...'**
  String get enum_ImportPhase_ScanningMediaFiles_dialogTitle;

  /// No description provided for @enum_ImportPhase_DeterminingTargets_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'取り込み対象を判定中...'**
  String get enum_ImportPhase_DeterminingTargets_dialogTitle;

  /// No description provided for @enum_ImportPhase_ParsingExif_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'EXIF を解析中...'**
  String get enum_ImportPhase_ParsingExif_dialogTitle;

  /// No description provided for @enum_ImportPhase_CheckingDestination_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'保存先を確認中...'**
  String get enum_ImportPhase_CheckingDestination_dialogTitle;

  /// No description provided for @enum_ImportPhase_CheckingDiskSpace_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'容量を確認中...'**
  String get enum_ImportPhase_CheckingDiskSpace_dialogTitle;

  /// No description provided for @enum_ImportPhase_Importing_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'取り込み中...'**
  String get enum_ImportPhase_Importing_dialogTitle;

  /// No description provided for @enum_ImportPhase_Initializing_statusText.
  ///
  /// In ja, this message translates to:
  /// **'準備中...'**
  String get enum_ImportPhase_Initializing_statusText;

  /// No description provided for @enum_ImportPhase_ValidatingSDCard_statusText.
  ///
  /// In ja, this message translates to:
  /// **'SD カード構造を検証中...'**
  String get enum_ImportPhase_ValidatingSDCard_statusText;

  /// No description provided for @enum_ImportPhase_CheckingWritePermission_statusText.
  ///
  /// In ja, this message translates to:
  /// **'書き込み可能性を確認中...'**
  String get enum_ImportPhase_CheckingWritePermission_statusText;

  /// No description provided for @enum_ImportPhase_ScanningMediaFiles_statusText.
  ///
  /// In ja, this message translates to:
  /// **'スキャン中...'**
  String get enum_ImportPhase_ScanningMediaFiles_statusText;

  /// No description provided for @enum_ImportPhase_DeterminingTargets_statusText.
  ///
  /// In ja, this message translates to:
  /// **'取り込み対象を判定中...'**
  String get enum_ImportPhase_DeterminingTargets_statusText;

  /// No description provided for @enum_ImportPhase_ParsingExif_statusText.
  ///
  /// In ja, this message translates to:
  /// **'EXIF を解析中...'**
  String get enum_ImportPhase_ParsingExif_statusText;

  /// No description provided for @enum_ImportPhase_CheckingDestination_statusText.
  ///
  /// In ja, this message translates to:
  /// **'保存先を確認中...'**
  String get enum_ImportPhase_CheckingDestination_statusText;

  /// No description provided for @enum_ImportPhase_CheckingDiskSpace_statusText.
  ///
  /// In ja, this message translates to:
  /// **'容量を確認中...'**
  String get enum_ImportPhase_CheckingDiskSpace_statusText;

  /// No description provided for @enum_ImportPhase_Importing_statusText.
  ///
  /// In ja, this message translates to:
  /// **'コピー中...'**
  String get enum_ImportPhase_Importing_statusText;

  /// No description provided for @tz_honolulu.
  ///
  /// In ja, this message translates to:
  /// **'ホノルル'**
  String get tz_honolulu;

  /// No description provided for @tz_anchorage.
  ///
  /// In ja, this message translates to:
  /// **'アンカレッジ'**
  String get tz_anchorage;

  /// No description provided for @tz_losAngeles.
  ///
  /// In ja, this message translates to:
  /// **'ロサンゼルス'**
  String get tz_losAngeles;

  /// No description provided for @tz_denver.
  ///
  /// In ja, this message translates to:
  /// **'デンバー'**
  String get tz_denver;

  /// No description provided for @tz_chicago.
  ///
  /// In ja, this message translates to:
  /// **'シカゴ'**
  String get tz_chicago;

  /// No description provided for @tz_newYork.
  ///
  /// In ja, this message translates to:
  /// **'ニューヨーク'**
  String get tz_newYork;

  /// No description provided for @tz_saoPaulo.
  ///
  /// In ja, this message translates to:
  /// **'サンパウロ'**
  String get tz_saoPaulo;

  /// No description provided for @tz_azores.
  ///
  /// In ja, this message translates to:
  /// **'アゾレス'**
  String get tz_azores;

  /// No description provided for @tz_utc.
  ///
  /// In ja, this message translates to:
  /// **'UTC'**
  String get tz_utc;

  /// No description provided for @tz_london.
  ///
  /// In ja, this message translates to:
  /// **'ロンドン'**
  String get tz_london;

  /// No description provided for @tz_paris.
  ///
  /// In ja, this message translates to:
  /// **'パリ'**
  String get tz_paris;

  /// No description provided for @tz_berlin.
  ///
  /// In ja, this message translates to:
  /// **'ベルリン'**
  String get tz_berlin;

  /// No description provided for @tz_athens.
  ///
  /// In ja, this message translates to:
  /// **'アテネ'**
  String get tz_athens;

  /// No description provided for @tz_moscow.
  ///
  /// In ja, this message translates to:
  /// **'モスクワ'**
  String get tz_moscow;

  /// No description provided for @tz_dubai.
  ///
  /// In ja, this message translates to:
  /// **'ドバイ'**
  String get tz_dubai;

  /// No description provided for @tz_karachi.
  ///
  /// In ja, this message translates to:
  /// **'カラチ'**
  String get tz_karachi;

  /// No description provided for @tz_kolkata.
  ///
  /// In ja, this message translates to:
  /// **'コルカタ'**
  String get tz_kolkata;

  /// No description provided for @tz_dhaka.
  ///
  /// In ja, this message translates to:
  /// **'ダッカ'**
  String get tz_dhaka;

  /// No description provided for @tz_bangkok.
  ///
  /// In ja, this message translates to:
  /// **'バンコク'**
  String get tz_bangkok;

  /// No description provided for @tz_singapore.
  ///
  /// In ja, this message translates to:
  /// **'シンガポール'**
  String get tz_singapore;

  /// No description provided for @tz_hongKong.
  ///
  /// In ja, this message translates to:
  /// **'香港'**
  String get tz_hongKong;

  /// No description provided for @tz_shanghai.
  ///
  /// In ja, this message translates to:
  /// **'上海'**
  String get tz_shanghai;

  /// No description provided for @tz_tokyo.
  ///
  /// In ja, this message translates to:
  /// **'東京'**
  String get tz_tokyo;

  /// No description provided for @tz_seoul.
  ///
  /// In ja, this message translates to:
  /// **'ソウル'**
  String get tz_seoul;

  /// No description provided for @tz_sydney.
  ///
  /// In ja, this message translates to:
  /// **'シドニー'**
  String get tz_sydney;

  /// No description provided for @tz_auckland.
  ///
  /// In ja, this message translates to:
  /// **'オークランド'**
  String get tz_auckland;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
