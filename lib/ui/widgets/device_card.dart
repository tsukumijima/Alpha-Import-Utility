/// デバイスカードウィジェット
///
/// 検出されたデバイス（SD カード、USB ストレージなど）を表示するカード。
library;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
              Expanded(child: _buildInfo(context, theme, l10n, isEnabled)),

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
      case DeviceType.SDCard:
        icon = Icons.sd_card;
        break;
      case DeviceType.USBStorage:
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
  Widget _buildInfo(BuildContext context, ThemeData theme, AppLocalizations l10n, bool isEnabled) {
    final textColor = isEnabled ? Colors.white : Colors.white54;
    final sizeDetail = _buildSizeDetail(l10n);

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
        if (sizeDetail != null) ...[
          const SizedBox(height: 4),
          Text(
            sizeDetail,
            style: theme.textTheme.bodySmall?.copyWith(color: textColor.withValues(alpha: 0.7)),
          ),
        ],

        // Sony SD カードでない場合の警告
        if (!device.isSonyAlphaCard) ...[
          const SizedBox(height: 8),
          Text(
            l10n.deviceCard_notRecognized,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }

  /// 容量情報の表示テキストを取得
  ///
  /// 使用済みと空き容量が取得できる場合は詳細表示を行う。
  /// 取得できない場合は総容量のみを返す。
  String? _buildSizeDetail(AppLocalizations l10n) {
    final total = device.formattedSize;
    if (total == null) {
      return null;
    }
    final used = device.formattedUsedSize;
    final free = device.formattedFreeSize;
    if (used != null && free != null) {
      return l10n.deviceCard_storageDetail(total, used, free);
    }
    return total;
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
    final l10n = AppLocalizations.of(context);

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
              l10n.deviceCard_noDevices,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.deviceCard_connectHint,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onSelectFolder,
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.deviceCard_manualSelect),
            ),
          ],
        ),
      ),
    );
  }
}
