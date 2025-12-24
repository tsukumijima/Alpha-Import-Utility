/// デバイスカードウィジェット
///
/// 検出されたデバイス（SD カード、USB ストレージなど）を表示するカード。
library;

import 'package:flutter/material.dart';

import '../../services/device_detector.dart';

/// デバイスカードウィジェット
///
/// デバイスの情報を表示し、タップで取り込みを開始する。
class DeviceCard extends StatelessWidget {
  /// 表示するデバイス
  final DetectedDevice device;

  /// タップ時のコールバック
  final VoidCallback? onTap;

  /// デバイスが選択可能か（Sony SD カード構造の場合のみ true）
  final bool isSelectable;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.isSelectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = isSelectable && device.isSonyAlphaCard;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // デバイスアイコン
              _buildIcon(context, isEnabled),
              const SizedBox(width: 16),

              // デバイス情報
              Expanded(child: _buildInfo(context, theme, isEnabled)),

              // ステータスアイコン
              _buildStatusIcon(context, isEnabled),
            ],
          ),
        ),
      ),
    );
  }

  /// デバイスアイコンを構築
  Widget _buildIcon(BuildContext context, bool isEnabled) {
    IconData icon;
    Color iconColor;

    switch (device.type) {
      case DeviceType.SdCard:
        icon = Icons.sd_card;
        break;
      case DeviceType.UsbStorage:
        icon = Icons.usb;
        break;
      case DeviceType.LocalFolder:
        icon = Icons.folder;
        break;
      default:
        icon = Icons.storage;
    }

    if (device.isSonyAlphaCard) {
      iconColor = Theme.of(context).colorScheme.primary;
    } else {
      iconColor = isEnabled ? Colors.white70 : Colors.white38;
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 32, color: iconColor),
    );
  }

  /// デバイス情報を構築
  Widget _buildInfo(BuildContext context, ThemeData theme, bool isEnabled) {
    final textColor = isEnabled ? Colors.white : Colors.white54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // デバイス名
        Text(
          device.displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // マウントポイント
        Text(
          device.mountPoint,
          style: theme.textTheme.bodySmall?.copyWith(color: textColor.withValues(alpha: 0.7)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // 容量情報（取得できた場合のみ）
        if (device.formattedSize != null) ...[
          const SizedBox(height: 4),
          Text(
            device.formattedSize!,
            style: theme.textTheme.bodySmall?.copyWith(color: textColor.withValues(alpha: 0.7)),
          ),
        ],

        // Sony SD カードでない場合の警告
        if (!device.isSonyAlphaCard) ...[
          const SizedBox(height: 8),
          Text(
            'Sony SD カード構造ではありません',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }

  /// ステータスアイコンを構築
  Widget _buildStatusIcon(BuildContext context, bool isEnabled) {
    if (device.isSonyAlphaCard) {
      return Icon(
        Icons.chevron_right,
        color: isEnabled ? Theme.of(context).colorScheme.primary : Colors.white38,
        size: 28,
      );
    }
    return const SizedBox.shrink();
  }
}

/// デバイス未検出時のプレースホルダーカード
class EmptyDeviceCard extends StatelessWidget {
  /// フォルダ選択ボタンがタップされた時のコールバック
  final VoidCallback? onSelectFolder;

  const EmptyDeviceCard({super.key, this.onSelectFolder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sd_card_outlined,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              'デバイスが検出されていません',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'SD カードまたはカメラを接続してください',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onSelectFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('フォルダを手動選択'),
            ),
          ],
        ),
      ),
    );
  }
}
