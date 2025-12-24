/// 設定ダイアログ
///
/// アプリケーション設定を編集するモーダルダイアログ。
library;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/settings.dart';
import '../services/logging_service.dart';

/// サポートするタイムゾーンのリスト
///
/// IANA 形式のタイムゾーン名と UTC オフセット、表示名のペア。
/// 主要なタイムゾーンのみを含む。
const List<({String id, String offset, String name})> _supportedTimezones = [
  (id: 'Pacific/Honolulu', offset: 'UTC-10:00', name: 'ホノルル'),
  (id: 'America/Anchorage', offset: 'UTC-09:00', name: 'アンカレッジ'),
  (id: 'America/Los_Angeles', offset: 'UTC-08:00', name: 'ロサンゼルス'),
  (id: 'America/Denver', offset: 'UTC-07:00', name: 'デンバー'),
  (id: 'America/Chicago', offset: 'UTC-06:00', name: 'シカゴ'),
  (id: 'America/New_York', offset: 'UTC-05:00', name: 'ニューヨーク'),
  (id: 'America/Sao_Paulo', offset: 'UTC-03:00', name: 'サンパウロ'),
  (id: 'Atlantic/Azores', offset: 'UTC-01:00', name: 'アゾレス'),
  (id: 'UTC', offset: 'UTC+00:00', name: 'UTC'),
  (id: 'Europe/London', offset: 'UTC+00:00', name: 'ロンドン'),
  (id: 'Europe/Paris', offset: 'UTC+01:00', name: 'パリ'),
  (id: 'Europe/Berlin', offset: 'UTC+01:00', name: 'ベルリン'),
  (id: 'Europe/Athens', offset: 'UTC+02:00', name: 'アテネ'),
  (id: 'Europe/Moscow', offset: 'UTC+03:00', name: 'モスクワ'),
  (id: 'Asia/Dubai', offset: 'UTC+04:00', name: 'ドバイ'),
  (id: 'Asia/Karachi', offset: 'UTC+05:00', name: 'カラチ'),
  (id: 'Asia/Kolkata', offset: 'UTC+05:30', name: 'コルカタ'),
  (id: 'Asia/Dhaka', offset: 'UTC+06:00', name: 'ダッカ'),
  (id: 'Asia/Bangkok', offset: 'UTC+07:00', name: 'バンコク'),
  (id: 'Asia/Singapore', offset: 'UTC+08:00', name: 'シンガポール'),
  (id: 'Asia/Hong_Kong', offset: 'UTC+08:00', name: '香港'),
  (id: 'Asia/Shanghai', offset: 'UTC+08:00', name: '上海'),
  (id: 'Asia/Tokyo', offset: 'UTC+09:00', name: '東京'),
  (id: 'Asia/Seoul', offset: 'UTC+09:00', name: 'ソウル'),
  (id: 'Australia/Sydney', offset: 'UTC+10:00', name: 'シドニー'),
  (id: 'Pacific/Auckland', offset: 'UTC+12:00', name: 'オークランド'),
];

/// 設定ダイアログウィジェット
class SettingsDialog extends StatefulWidget {
  /// 現在の設定
  final ImportSettings settings;

  const SettingsDialog({super.key, required this.settings});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  /// 編集中の設定
  late ImportSettings _settings;

  /// 保存先フォルダのテキストコントローラー
  late TextEditingController _destinationController;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _destinationController = TextEditingController(text: _settings.destinationFolder);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  /// 保存先フォルダを選択
  Future<void> _selectDestinationFolder() async {
    final log = LoggingService.instance;
    log.info('Opening destination folder picker.', tag: 'SettingsDialog');

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '保存先フォルダを選択',
        initialDirectory: _settings.destinationFolder.isNotEmpty
            ? _settings.destinationFolder
            : null,
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

    return AlertDialog(
      title: const Text('設定'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 保存先フォルダ
              _buildSectionTitle(theme, '保存先フォルダ'),
              const SizedBox(height: 8),
              _buildDestinationFolder(),

              const SizedBox(height: 24),

              // サブフォルダ設定
              _buildSectionTitle(theme, 'サブフォルダ設定'),
              const SizedBox(height: 8),
              _buildSubfolderSettings(),

              const SizedBox(height: 24),

              // 日付フォーマット
              _buildSectionTitle(theme, '日付フォーマット'),
              const SizedBox(height: 8),
              _buildDateFormatSettings(),

              const SizedBox(height: 24),

              // カメラタイムゾーン
              _buildSectionTitle(theme, 'カメラタイムゾーン'),
              const SizedBox(height: 8),
              _buildTimezoneSettings(),

              const SizedBox(height: 16),

              // プレビュー（オプションの上に配置）
              _buildPreview(theme),

              const SizedBox(height: 24),

              // オプション
              _buildSectionTitle(theme, 'オプション'),
              const SizedBox(height: 8),
              _buildOptionSettings(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _settings.hasDestinationFolder
              ? () => Navigator.pop(context, _settings)
              : null,
          child: const Text('保存'),
        ),
      ],
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
        helperText: 'カメラの内部時刻が設定されているタイムゾーン',
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

  /// オプション設定を構築
  Widget _buildOptionSettings() {
    return Column(
      children: [
        // EXIF から日時復元
        SwitchListTile(
          title: const Text('EXIF から日時を復元'),
          subtitle: const Text('コピー後のファイル日時を撮影日時に合わせます'),
          value: _settings.isRestoreDateTimeFromExif,
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(isRestoreDateTimeFromExif: value);
            });
          },
        ),

        // 動画 XML 取り込み
        SwitchListTile(
          title: const Text('動画メタデータ (XML) を取り込む'),
          subtitle: const Text('通常は不要です'),
          value: _settings.isImportVideoXML,
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(isImportVideoXML: value);
            });
          },
        ),

        // プロキシ動画取り込み
        SwitchListTile(
          title: const Text('プロキシ動画を取り込む'),
          subtitle: const Text('編集用の低解像度動画'),
          value: _settings.isImportProxyVideos,
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(isImportProxyVideos: value);
            });
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
            '      └─ DSC00001.ARW',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
