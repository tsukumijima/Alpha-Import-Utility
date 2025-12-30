/// 設定ダイアログ
///
/// アプリケーション設定を編集するモーダルダイアログ。
/// タブで「基本設定」と「取り込みオプション」を切り替えられる。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/settings.dart';
import '../services/logging_service.dart';
import '../utils/timezone_utils.dart';

/// サポートするタイムゾーンのリストを参照するためのエイリアス
const _supportedTimezones = supportedTimezones;

/// タイムゾーン ID からローカライズされた表示名を取得するためのマップ
///
/// 各エントリは タイムゾーン ID をキーとし、AppLocalizations から
/// ローカライズされた名前を返す関数を値として持つ。
final _timezoneNameGetters = <String, String Function(AppLocalizations)>{
  'Pacific/Honolulu': (l10n) => l10n.tz_honolulu,
  'America/Anchorage': (l10n) => l10n.tz_anchorage,
  'America/Los_Angeles': (l10n) => l10n.tz_losAngeles,
  'America/Denver': (l10n) => l10n.tz_denver,
  'America/Chicago': (l10n) => l10n.tz_chicago,
  'America/New_York': (l10n) => l10n.tz_newYork,
  'America/Sao_Paulo': (l10n) => l10n.tz_saoPaulo,
  'Atlantic/Azores': (l10n) => l10n.tz_azores,
  'UTC': (l10n) => l10n.tz_utc,
  'Europe/London': (l10n) => l10n.tz_london,
  'Europe/Paris': (l10n) => l10n.tz_paris,
  'Europe/Berlin': (l10n) => l10n.tz_berlin,
  'Europe/Athens': (l10n) => l10n.tz_athens,
  'Europe/Moscow': (l10n) => l10n.tz_moscow,
  'Asia/Dubai': (l10n) => l10n.tz_dubai,
  'Asia/Karachi': (l10n) => l10n.tz_karachi,
  'Asia/Kolkata': (l10n) => l10n.tz_kolkata,
  'Asia/Dhaka': (l10n) => l10n.tz_dhaka,
  'Asia/Bangkok': (l10n) => l10n.tz_bangkok,
  'Asia/Singapore': (l10n) => l10n.tz_singapore,
  'Asia/Hong_Kong': (l10n) => l10n.tz_hongKong,
  'Asia/Shanghai': (l10n) => l10n.tz_shanghai,
  'Asia/Tokyo': (l10n) => l10n.tz_tokyo,
  'Asia/Seoul': (l10n) => l10n.tz_seoul,
  'Australia/Sydney': (l10n) => l10n.tz_sydney,
  'Pacific/Auckland': (l10n) => l10n.tz_auckland,
};

/// 設定ダイアログウィジェット
class SettingsDialog extends StatefulWidget {
  /// 現在の設定
  final ImportSettings settings;

  const SettingsDialog({super.key, required this.settings});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  /// 編集中の設定
  late ImportSettings _settings;

  /// ダイアログ表示時の元の設定（変更検出・キャンセル時の復元用）
  late ImportSettings _originalSettings;

  /// 保存先フォルダのテキストコントローラー
  late TextEditingController _destinationController;

  /// タブコントローラー
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _originalSettings = widget.settings;
    _destinationController = TextEditingController(text: _settings.destinationFolder);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// 設定が変更されたかどうかを判定
  bool get _hasChanges {
    return _settings.language != _originalSettings.language ||
        _settings.destinationFolder != _originalSettings.destinationFolder ||
        _settings.subfolderPattern != _originalSettings.subfolderPattern ||
        _settings.dateFormat != _originalSettings.dateFormat ||
        _settings.dateSeparator != _originalSettings.dateSeparator ||
        _settings.isShowImportPreview != _originalSettings.isShowImportPreview ||
        _settings.isRestoreDateTimeFromExif != _originalSettings.isRestoreDateTimeFromExif ||
        _settings.cameraTimezone != _originalSettings.cameraTimezone ||
        _settings.isImportVideoXML != _originalSettings.isImportVideoXML ||
        _settings.isImportProxyVideos != _originalSettings.isImportProxyVideos;
  }

  /// キャンセル時の処理
  ///
  /// 言語が変更されていた場合は元の言語に戻す。
  void _handleCancel() {
    _restoreLanguageIfNeeded();
    Navigator.pop(context);
  }

  /// 言語が変更されていた場合は元の言語に戻す
  void _restoreLanguageIfNeeded() {
    if (_settings.language != _originalSettings.language) {
      AlphaImportUtilityApp.updateLocale(_originalSettings.language.locale);
    }
  }

  /// 保存先フォルダを選択
  Future<void> _selectDestinationFolder(AppLocalizations l10n) async {
    final log = LoggingService.instance;
    log.info('Opening destination folder picker.', tag: 'SettingsDialog');

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.settings_destinationFolder_picker,
        initialDirectory: _settings.destinationFolder.isNotEmpty ? _settings.destinationFolder : null,
      );

      if (result != null) {
        log.info('Destination folder selected: $result.', tag: 'SettingsDialog');
        log.logSettingsChanged('destinationFolder', result);
        setState(() {
          _settings = _settings.copyWith(destinationFolder: result);
          _destinationController.text = result;
        });
      } else {
        log.debug('Destination folder picker cancelled.', tag: 'SettingsDialog');
      }
    } catch (ex, stackTrace) {
      log.error('Destination folder picker failed.', tag: 'SettingsDialog', error: ex, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _restoreLanguageIfNeeded();
        }
      },
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ダイアログヘッダー
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                child: Row(
                  children: [
                    Icon(Icons.settings, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(l10n.settings_title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // タブバー
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l10n.settings_tab_basic),
                  Tab(text: l10n.settings_tab_options),
                ],
              ),

              // タブコンテンツ
              Flexible(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicSettingsTab(theme, l10n),
                    _buildOptionsTab(theme, l10n),
                  ],
                ),
              ),

              // アクションボタン
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _handleCancel,
                      child: Text(l10n.button_cancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      // 保存先が設定済みかつ変更がある場合のみ有効
                      onPressed: _settings.hasDestinationFolder && _hasChanges
                          ? () => Navigator.pop(context, _settings)
                          : null,
                      icon: const Icon(Icons.save),
                      label: Text(l10n.button_save),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 基本設定タブを構築
  Widget _buildBasicSettingsTab(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 言語設定（最上部に配置）
          _buildSectionTitle(theme, l10n.settings_language_title),
          const SizedBox(height: 6),
          Text(
            l10n.settings_language_description,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _buildLanguageSettings(l10n),

          const SizedBox(height: 28),

          // 保存先フォルダ
          _buildSectionTitle(theme, l10n.settings_destinationFolder_title),
          const SizedBox(height: 6),
          Text(
            l10n.settings_destinationFolder_description,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _buildDestinationFolder(l10n),

          const SizedBox(height: 28),

          // サブフォルダ設定
          _buildSectionTitle(theme, l10n.settings_subfolder_title),
          const SizedBox(height: 6),
          Text(
            l10n.settings_subfolder_description,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _buildSubfolderSettings(l10n),

          const SizedBox(height: 28),

          // 日付フォーマット
          _buildSectionTitle(theme, l10n.settings_dateFormat_title),
          const SizedBox(height: 6),
          Text(
            l10n.settings_dateFormat_description,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _buildDateFormatSettings(l10n),

          const SizedBox(height: 24),

          // プレビュー
          _buildPreview(theme, l10n),

          const SizedBox(height: 28),

          // 取り込み前プレビュー
          _buildSectionTitle(theme, l10n.settings_importPreview_title),
          const SizedBox(height: 6),
          Text(
            l10n.settings_importPreview_description,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: Text(l10n.settings_importPreview_switch),
            value: _settings.isShowImportPreview,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(isShowImportPreview: value);
              });
            },
          ),
        ],
      ),
    );
  }

  /// オプションタブを構築
  Widget _buildOptionsTab(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(theme, l10n.settings_dateRestore_title),
          const SizedBox(height: 6),
          Text(
            l10n.settings_dateRestore_description,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: Text(l10n.settings_dateRestore_switch),
            value: _settings.isRestoreDateTimeFromExif,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(isRestoreDateTimeFromExif: value);
              });
            },
          ),

          const Divider(height: 32),

          // カメラタイムゾーン
          _buildSectionTitle(theme, l10n.settings_timezone_title),
          const SizedBox(height: 6),
          Text(
            l10n.settings_timezone_description,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _buildTimezoneSettings(l10n),

          const Divider(height: 32),

          _buildSectionTitle(theme, l10n.settings_videoMeta_title),
          const SizedBox(height: 6),
          Text(
            l10n.settings_videoMeta_description,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: Text(l10n.settings_videoMeta_switch),
            value: _settings.isImportVideoXML,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(isImportVideoXML: value);
              });
            },
          ),

          const Divider(height: 32),

          _buildSectionTitle(theme, l10n.settings_proxyVideo_title),
          const SizedBox(height: 6),
          Text(
            l10n.settings_proxyVideo_description,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: Text(l10n.settings_proxyVideo_switch),
            value: _settings.isImportProxyVideos,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(isImportProxyVideos: value);
              });
            },
          ),
        ],
      ),
    );
  }

  /// セクションタイトルを構築
  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// 言語設定を構築
  Widget _buildLanguageSettings(AppLocalizations l10n) {
    return DropdownButtonFormField<AppLanguage>(
      initialValue: _settings.language,
      decoration: InputDecoration(
        labelText: l10n.settings_language_label,
      ),
      items: AppLanguage.values.map((lang) {
        return DropdownMenuItem(
          value: lang,
          child: Text(_getLanguageName(l10n, lang)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _settings = _settings.copyWith(language: value);
          });
          // 即座にロケールを変更
          AlphaImportUtilityApp.updateLocale(value.locale);
        }
      },
    );
  }

  /// 言語の表示名をローカライズして取得
  String _getLanguageName(AppLocalizations l10n, AppLanguage language) {
    switch (language) {
      case AppLanguage.Japanese:
        return l10n.settings_language_option_japanese;
      case AppLanguage.English:
        return l10n.settings_language_option_english;
    }
  }

  /// 保存先フォルダ設定を構築
  Widget _buildDestinationFolder(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _destinationController,
            readOnly: true,
            decoration: InputDecoration(
              hintText: l10n.settings_destinationFolder_hint,
              prefixIcon: Icon(Icons.folder),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _selectDestinationFolder(l10n),
          icon: const Icon(Icons.folder_open),
          tooltip: l10n.tooltip_selectFolder,
        ),
      ],
    );
  }

  /// サブフォルダ設定を構築
  Widget _buildSubfolderSettings(AppLocalizations l10n) {
    return DropdownButtonFormField<SubfolderPattern>(
      initialValue: _settings.subfolderPattern,
      decoration: InputDecoration(
        labelText: l10n.settings_subfolder_label,
      ),
      items: SubfolderPattern.values.map((pattern) {
        return DropdownMenuItem(
          value: pattern,
          child: Text(_getSubfolderPatternName(l10n, pattern)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _settings = _settings.copyWith(subfolderPattern: value);
          });
        }
      },
    );
  }

  /// SubfolderPattern のローカライズされた表示名を取得
  String _getSubfolderPatternName(AppLocalizations l10n, SubfolderPattern pattern) {
    switch (pattern) {
      case SubfolderPattern.DateOnly:
        return l10n.enum_SubfolderPattern_DateOnly;
      case SubfolderPattern.YearAndDate:
        return l10n.enum_SubfolderPattern_YearAndDate;
      case SubfolderPattern.YearMonthAndDate:
        return l10n.enum_SubfolderPattern_YearMonthAndDate;
    }
  }

  /// 日付フォーマット設定を構築
  Widget _buildDateFormatSettings(AppLocalizations l10n) {
    return Column(
      children: [
        // 日付フォーマット
        DropdownButtonFormField<DateFormatStyle>(
          initialValue: _settings.dateFormat,
          decoration: InputDecoration(
            labelText: l10n.settings_dateFormat_yearLabel,
          ),
          items: DateFormatStyle.values.map((format) {
            return DropdownMenuItem(
              value: format,
              child: Text(_getDateFormatStyleName(l10n, format)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _settings = _settings.copyWith(dateFormat: value);
              });
            }
          },
        ),

        const SizedBox(height: 12),

        // 区切り文字
        DropdownButtonFormField<DateSeparator>(
          initialValue: _settings.dateSeparator,
          decoration: InputDecoration(
            labelText: l10n.settings_dateFormat_separatorLabel,
          ),
          items: DateSeparator.values.map((separator) {
            return DropdownMenuItem(
              value: separator,
              child: Text(_getDateSeparatorName(l10n, separator)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _settings = _settings.copyWith(dateSeparator: value);
              });
            }
          },
        ),
      ],
    );
  }

  /// DateFormatStyle のローカライズされた表示名を取得
  String _getDateFormatStyleName(AppLocalizations l10n, DateFormatStyle format) {
    switch (format) {
      case DateFormatStyle.YYYYMMDD:
        return l10n.enum_DateFormatStyle_YYYYMMDD;
      case DateFormatStyle.YYMMDD:
        return l10n.enum_DateFormatStyle_YYMMDD;
    }
  }

  /// DateSeparator のローカライズされた表示名を取得
  String _getDateSeparatorName(AppLocalizations l10n, DateSeparator separator) {
    switch (separator) {
      case DateSeparator.None:
        return l10n.enum_DateSeparator_None;
      case DateSeparator.Underscore:
        return l10n.enum_DateSeparator_Underscore;
      case DateSeparator.Hyphen:
        return l10n.enum_DateSeparator_Hyphen;
    }
  }

  /// プレビューを構築
  Widget _buildPreview(ThemeData theme, AppLocalizations l10n) {
    final examplePath = _settings.subfolderPattern.getExample(
      _settings.dateFormat,
      _settings.dateSeparator,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settings_preview_title,
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            '${_settings.destinationFolder.isNotEmpty ? _settings.destinationFolder : l10n.settings_destinationFolder_notSet}/',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          Text(
            '  └─ $examplePath/',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
          ),
          Text(
            '      └─ DSC00001.JPG',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  /// タイムゾーン設定を構築
  Widget _buildTimezoneSettings(AppLocalizations l10n) {
    // 現在の設定値がリストにあるか確認
    final currentTimezone = _supportedTimezones.firstWhere(
      (tz) => tz.id == _settings.cameraTimezone,
      orElse: () => _supportedTimezones.firstWhere((tz) => tz.id == 'Asia/Tokyo'),
    );

    return DropdownButtonFormField<String>(
      initialValue: currentTimezone.id,
      decoration: InputDecoration(
        labelText: l10n.settings_timezone_label,
      ),
      items: _supportedTimezones.map((tz) {
        return DropdownMenuItem(
          value: tz.id,
          child: Text('${_getTimezoneName(l10n, tz.id)} (${tz.offset})'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _settings = _settings.copyWith(cameraTimezone: value);
          });
        }
      },
    );
  }

  /// タイムゾーン ID からローカライズされた表示名を取得
  ///
  /// [timezoneId] が [_timezoneNameGetters] に存在する場合はローカライズされた
  /// 名前を返し、存在しない場合はタイムゾーン ID をそのまま返す。
  String _getTimezoneName(AppLocalizations l10n, String timezoneId) {
    final getter = _timezoneNameGetters[timezoneId];
    return getter != null ? getter(l10n) : timezoneId;
  }
}
