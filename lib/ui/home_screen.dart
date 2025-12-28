/// メイン画面
///
/// デバイス一覧を表示し、取り込みを開始するメイン画面。
/// 3つのセクション（カメラ、SD カード、フォルダ）に分かれている。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../services/device_detector.dart';
import '../services/logging_service.dart';
import '../services/settings_service.dart';
import '../services/update_check_service.dart';
import 'import_dialog.dart';
import 'settings_dialog.dart';
import 'theme.dart';
import 'widgets/device_card.dart';
import 'widgets/update_banner.dart';

/// メイン画面ウィジェット
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// デバイス検出サービス
  final _deviceDetector = DeviceDetector();

  /// ロガー
  final _log = LoggingService.instance;

  /// 検出されたデバイス一覧
  List<DetectedDevice> _devices = [];

  /// スキャン中フラグ
  bool _isScanning = true;

  /// 現在の設定
  ImportSettings? _settings;

  /// アップデートチェック結果
  UpdateCheckResult? _updateCheckResult;

  /// アップデートバナーを表示するかどうか
  bool _isShowUpdateBanner = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _deviceDetector.dispose();
    super.dispose();
  }

  /// 初期化処理
  Future<void> _initialize() async {
    // 設定を読み込み
    _settings = await SettingsService.instance.loadImportSettings();

    // アップデートチェック（バックグラウンドで実行、UI をブロックしない）
    _checkForUpdates();

    // デバイス検出を開始
    _deviceDetector.onDevicesChanged = (devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
        });
      }
    };
    _deviceDetector.startPolling();

    // 初回スキャン
    final devices = await _deviceDetector.scan();
    if (mounted) {
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    }
  }

  /// アップデートをチェック
  Future<void> _checkForUpdates() async {
    final result = await UpdateCheckService.instance.checkForUpdates();
    if (mounted && result.isUpdateAvailable) {
      setState(() {
        _updateCheckResult = result;
      });
    }
  }

  /// 手動でフォルダを選択
  Future<void> _selectFolder() async {
    _log.info('Opening folder picker dialog.', tag: 'HomeScreen');

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'インポート元フォルダを選択',
      );

      if (result != null) {
        _log.info('Folder selected: $result.', tag: 'HomeScreen');
        final device = await _deviceDetector.addManualFolder(result);
        if (device != null && device.isSonyAlphaCard) {
          if (mounted) {
            _startImport(device);
          }
        } else if (mounted) {
          _log.warning('Selected folder is not a Sony SD card structure.', tag: 'HomeScreen');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('選択されたフォルダは Sony α カメラの SD カード構造として認識できませんでした。'),
            ),
          );
        }
      } else {
        _log.debug('Folder picker cancelled.', tag: 'HomeScreen');
      }
    } catch (ex, stackTrace) {
      _log.error('Folder picker failed.', tag: 'HomeScreen', error: ex, stackTrace: stackTrace);
    }
  }

  /// 設定画面を開く
  Future<void> _openSettings() async {
    final result = await showDialog<ImportSettings>(
      context: context,
      builder: (context) => SettingsDialog(settings: _settings!),
    );

    if (result != null) {
      await SettingsService.instance.saveImportSettings(result);
      setState(() {
        _settings = result;
      });
    }
  }

  /// 取り込みを開始
  Future<void> _startImport(DetectedDevice device) async {
    // 保存先フォルダが設定されているか確認
    if (_settings == null || !_settings!.hasDestinationFolder) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('保存先フォルダが未設定です'),
          content: const Text('取り込みを開始する前に、保存先フォルダを設定してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.settings),
              label: const Text('設定を開く'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings == true) {
        await _openSettings();
      }
      return;
    }

    // 取り込み中はデバイス検出のポーリングを一時停止
    // ログの可読性向上とリソース節約のため
    _log.info('Pausing device polling during import.', tag: 'HomeScreen');
    _deviceDetector.pausePolling();

    try {
      // 取り込みダイアログを表示
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ImportDialog(
          device: device,
          settings: _settings!,
        ),
      );
    } finally {
      // 取り込み完了後（成功・キャンセル問わず）にポーリングを再開
      _log.info('Resuming device polling after import.', tag: 'HomeScreen');
      _deviceDetector.resumePolling();
    }
  }

  /// デバイスタイプ別にフィルタ
  List<DetectedDevice> _getDevicesByType(DeviceType type) {
    return _devices.where((d) => d.type == type).toList();
  }

  /// USB ストレージ（カメラ直接接続）を取得
  List<DetectedDevice> get _cameraDevices => _getDevicesByType(DeviceType.USBStorage);

  /// SD カードを取得
  List<DetectedDevice> get _sdCardDevices => _getDevicesByType(DeviceType.SDCard);

  /// 手動選択フォルダを取得
  List<DetectedDevice> get _folderDevices => _getDevicesByType(DeviceType.LocalFolder);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: getGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー
              _buildHeader(context),

              // アップデートバナー（新しいバージョンがある場合のみ表示）
              if (_updateCheckResult?.isUpdateAvailable == true &&
                  _updateCheckResult?.latestRelease != null &&
                  _isShowUpdateBanner)
                UpdateBanner(
                  release: _updateCheckResult!.latestRelease!,
                  currentVersion: _updateCheckResult!.currentVersion,
                  onDismiss: () {
                    setState(() {
                      _isShowUpdateBanner = false;
                    });
                  },
                ),

              // コンテンツ
              Expanded(
                child: _isScanning ? _buildLoadingIndicator() : _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ヘッダーを構築
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // アプリロゴ
          Image.asset(
            'assets/images/logo.png',
            height: 34,
            filterQuality: FilterQuality.high,
          ),
          const Spacer(),

          // 更新ボタン
          IconButton(
            onPressed: _isScanning
                ? null
                : () async {
                    _log.info('Manual refresh triggered.', tag: 'HomeScreen');
                    setState(() => _isScanning = true);
                    try {
                      final devices = await _deviceDetector.scan();
                      if (mounted) {
                        setState(() {
                          _devices = devices;
                          _isScanning = false;
                        });
                      }
                    } catch (ex, stackTrace) {
                      _log.error('Manual refresh failed.', tag: 'HomeScreen', error: ex, stackTrace: stackTrace);
                      if (mounted) {
                        setState(() => _isScanning = false);
                      }
                    }
                  },
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '更新',
          ),

          // 設定ボタン
          IconButton(
            onPressed: _settings != null ? _openSettings : null,
            icon: const Icon(Icons.settings),
            tooltip: '設定',
          ),
        ],
      ),
    );
  }

  /// ローディングインジケーターを構築
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('デバイスをスキャン中...'),
        ],
      ),
    );
  }

  /// コンテンツを構築
  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カメラから取り込みセクション
          _buildSection(
            context,
            icon: Icons.camera_alt,
            title: 'カメラから取り込み',
            description: 'USB ケーブルで接続されたカメラから直接写真・動画を取り込みます。',
            devices: _cameraDevices,
            emptyMessage: 'カメラが接続されていません',
            emptyHint: 'USB ケーブルでカメラを接続してください',
          ),

          const SizedBox(height: 24),

          // SD カードから取り込みセクション
          _buildSection(
            context,
            icon: Icons.sd_card,
            title: 'SD カードから取り込み',
            description: 'SD カードリーダーを使用して、SD カードから写真・動画を取り込みます。',
            devices: _sdCardDevices,
            emptyMessage: 'SD カードが挿入されていません',
            emptyHint: 'SD カードをカードリーダーに挿入してください',
          ),

          const SizedBox(height: 24),

          // フォルダから取り込みセクション
          _buildFolderSection(context),
        ],
      ),
    );
  }

  /// セクションを構築
  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required List<DetectedDevice> devices,
    required String emptyMessage,
    required String emptyHint,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダー
        Row(
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 説明文
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white60,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // デバイス一覧またはプレースホルダー
        if (devices.isNotEmpty)
          ...devices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DeviceCard(
                device: device,
                onTap: () => _startImport(device),
              ),
            ),
          )
        else
          _buildEmptyPlaceholder(context, emptyMessage, emptyHint),
      ],
    );
  }

  /// フォルダセクションを構築
  Widget _buildFolderSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダー
        Row(
          children: [
            Icon(Icons.folder, size: 24, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              'フォルダから取り込み',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 説明文
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            'PC 上のフォルダを直接選択して取り込みます。過去のバックアップからの取り込みに便利です。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white60,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 手動選択済みフォルダ
        if (_folderDevices.isNotEmpty)
          ..._folderDevices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DeviceCard(
                device: device,
                onTap: () => _startImport(device),
              ),
            ),
          ),

        // フォルダ選択ボタン
        Card(
          child: InkWell(
            onTap: _selectFolder,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_open,
                      size: 32,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'フォルダを選択 ...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sony α カメラの SD カードのバックアップフォルダを選択してください',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.add,
                    color: Colors.white38,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 空のプレースホルダーを構築
  Widget _buildEmptyPlaceholder(
    BuildContext context,
    String message,
    String hint,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.device_unknown,
                size: 32,
                color: Colors.white24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
