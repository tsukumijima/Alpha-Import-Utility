/// 取り込みダイアログ
///
/// 取り込み進捗を表示するモーダルダイアログ。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../models/import_result.dart';
import '../services/device_detector.dart';
import '../services/import_engine.dart';
import 'widgets/progress_indicator.dart';

/// 取り込みダイアログウィジェット
class ImportDialog extends StatefulWidget {
  /// 取り込み元デバイス
  final DetectedDevice device;

  /// 取り込み設定
  final ImportSettings settings;

  const ImportDialog({
    super.key,
    required this.device,
    required this.settings,
  });

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  /// 取り込みエンジン
  ImportEngine? _engine;

  /// 現在の進捗
  ImportProgress _progress = ImportProgress.initial();

  /// 取り込み結果（完了時のみ）
  ImportResult? _result;

  /// 取り込み中フラグ
  bool _isImporting = true;

  /// キャンセル確認中フラグ
  bool _isCancelConfirming = false;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  /// 取り込みを開始
  Future<void> _startImport() async {
    _engine = ImportEngine(
      sdCardRoot: widget.device.mountPoint,
      settings: widget.settings,
    );

    _engine!.onProgress = (progress) {
      if (mounted) {
        setState(() => _progress = progress);
      }
    };

    final result = await _engine!.execute();

    if (mounted) {
      setState(() {
        _result = result;
        _isImporting = false;
      });
    }
  }

  /// キャンセルを要求
  Future<void> _requestCancel() async {
    setState(() => _isCancelConfirming = true);

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取り込みをキャンセルしますか？'),
        content: const Text('現在コピー中のファイルが完了してから停止します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('続行'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      _engine?.cancel();
    }

    if (mounted) {
      setState(() => _isCancelConfirming = false);
    }
  }

  /// 保存先フォルダを開く
  Future<void> _openDestinationFolder() async {
    final path = widget.settings.destinationFolder;

    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else {
      // Linux
      await Process.run('xdg-open', [path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isImporting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isImporting) {
          _requestCancel();
        }
      },
      child: AlertDialog(
        title: Text(_isImporting ? '取り込み中...' : '取り込み完了'),
        content: SizedBox(
          width: 500,
          child: _isImporting ? _buildProgress() : _buildResult(),
        ),
        actions: _isImporting ? _buildImportingActions() : _buildCompletedActions(),
      ),
    );
  }

  /// 進捗表示を構築
  Widget _buildProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // デバイス情報
        Text(
          '${widget.device.displayName} から取り込み中',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
        ),
        const SizedBox(height: 24),

        // 進捗インジケーター
        ImportProgressIndicator(progress: _progress),
      ],
    );
  }

  /// 結果表示を構築
  Widget _buildResult() {
    if (_result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 結果サマリー
        ImportResultSummary(result: _result!),

        // 警告一覧（あれば）
        if (_result!.warnings.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildWarningsList(),
        ],
      ],
    );
  }

  /// 警告一覧を構築
  Widget _buildWarningsList() {
    return ExpansionTile(
      title: Text(
        '警告 (${_result!.warnings.length}件)',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.orange,
            ),
      ),
      initiallyExpanded: false,
      children: _result!.warnings.map((warning) {
        return ListTile(
          dense: true,
          leading: const Icon(Icons.warning_outlined, color: Colors.orange, size: 20),
          title: Text(
            warning.file.fileName,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          subtitle: Text(
            warning.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
          ),
        );
      }).toList(),
    );
  }

  /// 取り込み中のアクションボタン
  List<Widget> _buildImportingActions() {
    return [
      TextButton(
        onPressed: _isCancelConfirming ? null : _requestCancel,
        child: const Text('キャンセル'),
      ),
    ];
  }

  /// 完了後のアクションボタン
  List<Widget> _buildCompletedActions() {
    return [
      TextButton(
        onPressed: _openDestinationFolder,
        child: const Text('保存先を開く'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('閉じる'),
      ),
    ];
  }
}
