/// アップデート通知バナーウィジェット
///
/// 新しいバージョンが利用可能な場合に表示する
/// 画面上部の控えめな情報バナー。
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/github_release.dart';
import '../../services/logging_service.dart';

/// アップデート通知バナー
///
/// 閉じるボタン付きの情報バナーで、
/// タップするとブラウザでリリースページを開く。
class UpdateBanner extends StatelessWidget {
  /// 最新リリース情報
  final GitHubRelease release;

  /// 現在のバージョン
  final String currentVersion;

  /// 閉じるボタンが押されたときのコールバック
  final VoidCallback onDismiss;

  /// ロガー
  LoggingService get _log => LoggingService.instance;

  const UpdateBanner({
    super.key,
    required this.release,
    required this.currentVersion,
    required this.onDismiss,
  });

  /// リリースページをブラウザで開く
  Future<void> _openReleasePage(BuildContext context) async {
    final url = Uri.parse(release.htmlUrl);
    _log.info('Opening release page: ${release.htmlUrl}.', tag: 'UpdateBanner');

    try {
      final isLaunched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!isLaunched) {
        _log.warning('Failed to launch URL.', tag: 'UpdateBanner');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ブラウザを開けませんでした。')),
          );
        }
      }
    } catch (ex, stackTrace) {
      _log.error(
        'Failed to launch URL.',
        tag: 'UpdateBanner',
        error: ex,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ブラウザを開けませんでした。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // アイコン
          Icon(
            Icons.system_update,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),

          // メッセージ
          Expanded(
            child: GestureDetector(
              onTap: () => _openReleasePage(context),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '新しいバージョン '),
                      TextSpan(
                        text: 'v${release.version}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const TextSpan(text: ' が利用可能です。'),
                      TextSpan(
                        text: ' ダウンロード',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),

          // 閉じるボタン
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            tooltip: '閉じる',
            color: Colors.white54,
            hoverColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}
