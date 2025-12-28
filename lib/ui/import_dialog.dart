/// 取り込みダイアログ
///
/// 取り込み進捗を表示するモーダルダイアログ。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/import_result.dart';
import '../models/settings.dart';
import '../services/device_detector.dart';
import '../services/import_engine.dart';
import 'widgets/progress_indicator.dart';

enum _ImportDialogPhase {
  preparing,
  preview,
  importing,
  completed,
}

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

  /// 取り込みプラン
  ImportPlan? _plan;

  /// 取り込み結果（完了時のみ）
  ImportResult? _result;

  /// ダイアログの状態
  _ImportDialogPhase _phase = _ImportDialogPhase.preparing;

  /// キャンセル確認中フラグ
  bool _isCancelConfirming = false;

  /// 準備フェーズの処理時間
  Duration _prepareDuration = Duration.zero;

  /// 準備フェーズ計測用ストップウォッチ
  final Stopwatch _prepareStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _initializeImportFlow();
  }

  /// 取り込みフローを初期化
  Future<void> _initializeImportFlow() async {
    _engine = ImportEngine(
      sdCardRoot: widget.device.mountPoint,
      settings: widget.settings,
    );

    _engine!.onProgress = (progress) {
      if (mounted) {
        setState(() => _progress = progress);
      }
    };

    if (widget.settings.isShowImportPreview) {
      await _prepareImportPlan();
      return;
    }

    await _startImport();
  }

  /// 取り込みプランを準備
  Future<void> _prepareImportPlan() async {
    setState(() => _phase = _ImportDialogPhase.preparing);
    _prepareStopwatch
      ..reset()
      ..start();

    try {
      final plan = await _engine!.prepareImportPlan();
      _prepareStopwatch.stop();
      _prepareDuration = _prepareStopwatch.elapsed;

      if (!mounted) {
        return;
      }

      if (plan.items.isEmpty) {
        setState(() {
          _result = ImportResult(
            successCount: 0,
            skippedCount: plan.skippedCount,
            warningCount: plan.warnings.length,
            errorCount: 0,
            warnings: plan.warnings,
            importedFiles: [],
            duration: _prepareDuration,
          );
          _phase = _ImportDialogPhase.completed;
        });
        return;
      }

      setState(() {
        _plan = plan;
        _phase = _ImportDialogPhase.preview;
      });
    } on ImportCancelledException {
      _prepareStopwatch.stop();
      return;
    } catch (ex) {
      _prepareStopwatch.stop();
      _prepareDuration = _prepareStopwatch.elapsed;
      final errorMessage = _engine?.resolveFatalErrorMessage(ex) ?? '取り込み中にエラーが発生したため中断しました。';
      if (mounted) {
        setState(() {
          _result = ImportResult.error(
            errorMessage: errorMessage,
            duration: _prepareDuration,
          );
          _phase = _ImportDialogPhase.completed;
        });
      }
    }
  }

  /// 取り込みを開始
  Future<void> _startImport({
    ImportPlan? plan,
  }) async {
    setState(() => _phase = _ImportDialogPhase.importing);

    final result = await _engine!.execute(plan: plan);
    final adjustedResult = plan == null ? result : _withAdjustedDuration(result, _prepareDuration + result.duration);

    if (mounted) {
      setState(() {
        _result = adjustedResult;
        _phase = _ImportDialogPhase.completed;
      });
    }
  }

  /// 処理時間を上書きした結果を返す
  ImportResult _withAdjustedDuration(ImportResult result, Duration duration) {
    return ImportResult(
      successCount: result.successCount,
      skippedCount: result.skippedCount,
      warningCount: result.warningCount,
      errorCount: result.errorCount,
      warnings: result.warnings,
      importedFiles: result.importedFiles,
      duration: duration,
      wasCancelled: result.wasCancelled,
      errorMessage: result.errorMessage,
    );
  }

  /// キャンセルを要求
  Future<void> _requestCancel() async {
    setState(() => _isCancelConfirming = true);

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取り込みをキャンセルしますか？'),
        content: Text(_getCancelMessage()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('続行'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.cancel),
            label: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      if (_phase == _ImportDialogPhase.importing) {
        _engine?.cancel();
      } else if (_phase == _ImportDialogPhase.preparing) {
        _engine?.cancel();
        if (mounted) {
          Navigator.pop(context);
        }
      } else if (_phase == _ImportDialogPhase.preview) {
        if (mounted) {
          Navigator.pop(context);
        }
      }
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
    // ダイアログコンテンツの最大高さをウィンドウ高さの 60% に制限
    // ref: https://www.codestudy.net/blog/how-to-constrain-height-of-alertdialog/
    final screenHeight = MediaQuery.of(context).size.height;
    final maxContentHeight = screenHeight * 0.6;

    return PopScope(
      canPop: _phase == _ImportDialogPhase.completed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _phase != _ImportDialogPhase.completed) {
          _requestCancel();
        }
      },
      child: AlertDialog(
        title: Text(_getDialogTitle()),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: maxContentHeight,
          ),
          child: SizedBox(
            width: 500,
            child: _buildContentByPhase(),
          ),
        ),
        actions: _buildActionsByPhase(),
      ),
    );
  }

  /// フェーズ別の内容を構築
  Widget _buildContentByPhase() {
    if (_phase == _ImportDialogPhase.preview) {
      return _buildPreview();
    }
    if (_phase == _ImportDialogPhase.completed) {
      return _buildResult();
    }
    return _buildProgress();
  }

  /// フェーズ別のアクションを構築
  List<Widget> _buildActionsByPhase() {
    if (_phase == _ImportDialogPhase.preview) {
      return _buildPreviewActions();
    }
    if (_phase == _ImportDialogPhase.completed) {
      return _buildCompletedActions();
    }
    return _buildImportingActions();
  }

  /// 進捗表示を構築
  Widget _buildProgress() {
    // ImportProgress の importPhase からステータステキストを取得
    final statusText = _progress.importPhase.statusText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // デバイス情報
        Text(
          '${widget.device.displayName} から$statusText',
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

    // SingleChildScrollView でラップして、警告リスト展開時のオーバーフローを防ぐ
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 結果サマリー
          ImportResultSummary(result: _result!),

          // エラー理由（あれば）
          if (_result!.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              '中断理由',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _result!.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],

          // 警告一覧（あれば）
          if (_result!.warnings.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildWarningsList(),
          ],
        ],
      ),
    );
  }

  /// ダイアログタイトルを取得
  String _getDialogTitle() {
    // プレビュー画面
    if (_phase == _ImportDialogPhase.preview) {
      return '取り込み前プレビュー';
    }
    // 完了画面
    if (_phase == _ImportDialogPhase.completed) {
      if (_result?.wasCancelled == true) {
        return '取り込み中断';
      }
      if ((_result?.errorCount ?? 0) > 0) {
        return '取り込み中断';
      }
      return '取り込み完了';
    }
    // 準備中または取り込み中: ImportProgress の importPhase に基づいてタイトルを表示
    return _progress.importPhase.dialogTitle;
  }

  /// キャンセル確認メッセージを取得
  String _getCancelMessage() {
    if (_phase == _ImportDialogPhase.preparing) {
      return 'スキャンを中止してダイアログを閉じます。';
    }
    if (_phase == _ImportDialogPhase.preview) {
      return '取り込みを開始せずにプレビューを閉じます。';
    }
    return '現在コピー中のファイルが完了してから停止します。';
  }

  /// プレビュー画面を構築
  Widget _buildPreview() {
    if (_plan == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.device.displayName} の取り込み対象: ${_plan!.items.length} 件',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 16),
        // Flexible を使って親の ConstrainedBox の制約内で残りのスペースを使う
        // shrinkWrap: true は IntrinsicWidth/Height との組み合わせで
        // intrinsic dimensions エラーを起こすため使用しない
        Flexible(
          child: ListView.separated(
            itemCount: _plan!.items.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) => _buildPreviewItem(theme, _plan!.items[index]),
          ),
        ),
      ],
    );
  }

  /// プレビューの各項目を構築
  Widget _buildPreviewItem(ThemeData theme, ImportPlanItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '取り込み元: ${item.sourcePath}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          '取り込み先: ${item.destinationPath}',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
        ),
      ],
    );
  }

  /// 警告一覧を構築
  Widget _buildWarningsList() {
    final theme = Theme.of(context);

    return ExpansionTile(
      title: Text(
        '警告 (${_result!.warnings.length}件)',
        style: theme.textTheme.titleSmall?.copyWith(
          color: Colors.orange,
        ),
      ),
      initiallyExpanded: false,
      // 外側の SingleChildScrollView がスクロールを担当するため、
      // ListView は shrinkWrap + NeverScrollableScrollPhysics で固定サイズ化する
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _result!.warnings.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final warning = _result!.warnings[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.warning_outlined, color: Colors.orange, size: 20),
              title: Text(
                warning.file.fileName,
                style: theme.textTheme.bodySmall,
              ),
              subtitle: Text(
                warning.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
              ),
            );
          },
        ),
      ],
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
      ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
        label: const Text('閉じる'),
      ),
    ];
  }

  /// プレビュー時のアクションボタン
  List<Widget> _buildPreviewActions() {
    return [
      TextButton(
        onPressed: _isCancelConfirming ? null : _requestCancel,
        child: const Text('キャンセル'),
      ),
      ElevatedButton.icon(
        onPressed: () => _startImport(plan: _plan),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('続行'),
      ),
    ];
  }
}
