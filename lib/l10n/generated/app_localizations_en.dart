// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tooltip_refresh => 'Refresh';

  @override
  String get tooltip_settings => 'Settings';

  @override
  String get tooltip_selectFolder => 'Select Folder';

  @override
  String get tooltip_close => 'Close';

  @override
  String get home_scanningDevices => 'Scanning devices...';

  @override
  String get home_sectionCamera_title => 'Import from Camera';

  @override
  String get home_sectionCamera_description =>
      'Import photos and videos directly from a camera connected via USB cable.';

  @override
  String get home_sectionCamera_empty => 'No camera connected';

  @override
  String get home_sectionCamera_emptyHint => 'Connect your camera with a USB cable';

  @override
  String get home_sectionSDCard_title => 'Import from SD Card';

  @override
  String get home_sectionSDCard_description => 'Import photos and videos from an SD card using a card reader.';

  @override
  String get home_sectionSDCard_empty => 'No SD card inserted';

  @override
  String get home_sectionSDCard_emptyHint => 'Insert an SD card into the card reader';

  @override
  String get home_sectionFolder_title => 'Import from Folder';

  @override
  String get home_sectionFolder_description =>
      'Select a folder on your PC to import. Useful for importing from old backups.';

  @override
  String get home_sectionFolder_selectButton => 'Select Folder...';

  @override
  String get home_sectionFolder_selectHint => 'Select a backup folder of a Sony α camera SD card';

  @override
  String get home_filePicker_title => 'Select source folder';

  @override
  String get home_invalidSdCard => 'The selected folder was not recognized as a Sony α camera SD card structure.';

  @override
  String get deviceCard_notRecognized => 'This device was not recognized as a Sony α camera SD card structure.';

  @override
  String get deviceCard_noDevices => 'No devices detected';

  @override
  String get deviceCard_connectHint => 'Connect an SD card or camera';

  @override
  String get deviceCard_manualSelect => 'Select folder manually';

  @override
  String deviceCard_storageDetail(String total, String used, String free) {
    return '$total (Used: $used / Free: $free)';
  }

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_tab_basic => 'Basic';

  @override
  String get settings_tab_options => 'Import Options';

  @override
  String get settings_language_title => 'Language';

  @override
  String get settings_language_description => 'Select the display language for the app.';

  @override
  String get settings_language_label => 'Language';

  @override
  String get settings_language_option_japanese => 'Japanese';

  @override
  String get settings_language_option_english => 'English';

  @override
  String get settings_destinationFolder_title => 'Destination Folder';

  @override
  String get settings_destinationFolder_description =>
      'Specify the folder where imported photos and videos will be saved.';

  @override
  String get settings_destinationFolder_hint => 'Select a folder';

  @override
  String get settings_destinationFolder_picker => 'Select destination folder';

  @override
  String get settings_destinationFolder_notSet => '(Not set)';

  @override
  String get settings_subfolder_title => 'Subfolder Settings';

  @override
  String get settings_subfolder_description => 'Select a pattern for creating subfolders by capture date.';

  @override
  String get settings_subfolder_label => 'Pattern';

  @override
  String get settings_dateFormat_title => 'Date Format';

  @override
  String get settings_dateFormat_description => 'Specify the date format used for subfolder names.';

  @override
  String get settings_dateFormat_yearLabel => 'Year Format';

  @override
  String get settings_dateFormat_separatorLabel => 'Separator';

  @override
  String get settings_preview_title => 'Preview';

  @override
  String get settings_importPreview_title => 'Import Preview';

  @override
  String get settings_importPreview_description =>
      'Show a list of files to import after scanning and confirm before proceeding.';

  @override
  String get settings_importPreview_switch => 'Show preview before import';

  @override
  String get settings_dateRestore_title => 'Restore File Dates';

  @override
  String get settings_dateRestore_description =>
      'Set the creation and modification dates of copied files to match the capture date from EXIF.';

  @override
  String get settings_dateRestore_switch => 'Restore dates from EXIF';

  @override
  String get settings_timezone_title => 'Camera Timezone';

  @override
  String get settings_timezone_description =>
      'Specify the timezone set on your camera, used when restoring file dates.\nIf EXIF contains timezone information, that value takes priority.\nThis setting is only used as a fallback when EXIF lacks timezone info.\nSelect \"Tokyo\" if you use the camera in Japan.';

  @override
  String get settings_timezone_label => 'Timezone';

  @override
  String get settings_videoMeta_title => 'Video Metadata';

  @override
  String get settings_videoMeta_description =>
      'Also import XML metadata files (e.g., C0001M01.XML) associated with video files (.MP4).\nNot required for general video use, but recommended for compatibility with Sony software.';

  @override
  String get settings_videoMeta_switch => 'Import video metadata (XML)';

  @override
  String get settings_proxyVideo_title => 'Proxy Videos';

  @override
  String get settings_proxyVideo_description =>
      'Also import low-resolution proxy videos (in PRIVATE/M4ROOT/SUB/ folder)\ngenerated alongside the original video files.';

  @override
  String get settings_proxyVideo_switch => 'Import proxy videos';

  @override
  String get button_cancel => 'Cancel';

  @override
  String get button_save => 'Save';

  @override
  String get button_close => 'Close';

  @override
  String get button_continue => 'Continue';

  @override
  String get button_openSettings => 'Open Settings';

  @override
  String get button_openDestination => 'Open Destination';

  @override
  String get destinationNotSet_title => 'Destination folder not set';

  @override
  String get destinationNotSet_message => 'Please set a destination folder before starting the import.';

  @override
  String get import_dialog_preview => 'Import Preview';

  @override
  String get import_dialog_completed => 'Import Complete';

  @override
  String get import_dialog_cancelled => 'Import Cancelled';

  @override
  String get import_dialog_error => 'Import Error';

  @override
  String get import_cancelConfirm_title => 'Cancel import?';

  @override
  String get import_cancelConfirm_preparing => 'Stop scanning and close the dialog.';

  @override
  String get import_cancelConfirm_preview => 'Close preview without starting import.';

  @override
  String get import_cancelConfirm_importing => 'Stop after the current file finishes copying.';

  @override
  String import_previewTargetCount(String deviceName, int count) {
    return '$deviceName import targets: $count files';
  }

  @override
  String import_fromDevice(String deviceName, String statusText) {
    return '$statusText from $deviceName';
  }

  @override
  String import_previewSource(String path) {
    return 'Source: $path';
  }

  @override
  String import_previewDestination(String path) {
    return 'Destination: $path';
  }

  @override
  String get import_result_abortReason => 'Abort Reason';

  @override
  String import_result_warnings(int count) {
    return 'Warnings ($count)';
  }

  @override
  String progress_scanningCount(int count) {
    return 'Scanning ($count files)';
  }

  @override
  String get progress_scanning => 'Scanning...';

  @override
  String progress_fileCount(int current, int total) {
    return '$current / $total files';
  }

  @override
  String get progress_phase_scanningMediaFiles => 'Scanning media files...';

  @override
  String get progress_phase_checkingDiskSpace => 'Checking destination disk space...';

  @override
  String get progress_phase_importing => 'Importing...';

  @override
  String get progress_phase_checkingDestinationFolder => 'Checking destination folders...';

  @override
  String get progress_phase_checkingDestinationDuplicate => 'Checking for existing files...';

  @override
  String get progress_phase_parsingExif => ' Parsing EXIF...';

  @override
  String get result_success => 'Success';

  @override
  String get result_skipped => 'Skipped';

  @override
  String get result_warning => 'Warnings';

  @override
  String get result_error => 'Errors';

  @override
  String result_countUnit(int count) {
    return '$count files';
  }

  @override
  String result_duration(String duration) {
    return 'Duration: $duration';
  }

  @override
  String result_durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String result_durationMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String result_durationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get result_status_cancelled => 'Import was cancelled';

  @override
  String get result_status_error => 'An error occurred during import';

  @override
  String get result_status_noNewFiles => 'No new files to import';

  @override
  String get result_status_completed => 'Import completed';

  @override
  String get error_metadataUpdateFailed => 'Import aborted: Failed to update metadata.';

  @override
  String get error_importCancelled => 'Import was cancelled.';

  @override
  String get error_nativeApiUnavailable => 'Import aborted: Native API required for file date handling is unavailable.';

  @override
  String get error_fileIOFailed => 'Import aborted: Failed to read/write file.';

  @override
  String error_fileIOFailedWithName(String fileName) {
    return 'Import aborted: Failed to read/write file: $fileName.';
  }

  @override
  String get error_genericImportFailed => 'Import aborted due to an error.';

  @override
  String get error_browserOpenFailed => 'Failed to open browser.';

  @override
  String get error_diskSpaceReadFailed => 'Import aborted: Failed to read available disk space.';

  @override
  String get error_noSpaceLeft => 'Import aborted: Not enough disk space.';

  @override
  String error_noSpaceLeftWithName(String fileName) {
    return 'Import aborted: Not enough disk space for file: $fileName.';
  }

  @override
  String error_noSpaceLeftWithSize(String required, String available) {
    return 'Import aborted: Not enough disk space. Required: $required, Available: $available.';
  }

  @override
  String get error_destinationPathFailed => 'Import aborted: Failed to resolve destination path.';

  @override
  String get update_error_checkFailed => 'Failed to check for updates.';

  @override
  String get update_error_releaseNotFound => 'No releases found.';

  @override
  String update_error_apiFailed(int statusCode) {
    return 'GitHub API error ($statusCode)';
  }

  @override
  String update_message(String version) {
    return 'New version $version is available.';
  }

  @override
  String get update_message_prefix => 'New version ';

  @override
  String get update_message_suffix => ' is available.';

  @override
  String get update_download => ' Download';

  @override
  String get enum_SubfolderPattern_DateOnly => 'Date only';

  @override
  String get enum_SubfolderPattern_YearAndDate => 'Year/Date';

  @override
  String get enum_SubfolderPattern_YearMonthAndDate => 'Year/Month/Date';

  @override
  String get enum_DateFormatStyle_YYYYMMDD => 'YYYY_MM_DD (4-digit year)';

  @override
  String get enum_DateFormatStyle_YYMMDD => 'YY_MM_DD (2-digit year)';

  @override
  String get enum_DateSeparator_None => 'None (20251224)';

  @override
  String get enum_DateSeparator_Underscore => 'Underscore (2025_12_24)';

  @override
  String get enum_DateSeparator_Hyphen => 'Hyphen (2025-12-24)';

  @override
  String get enum_MediaType_JPEGPhoto => 'JPEG Photo';

  @override
  String get enum_MediaType_RAWPhoto => 'RAW Photo';

  @override
  String get enum_MediaType_HEIFPhoto => 'HEIF Photo';

  @override
  String get enum_MediaType_Video => 'Video';

  @override
  String get enum_MediaType_ProxyVideo => 'Proxy Video';

  @override
  String get enum_MediaType_VideoMeta => 'Video Metadata';

  @override
  String get enum_MediaType_Unknown => 'Unknown File';

  @override
  String get enum_ImportWarningType_DuplicateRenamed => 'Saved with different name';

  @override
  String get enum_ImportWarningType_ExifReadFailed => 'EXIF read failed';

  @override
  String get enum_ImportWarningType_DateRestoreFailed => 'Date restore failed';

  @override
  String get enum_ImportWarningType_HashVerificationFailed => 'Hash verification failed';

  @override
  String get enum_ImportWarningType_MetadataUpdateSkipped => 'Metadata update skipped';

  @override
  String get enum_ImportWarningType_UnknownExtensionFound => 'Unknown extension';

  @override
  String get enum_ImportWarningType_FileInUseSkipped => 'File in use skipped';

  @override
  String get enum_ImportPhase_Initializing_dialogTitle => 'Preparing...';

  @override
  String get enum_ImportPhase_ValidatingSDCard_dialogTitle => 'Validating SD card...';

  @override
  String get enum_ImportPhase_CheckingWritePermission_dialogTitle => 'Validating SD card...';

  @override
  String get enum_ImportPhase_ScanningMediaFiles_dialogTitle => 'Scanning media...';

  @override
  String get enum_ImportPhase_DeterminingTargets_dialogTitle => 'Determining targets...';

  @override
  String get enum_ImportPhase_ParsingExif_dialogTitle => 'Parsing EXIF...';

  @override
  String get enum_ImportPhase_CheckingDestination_dialogTitle => 'Checking destination...';

  @override
  String get enum_ImportPhase_CheckingDiskSpace_dialogTitle => 'Checking disk space...';

  @override
  String get enum_ImportPhase_Importing_dialogTitle => 'Importing...';

  @override
  String get enum_ImportPhase_Initializing_statusText => 'Preparing...';

  @override
  String get enum_ImportPhase_ValidatingSDCard_statusText => 'Validating SD card structure...';

  @override
  String get enum_ImportPhase_CheckingWritePermission_statusText => 'Checking write permission...';

  @override
  String get enum_ImportPhase_ScanningMediaFiles_statusText => 'Scanning...';

  @override
  String get enum_ImportPhase_DeterminingTargets_statusText => 'Determining import targets...';

  @override
  String get enum_ImportPhase_ParsingExif_statusText => 'Parsing EXIF...';

  @override
  String get enum_ImportPhase_CheckingDestination_statusText => 'Checking destination...';

  @override
  String get enum_ImportPhase_CheckingDiskSpace_statusText => 'Checking disk space...';

  @override
  String get enum_ImportPhase_Importing_statusText => 'Copying...';

  @override
  String get tz_honolulu => 'Honolulu';

  @override
  String get tz_anchorage => 'Anchorage';

  @override
  String get tz_losAngeles => 'Los Angeles';

  @override
  String get tz_denver => 'Denver';

  @override
  String get tz_chicago => 'Chicago';

  @override
  String get tz_newYork => 'New York';

  @override
  String get tz_saoPaulo => 'São Paulo';

  @override
  String get tz_azores => 'Azores';

  @override
  String get tz_utc => 'UTC';

  @override
  String get tz_london => 'London';

  @override
  String get tz_paris => 'Paris';

  @override
  String get tz_berlin => 'Berlin';

  @override
  String get tz_athens => 'Athens';

  @override
  String get tz_moscow => 'Moscow';

  @override
  String get tz_dubai => 'Dubai';

  @override
  String get tz_karachi => 'Karachi';

  @override
  String get tz_kolkata => 'Kolkata';

  @override
  String get tz_dhaka => 'Dhaka';

  @override
  String get tz_bangkok => 'Bangkok';

  @override
  String get tz_singapore => 'Singapore';

  @override
  String get tz_hongKong => 'Hong Kong';

  @override
  String get tz_shanghai => 'Shanghai';

  @override
  String get tz_tokyo => 'Tokyo';

  @override
  String get tz_seoul => 'Seoul';

  @override
  String get tz_sydney => 'Sydney';

  @override
  String get tz_auckland => 'Auckland';
}
