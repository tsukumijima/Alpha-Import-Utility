/// プログレスインジケーターウィジェット
///
/// 取り込み進捗を視覚的に表示するカスタムウィジェット。
library;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 全体進捗
        _buildOverallProgress(context, theme, l10n),

        // 現在のファイル進捗
        if (progress.currentFile != null) const SizedBox(height: 24),
        if (progress.currentFile != null) _buildCurrentFileProgress(context, theme, l10n),
      ],
    );
  }

  /// 全体進捗を構築
  Widget _buildOverallProgress(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final isIndeterminate = progress.totalCount == 0;

    // 左側のラベル:
    // 1. スキャン中パスがあればそれを表示
    // 2. phase が設定されていればそれを表示
    // 3. どちらもなければ importPhase からローカライズテキストを取得
    final scanPath = progress.scanCurrentPath;
    final phase = progress.phase;
    String leftLabel;
    if (scanPath != null && scanPath.isNotEmpty) {
      leftLabel = scanPath;
    } else if (phase != null && phase.isNotEmpty) {
      leftLabel = phase;
    } else {
      leftLabel = _getImportPhaseStatusText(l10n, progress.importPhase);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 進捗テキスト
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                leftLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _getProgressText(l10n),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 15,
                fontWeight: FontWeight.normal,
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

  /// 進捗テキストを取得
  String _getProgressText(AppLocalizations l10n) {
    if (progress.totalCount == 0) {
      // totalCount が 0 の場合はスキャン中
      return progress.processedCount > 0
          ? l10n.progress_scanningCount(progress.processedCount)
          : l10n.progress_scanning;
    }
    return l10n.progress_fileCount(progress.processedCount, progress.totalCount);
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

  /// 現在のファイル進捗を構築
  Widget _buildCurrentFileProgress(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final file = progress.currentFile!;
    final destinationPath = progress.currentDestinationPath;

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
            'From: ${file.relativePath}',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (destinationPath != null && destinationPath.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'To: $destinationPath',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

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
                _getMediaTypeName(l10n, file.type),
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

  /// MediaType のローカライズされた表示名を取得
  String _getMediaTypeName(AppLocalizations l10n, MediaType type) {
    switch (type) {
      case MediaType.JPEGPhoto:
        return l10n.enum_MediaType_JPEGPhoto;
      case MediaType.RAWPhoto:
        return l10n.enum_MediaType_RAWPhoto;
      case MediaType.HEIFPhoto:
        return l10n.enum_MediaType_HEIFPhoto;
      case MediaType.Video:
        return l10n.enum_MediaType_Video;
      case MediaType.ProxyVideo:
        return l10n.enum_MediaType_ProxyVideo;
      case MediaType.VideoMeta:
        return l10n.enum_MediaType_VideoMeta;
      case MediaType.Unknown:
        return l10n.enum_MediaType_Unknown;
    }
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
    final l10n = AppLocalizations.of(context);

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
                _getStatusMessage(l10n),
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 結果サマリー
        _buildResultRow(context, l10n, l10n.result_success, result.successCount, Colors.green),
        const SizedBox(height: 8),
        _buildResultRow(context, l10n, l10n.result_skipped, result.skippedCount, Colors.white70),
        const SizedBox(height: 8),
        _buildResultRow(context, l10n, l10n.result_warning, result.warningCount, Colors.orange),
        if (result.errorCount > 0) ...[
          const SizedBox(height: 8),
          _buildResultRow(context, l10n, l10n.result_error, result.errorCount, Colors.red),
        ],

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // 処理時間
        Text(
          l10n.result_duration(_formatDuration(l10n, result.duration)),
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildResultRow(
    BuildContext context,
    AppLocalizations l10n,
    String label,
    int count,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        Text(
          l10n.result_countUnit(count),
          style: theme.textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// 処理時間をローカライズされた形式でフォーマット
  String _formatDuration(AppLocalizations l10n, Duration duration) {
    if (duration.inHours > 0) {
      return l10n.result_durationHoursMinutes(duration.inHours, duration.inMinutes.remainder(60));
    } else if (duration.inMinutes > 0) {
      return l10n.result_durationMinutesSeconds(duration.inMinutes, duration.inSeconds.remainder(60));
    } else {
      return l10n.result_durationSeconds(duration.inSeconds);
    }
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

  String _getStatusMessage(AppLocalizations l10n) {
    if (result.wasCancelled) {
      return l10n.result_status_cancelled;
    } else if (result.errorCount > 0) {
      return l10n.result_status_error;
    } else if (result.successCount == 0) {
      return l10n.result_status_noNewFiles;
    } else {
      return l10n.result_status_completed;
    }
  }
}
