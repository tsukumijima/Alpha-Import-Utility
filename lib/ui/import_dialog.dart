/// 取り込みダイアログ
///
/// 取り込み進捗を表示するモーダルダイアログ。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    _engine = ImportEngine(
      sdCardRoot: widget.device.mountPoint,
      settings: widget.settings,
      l10n: l10n,
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
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final errorMessage = _engine?.resolveFatalErrorMessage(ex, l10n) ?? l10n.error_genericImportFailed;
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
    final l10n = AppLocalizations.of(context);

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.import_cancelConfirm_title),
        content: Text(_getCancelMessage(l10n)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.button_continue),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.cancel),
            label: Text(l10n.button_cancel),
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
    final l10n = AppLocalizations.of(context);
    // ImportProgress の importPhase からステータステキストを取得
    final statusText = _getImportPhaseStatusText(l10n, _progress.importPhase);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // デバイス情報
        Text(
          l10n.import_fromDevice(widget.device.displayName, statusText),
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

  /// ImportPhase のローカライズされたステータステキストを取得
  String _getImportPhaseStatusText(AppLocalizations l10n, ImportPhase phase) {
    switch (phase) {
      case ImportPhase.Initializing:
        return l10n.enum_ImportPhase_Initializing_statusText;
      case ImportPhase.ValidatingSDCard:
        return l10n.enum_ImportPhase_ValidatingSDCard_statusText;
      case ImportPhase.CheckingWritePermission:
        return l10n.enum_ImportPhase_CheckingWritePermission_statusText;
      case ImportPhase.ScanningMediaFiles:
        return l10n.enum_ImportPhase_ScanningMediaFiles_statusText;
      case ImportPhase.DeterminingTargets:
        return l10n.enum_ImportPhase_DeterminingTargets_statusText;
      case ImportPhase.ParsingExif:
        return l10n.enum_ImportPhase_ParsingExif_statusText;
      case ImportPhase.CheckingDestination:
        return l10n.enum_ImportPhase_CheckingDestination_statusText;
      case ImportPhase.CheckingDiskSpace:
        return l10n.enum_ImportPhase_CheckingDiskSpace_statusText;
      case ImportPhase.Importing:
        return l10n.enum_ImportPhase_Importing_statusText;
    }
  }

  /// 結果表示を構築
  Widget _buildResult() {
    if (_result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final l10n = AppLocalizations.of(context);

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
              l10n.import_result_abortReason,
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
    final l10n = AppLocalizations.of(context);

    // プレビュー画面
    if (_phase == _ImportDialogPhase.preview) {
      return l10n.import_dialog_preview;
    }
    // 完了画面
    if (_phase == _ImportDialogPhase.completed) {
      if (_result?.wasCancelled == true) {
        return l10n.import_dialog_cancelled;
      }
      if ((_result?.errorCount ?? 0) > 0) {
        return l10n.import_dialog_cancelled;
      }
      return l10n.import_dialog_completed;
    }
    // 準備中または取り込み中: ImportProgress の importPhase に基づいてタイトルを表示
    return _getImportPhaseDialogTitle(l10n, _progress.importPhase);
  }

  /// ImportPhase のローカライズされたダイアログタイトルを取得
  String _getImportPhaseDialogTitle(AppLocalizations l10n, ImportPhase phase) {
    switch (phase) {
      case ImportPhase.Initializing:
        return l10n.enum_ImportPhase_Initializing_dialogTitle;
      case ImportPhase.ValidatingSDCard:
        return l10n.enum_ImportPhase_ValidatingSDCard_dialogTitle;
      case ImportPhase.CheckingWritePermission:
        return l10n.enum_ImportPhase_CheckingWritePermission_dialogTitle;
      case ImportPhase.ScanningMediaFiles:
        return l10n.enum_ImportPhase_ScanningMediaFiles_dialogTitle;
      case ImportPhase.DeterminingTargets:
        return l10n.enum_ImportPhase_DeterminingTargets_dialogTitle;
      case ImportPhase.ParsingExif:
        return l10n.enum_ImportPhase_ParsingExif_dialogTitle;
      case ImportPhase.CheckingDestination:
        return l10n.enum_ImportPhase_CheckingDestination_dialogTitle;
      case ImportPhase.CheckingDiskSpace:
        return l10n.enum_ImportPhase_CheckingDiskSpace_dialogTitle;
      case ImportPhase.Importing:
        return l10n.enum_ImportPhase_Importing_dialogTitle;
    }
  }

  /// キャンセル確認メッセージを取得
  String _getCancelMessage(AppLocalizations l10n) {
    if (_phase == _ImportDialogPhase.preparing) {
      return l10n.import_cancelConfirm_preparing;
    }
    if (_phase == _ImportDialogPhase.preview) {
      return l10n.import_cancelConfirm_preview;
    }
    return l10n.import_cancelConfirm_importing;
  }

  /// プレビュー画面を構築
  Widget _buildPreview() {
    if (_plan == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.import_previewTargetCount(widget.device.displayName, _plan!.items.length),
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
            itemBuilder: (context, index) => _buildPreviewItem(theme, l10n, _plan!.items[index]),
          ),
        ),
      ],
    );
  }

  /// プレビューの各項目を構築
  Widget _buildPreviewItem(ThemeData theme, AppLocalizations l10n, ImportPlanItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.import_previewSource(item.sourcePath),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.import_previewDestination(item.destinationPath),
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
        ),
      ],
    );
  }

  /// 警告一覧を構築
  Widget _buildWarningsList() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ExpansionTile(
      title: Text(
        l10n.import_result_warnings(_result!.warnings.length),
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
    final l10n = AppLocalizations.of(context);
    return [
      TextButton(
        onPressed: _isCancelConfirming ? null : _requestCancel,
        child: Text(l10n.button_cancel),
      ),
    ];
  }

  /// 完了後のアクションボタン
  List<Widget> _buildCompletedActions() {
    final l10n = AppLocalizations.of(context);
    return [
      TextButton(
        onPressed: _openDestinationFolder,
        child: Text(l10n.button_openDestination),
      ),
      ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
        label: Text(l10n.button_close),
      ),
    ];
  }

  /// プレビュー時のアクションボタン
  List<Widget> _buildPreviewActions() {
    final l10n = AppLocalizations.of(context);
    return [
      TextButton(
        onPressed: _isCancelConfirming ? null : _requestCancel,
        child: Text(l10n.button_cancel),
      ),
      ElevatedButton.icon(
        onPressed: () => _startImport(plan: _plan),
        icon: const Icon(Icons.arrow_forward),
        label: Text(l10n.button_continue),
      ),
    ];
  }
}
