/// 設定ダイアログ
///
/// アプリケーション設定を編集するモーダルダイアログ。
/// タブで「基本設定」と「取り込みオプション」を切り替えられる。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../services/logging_service.dart';
import '../utils/timezone_utils.dart';

/// サポートするタイムゾーンのリストを参照するためのエイリアス
const _supportedTimezones = supportedTimezones;

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

  /// 保存先フォルダのテキストコントローラー
  late TextEditingController _destinationController;

  /// タブコントローラー
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _destinationController = TextEditingController(text: _settings.destinationFolder);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// 保存先フォルダを選択
  Future<void> _selectDestinationFolder() async {
    final log = LoggingService.instance;
    log.info('Opening destination folder picker.', tag: 'SettingsDialog');

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '保存先フォルダを選択',
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

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ダイアログヘッダー
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Icon(Icons.settings, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('設定', style: theme.textTheme.headlineSmall),
                ],
              ),
            ),

            // タブバー
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '基本設定'),
                Tab(text: '取り込みオプション'),
              ],
            ),

            // タブコンテンツ
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicSettingsTab(theme),
                  _buildOptionsTab(theme),
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _settings.hasDestinationFolder ? () => Navigator.pop(context, _settings) : null,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 基本設定タブを構築
  Widget _buildBasicSettingsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 保存先フォルダ
          _buildSectionTitle(theme, '保存先フォルダ'),
          const SizedBox(height: 6),
          Text(
            '取り込んだ写真・動画を保存するフォルダを指定します。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _buildDestinationFolder(),

          const SizedBox(height: 28),

          // サブフォルダ設定
          _buildSectionTitle(theme, 'サブフォルダ設定'),
          const SizedBox(height: 6),
          Text(
            '撮影日ごとにサブフォルダを作成するパターンを選択します。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _buildSubfolderSettings(),

          const SizedBox(height: 28),

          // 日付フォーマット
          _buildSectionTitle(theme, '日付フォーマット'),
          const SizedBox(height: 6),
          Text(
            'サブフォルダ名に使用する日付の表記形式を指定します。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _buildDateFormatSettings(),

          const SizedBox(height: 24),

          // プレビュー
          _buildPreview(theme),

          const SizedBox(height: 28),

          // 取り込み前プレビュー
          _buildSectionTitle(theme, '取り込み前プレビュー'),
          const SizedBox(height: 6),
          Text(
            'スキャン完了後に取り込み対象の一覧を表示し、続行するか確認します。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: const Text('取り込み前にプレビューを表示'),
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
  Widget _buildOptionsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(theme, 'ファイル日時の復元'),
          const SizedBox(height: 6),
          Text(
            'コピー後のファイルの作成日時・更新日時を、EXIF に記録された撮影日時に合わせます。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: const Text('EXIF から日時を復元'),
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
          _buildSectionTitle(theme, 'カメラタイムゾーン'),
          const SizedBox(height: 6),
          Text(
            'ファイル日時の復元時に利用する、カメラに設定されているタイムゾーンを指定します。\n'
            'EXIF にタイムゾーン情報が含まれている場合は、その値を優先します。\n'
            'EXIF にタイムゾーン情報がない場合のみ、この設定がフォールバックとして利用されます。\n'
            '日本国内で使用している場合は「東京」を選択してください。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _buildTimezoneSettings(),

          const Divider(height: 32),

          _buildSectionTitle(theme, '動画メタデータ'),
          const SizedBox(height: 6),
          Text(
            '動画ファイル (.MP4) に付随する XML メタデータ (例: C0001M01.XML) も取り込みます。\n'
            '動画単体で利活用する分には不要ですが、ソニー純正ソフトとの互換性のため、取り込むことを推奨します。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: const Text('動画メタデータ (XML) を取り込む'),
            value: _settings.isImportVideoXML,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(isImportVideoXML: value);
              });
            },
          ),

          const Divider(height: 32),

          _buildSectionTitle(theme, 'プロキシー動画'),
          const SizedBox(height: 6),
          Text(
            'オリジナルの動画ファイルと同時に生成された、低解像度のプロキシー動画\n'
            '(PRIVATE/M4ROOT/SUB/ フォルダ内) も取り込みます。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: const Text('プロキシー動画を取り込む'),
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

  /// 保存先フォルダ設定を構築
  Widget _buildDestinationFolder() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _destinationController,
            readOnly: true,
            decoration: const InputDecoration(
              hintText: 'フォルダを選択してください',
              prefixIcon: Icon(Icons.folder),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _selectDestinationFolder,
          icon: const Icon(Icons.folder_open),
          tooltip: 'フォルダを選択',
        ),
      ],
    );
  }

  /// サブフォルダ設定を構築
  Widget _buildSubfolderSettings() {
    return DropdownButtonFormField<SubfolderPattern>(
      initialValue: _settings.subfolderPattern,
      decoration: const InputDecoration(
        labelText: 'パターン',
      ),
      items: SubfolderPattern.values.map((pattern) {
        return DropdownMenuItem(
          value: pattern,
          child: Text(pattern.displayName),
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

  /// 日付フォーマット設定を構築
  Widget _buildDateFormatSettings() {
    return Column(
      children: [
        // 日付フォーマット
        DropdownButtonFormField<DateFormatStyle>(
          initialValue: _settings.dateFormat,
          decoration: const InputDecoration(
            labelText: '年の形式',
          ),
          items: DateFormatStyle.values.map((format) {
            return DropdownMenuItem(
              value: format,
              child: Text(format.displayName),
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
          decoration: const InputDecoration(
            labelText: '区切り文字',
          ),
          items: DateSeparator.values.map((separator) {
            return DropdownMenuItem(
              value: separator,
              child: Text(separator.displayName),
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

  /// プレビューを構築
  Widget _buildPreview(ThemeData theme) {
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
            'プレビュー',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            '${_settings.destinationFolder.isNotEmpty ? _settings.destinationFolder : '(保存先未設定)'}/',
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
  Widget _buildTimezoneSettings() {
    // 現在の設定値がリストにあるか確認
    final currentTimezone = _supportedTimezones.firstWhere(
      (tz) => tz.id == _settings.cameraTimezone,
      orElse: () => _supportedTimezones.firstWhere((tz) => tz.id == 'Asia/Tokyo'),
    );

    return DropdownButtonFormField<String>(
      initialValue: currentTimezone.id,
      decoration: const InputDecoration(
        labelText: 'タイムゾーン',
      ),
      items: _supportedTimezones.map((tz) {
        return DropdownMenuItem(
          value: tz.id,
          child: Text('${tz.name} (${tz.offset})'),
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
}
