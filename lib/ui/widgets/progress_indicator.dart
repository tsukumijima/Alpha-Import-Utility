/// プログレスインジケーターウィジェット
///
/// 取り込み進捗を視覚的に表示するカスタムウィジェット。
library;

import 'package:flutter/material.dart';

import '../../models/import_result.dart';
import '../../models/media_file.dart';

/// 取り込み進捗表示ウィジェット
///
/// 全体の進捗とファイル単位の進捗を表示する。
class ImportProgressIndicator extends StatelessWidget {
  /// 進捗情報
  final ImportProgress progress;

  const ImportProgressIndicator({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 全体進捗
        _buildOverallProgress(context, theme),

        // 現在のファイル進捗
        if (progress.currentFile != null) const SizedBox(height: 24),
        if (progress.currentFile != null) _buildCurrentFileProgress(context, theme),
      ],
    );
  }

  /// 全体進捗を構築
  Widget _buildOverallProgress(BuildContext context, ThemeData theme) {
    final isIndeterminate = progress.totalCount == 0;
    final scanPath = progress.scanCurrentPath;
    final leftLabel = isIndeterminate && scanPath != null && scanPath.isNotEmpty ? scanPath : progress.phase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 進捗テキスト
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLabel.isEmpty ? 'インポート中...' : leftLabel,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              progress.progressText,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // プログレスバー
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: isIndeterminate ? null : progress.overallProgress,
            minHeight: 8,
          ),
        ),

        const SizedBox(height: 8),

        // パーセント表示
        Text(
          isIndeterminate ? '---' : '${(progress.overallProgress * 100).toStringAsFixed(1)}%',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  /// 現在のファイル進捗を構築
  Widget _buildCurrentFileProgress(BuildContext context, ThemeData theme) {
    final file = progress.currentFile!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ファイル名
          Text(
            file.fileName,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // ファイルパス
          Text(
            file.relativePath,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // ファイル進捗バー
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.currentFileProgress,
              minHeight: 4,
              backgroundColor: Colors.white12,
            ),
          ),

          const SizedBox(height: 8),

          // サイズ情報
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                file.type.displayName,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
              Text(
                '${_formatBytes(progress.currentFileCopiedBytes)} / ${file.formattedFileSize}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

/// 取り込み結果サマリーウィジェット
class ImportResultSummary extends StatelessWidget {
  /// 取り込み結果
  final ImportResult result;

  const ImportResultSummary({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ステータスアイコン + メッセージ
        Row(
          children: [
            Icon(
              _getStatusIcon(),
              color: _getStatusColor(context),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getStatusMessage(),
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 結果サマリー
        _buildResultRow(context, '成功', result.successCount, Colors.green),
        const SizedBox(height: 8),
        _buildResultRow(context, 'スキップ', result.skippedCount, Colors.white70),
        const SizedBox(height: 8),
        _buildResultRow(context, '警告', result.warningCount, Colors.orange),
        if (result.errorCount > 0) ...[
          const SizedBox(height: 8),
          _buildResultRow(context, 'エラー', result.errorCount, Colors.red),
        ],

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // 処理時間
        Text(
          '処理時間: ${result.formattedDuration}',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildResultRow(BuildContext context, String label, int count, Color color) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        Text(
          '$count 件',
          style: theme.textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  IconData _getStatusIcon() {
    if (result.wasCancelled) {
      return Icons.cancel_outlined;
    } else if (result.errorCount > 0) {
      return Icons.error_outline;
    } else if (result.warningCount > 0) {
      return Icons.warning_outlined;
    } else {
      return Icons.check_circle_outline;
    }
  }

  Color _getStatusColor(BuildContext context) {
    if (result.wasCancelled) {
      return Colors.orange;
    } else if (result.errorCount > 0) {
      return Colors.red;
    } else if (result.warningCount > 0) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getStatusMessage() {
    if (result.wasCancelled) {
      return '取り込みがキャンセルされました';
    } else if (result.errorCount > 0) {
      return '取り込み中にエラーが発生しました';
    } else if (result.successCount == 0) {
      return '新しいファイルはありませんでした';
    } else {
      return '取り込みが完了しました';
    }
  }
}
