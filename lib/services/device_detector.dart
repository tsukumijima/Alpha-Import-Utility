/// デバイス検出機能
///
/// リムーバブルドライブを検出し、Sony α SD カードを識別する。
/// 定期的なポーリングによるデバイス接続・切断の監視機能を提供する。
library;

import 'dart:async';
import 'dart:io';

import 'package:disks_desktop/disks_desktop.dart';

import 'sony_filesystem.dart';
import 'logging_service.dart';

/// 検出されたデバイスの情報
class DetectedDevice {
  /// デバイスのマウントポイント（ルートパス）
  final String mountPoint;

  /// デバイス名（ボリュームラベル）
  final String? name;

  /// デバイスの総容量（バイト）
  final int? totalSize;

  /// デバイスの使用済み容量（バイト）
  final int? usedSize;

  /// デバイスの空き容量（バイト）
  final int? freeSize;

  /// Sony α SD カード構造として有効かどうか
  final bool isSonyAlphaCard;

  /// デバイスタイプ
  final DeviceType type;

  DetectedDevice({
    required this.mountPoint,
    this.name,
    this.totalSize,
    this.usedSize,
    this.freeSize,
    required this.isSonyAlphaCard,
    required this.type,
  });

  /// 表示名を取得
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    // マウントポイントからボリューム名を抽出
    if (Platform.isWindows) {
      return mountPoint; // 例: 'D:\'
    } else {
      // macOS/Linux: /Volumes/XXX の XXX 部分
      final parts = mountPoint.split('/');
      return parts.isNotEmpty ? parts.last : mountPoint;
    }
  }

  /// 容量情報を人間が読みやすい形式で取得（全体容量のみ）
  String? get formattedSize {
    if (totalSize == null) return null;
    return _formatBytes(totalSize!);
  }

  /// 空き容量を人間が読みやすい形式で取得
  String? get formattedFreeSize {
    if (freeSize == null) return null;
    return _formatBytes(freeSize!);
  }

  /// 使用済み容量を人間が読みやすい形式で取得
  String? get formattedUsedSize {
    if (usedSize == null) return null;
    return _formatBytes(usedSize!);
  }

  /// 容量情報を「全体 (使用済み / 空き)」形式で取得
  String? get formattedSizeDetail {
    if (totalSize == null) return null;

    final total = _formatBytes(totalSize!);

    if (usedSize != null && freeSize != null) {
      final used = _formatBytes(usedSize!);
      final free = _formatBytes(freeSize!);
      return '$total（使用: $used / 空き: $free）';
    }

    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  String toString() {
    return 'DetectedDevice(name: $displayName, path: $mountPoint, isSony: $isSonyAlphaCard)';
  }
}

/// デバイスの種類
enum DeviceType {
  /// SD カード（カードリーダー経由）
  SDCard,

  /// USB ストレージ（カメラ直接接続など）
  USBStorage,

  /// ネットワークドライブ
  NetworkDrive,

  /// ローカルフォルダ（手動選択）
  LocalFolder,

  /// 不明
  Unknown,
}

/// デバイス検出サービス
///
/// リムーバブルドライブの検出と Sony SD カードの識別を行う。
/// ポーリングによるデバイス監視機能を提供する。
class DeviceDetector {
  /// ポーリング間隔（秒）
  static const int _pollingIntervalSeconds = 5;

  /// スキャンタイムアウト（秒）
  static const int _scanTimeoutSeconds = 10;

  /// ロガー
  final _log = LoggingService.instance;

  /// macOS で除外するシステムパスのパターン
  ///
  /// iOS Simulator、Xcode 関連、システムボリュームなどを除外する。
  static final List<RegExp> _excludedPathPatterns = [
    // iOS Simulator のボリューム
    RegExp(r'/Library/Developer/CoreSimulator'),
    // Xcode 関連
    RegExp(r'/Applications/Xcode'),
    // システムボリューム
    RegExp(r'^/System'),
    RegExp(r'^/private'),
    // Time Machine
    RegExp(r'\.timemachine'),
    RegExp(r'Time Machine'),
    // Recovery パーティション
    RegExp(r'Recovery'),
    RegExp(r'Preboot'),
    RegExp(r'VM'),
  ];

  /// 除外対象のボリューム名パターン
  static final List<RegExp> _excludedNamePatterns = [
    RegExp(r'^AppleAPFS', caseSensitive: false),
    RegExp(r'^com\.apple', caseSensitive: false),
    RegExp(r'^Macintosh HD', caseSensitive: false),
  ];

  /// ポーリングタイマー
  Timer? _pollingTimer;

  /// ポーリングが一時停止中かどうか
  bool _isPaused = false;

  /// 現在検出されているデバイス
  List<DetectedDevice> _currentDevices = [];

  /// デバイス変更通知コールバック
  void Function(List<DetectedDevice> devices)? onDevicesChanged;

  /// 検出済みデバイスを取得
  List<DetectedDevice> get currentDevices => List.unmodifiable(_currentDevices);

  /// ポーリングが動作中かどうか
  bool get isPolling => _pollingTimer != null && !_isPaused;

  /// デバイスをスキャンする
  ///
  /// リムーバブルドライブを列挙し、Sony α SD カード構造を検証する。
  /// タイムアウト付きで実行し、ハングを防止する。
  Future<List<DetectedDevice>> scan() async {
    _log.debug('Starting device scan.', tag: 'DeviceDetector');

    try {
      // タイムアウト付きでスキャンを実行
      final devices = await _scanInternal().timeout(
        Duration(seconds: _scanTimeoutSeconds),
        onTimeout: () {
          _log.warning(
            'Device scan timed out after $_scanTimeoutSeconds seconds.',
            tag: 'DeviceDetector',
          );
          return <DetectedDevice>[];
        },
      );

      _log.debug(
        'Device scan completed: ${devices.length} devices found.',
        tag: 'DeviceDetector',
      );

      _currentDevices = devices;
      return devices;
    } catch (ex, stackTrace) {
      _log.error(
        'Device scan failed.',
        tag: 'DeviceDetector',
        error: ex,
        stackTrace: stackTrace,
      );
      _currentDevices = [];
      return [];
    }
  }

  /// 内部スキャン処理
  Future<List<DetectedDevice>> _scanInternal() async {
    final devices = <DetectedDevice>[];

    // disks_desktop パッケージでディスク一覧を取得
    final repository = DisksRepository();
    final disks = await repository.query;

    _log.debug('Found ${disks.length} disk(s) total.', tag: 'DeviceDetector');

    for (final disk in disks) {
      final volumeName = disk.description;
      final mountPoints = disk.mountpoints;
      final mountPoint = mountPoints.isNotEmpty ? mountPoints.first.path : 'N/A';

      _log.debug(
        'Checking disk: $volumeName, mountPoint: $mountPoint, removable: ${disk.removable}, card: ${disk.card}, usb: ${disk.usb}.',
        tag: 'DeviceDetector',
      );

      // リムーバブルドライブのみを対象とする
      if (!disk.removable) {
        _log.debug('Skipping non-removable disk: $volumeName.', tag: 'DeviceDetector');
        continue;
      }

      // PMHOME ボリュームはスキップ（ライセンス情報のみ）
      if (volumeName.toUpperCase() == 'PMHOME') {
        _log.debug('Skipping PMHOME volume (license info only).', tag: 'DeviceDetector');
        continue;
      }

      // マウントポイントを取得
      if (mountPoints.isEmpty) {
        _log.debug('Skipping disk with no mount points: $volumeName.', tag: 'DeviceDetector');
        continue;
      }

      // macOS システムボリュームを除外
      if (_shouldExcludeDevice(mountPoint, volumeName)) {
        _log.debug(
          'Excluding system volume: $volumeName at $mountPoint.',
          tag: 'DeviceDetector',
        );
        continue;
      }

      // Sony α SD カード構造を検証
      final sonyFs = SonyFilesystemService(mountPoint);
      final validation = await sonyFs.validate();

      // 空き容量情報を取得
      final diskSpace = await _getDiskSpace(mountPoint);

      final device = DetectedDevice(
        mountPoint: mountPoint,
        name: disk.description,
        totalSize: diskSpace?.total ?? disk.size,
        usedSize: diskSpace?.used,
        freeSize: diskSpace?.free,
        isSonyAlphaCard: validation.isValid,
        type: _determineDeviceType(disk),
      );

      devices.add(device);
      _log.logDeviceDetected(device.displayName, mountPoint, validation.isValid);
    }

    return devices;
  }

  /// デバイスを除外すべきかどうかを判定
  ///
  /// macOS のシステムボリュームや開発用ボリュームを除外する。
  bool _shouldExcludeDevice(String mountPoint, String volumeName) {
    // パスパターンでチェック
    for (final pattern in _excludedPathPatterns) {
      if (pattern.hasMatch(mountPoint)) {
        return true;
      }
    }

    // ボリューム名パターンでチェック
    for (final pattern in _excludedNamePatterns) {
      if (pattern.hasMatch(volumeName)) {
        return true;
      }
    }

    return false;
  }

  /// ディスク情報からデバイスタイプを判定
  DeviceType _determineDeviceType(Disk disk) {
    // disks_desktop のプロパティに基づいて判定
    if (disk.card == true) {
      return DeviceType.SDCard;
    } else if (disk.usb == true) {
      return DeviceType.USBStorage;
    } else if (disk.removable) {
      return DeviceType.SDCard;
    }
    return DeviceType.Unknown;
  }

  /// マウントポイントの空き容量情報を取得
  ///
  /// df コマンドを使用してディスクの使用状況を取得する。
  /// 返り値は (totalBytes, usedBytes, freeBytes) のタプル。
  /// 取得に失敗した場合は null を返す。
  Future<({int total, int used, int free})?> _getDiskSpace(
    String mountPoint,
  ) async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        // df -k でキロバイト単位で出力
        final result = await Process.run('df', ['-k', mountPoint]);
        if (result.exitCode != 0) return null;

        final lines = (result.stdout as String).split('\n');
        if (lines.length < 2) return null;

        // ヘッダー行をスキップして 2 行目をパース
        // macOS の df -k 出力例:
        // Filesystem 1024-blocks Used Available Capacity iused ifree %iused Mounted on
        // /dev/disk4s1 62357504 33591296 28766208 54% 0 0 0% /Volumes/Untitled
        final parts = lines[1].split(RegExp(r'\s+'));
        if (parts.length < 4) return null;

        final totalKb = int.tryParse(parts[1]);
        final usedKb = int.tryParse(parts[2]);
        final freeKb = int.tryParse(parts[3]);

        if (totalKb == null || usedKb == null || freeKb == null) return null;

        return (
          total: totalKb * 1024,
          used: usedKb * 1024,
          free: freeKb * 1024,
        );
      } else if (Platform.isWindows) {
        // Windows では fsutil を使用（wmic は廃止されたため）
        // fsutil volume diskfree D:
        // 出力例:
        // Total # of bytes         : 64023257088
        // Total # of free bytes    : 30123456789
        // Total # of avail free bytes : 30123456789
        final driveLetter = mountPoint.replaceAll(r'\', '');
        final result = await Process.run('fsutil', [
          'volume',
          'diskfree',
          driveLetter,
        ]);
        if (result.exitCode != 0) return null;

        final output = result.stdout as String;
        int? totalBytes;
        int? freeBytes;

        // 各行をパース
        for (final line in output.split('\n')) {
          // "Total # of bytes" の行から総容量を取得
          if (line.contains('Total # of bytes') && !line.contains('free')) {
            final match = RegExp(r':\s*(\d+)').firstMatch(line);
            if (match != null) {
              totalBytes = int.tryParse(match.group(1)!);
            }
          }
          // "Total # of free bytes" の行から空き容量を取得
          else if (line.contains('Total # of free bytes')) {
            final match = RegExp(r':\s*(\d+)').firstMatch(line);
            if (match != null) {
              freeBytes = int.tryParse(match.group(1)!);
            }
          }
        }

        if (totalBytes == null || freeBytes == null) return null;

        return (
          total: totalBytes,
          used: totalBytes - freeBytes,
          free: freeBytes,
        );
      }
    } catch (ex) {
      _log.debug(
        'Failed to get disk space for $mountPoint: $ex.',
        tag: 'DeviceDetector',
      );
    }
    return null;
  }

  /// ポーリングを開始する
  ///
  /// 定期的にデバイスをスキャンし、変更があれば通知する。
  void startPolling() {
    stopPolling();
    _log.info('Starting device polling (interval: ${_pollingIntervalSeconds}s).', tag: 'DeviceDetector');

    // 初回スキャン
    scan().then((devices) {
      if (onDevicesChanged != null) {
        onDevicesChanged!(devices);
      }
    });

    // 定期スキャン開始
    _pollingTimer = Timer.periodic(
      Duration(seconds: _pollingIntervalSeconds),
      (_) async {
        final previousPaths = _currentDevices.map((d) => d.mountPoint).toSet();
        final devices = await scan();
        final currentPaths = devices.map((d) => d.mountPoint).toSet();

        // 変更があれば通知
        if (!_setEquals(previousPaths, currentPaths)) {
          _log.info('Device list changed.', tag: 'DeviceDetector');
          if (onDevicesChanged != null) {
            onDevicesChanged!(devices);
          }
        }
      },
    );
  }

  /// ポーリングを停止する
  void stopPolling() {
    if (_pollingTimer != null) {
      _log.info('Stopping device polling.', tag: 'DeviceDetector');
      _pollingTimer?.cancel();
      _pollingTimer = null;
      _isPaused = false;
    }
  }

  /// ポーリングを一時停止する
  ///
  /// 取り込み処理中など、一時的にスキャンを停止したい場合に使用する。
  /// resumePolling() で再開できる。
  void pausePolling() {
    if (_pollingTimer != null && !_isPaused) {
      _log.info('Pausing device polling.', tag: 'DeviceDetector');
      _pollingTimer?.cancel();
      _pollingTimer = null;
      _isPaused = true;
    }
  }

  /// 一時停止したポーリングを再開する
  ///
  /// pausePolling() で一時停止した場合のみ有効。
  /// stopPolling() で停止した場合は startPolling() を使用すること。
  void resumePolling() {
    if (_isPaused) {
      _log.info('Resuming device polling.', tag: 'DeviceDetector');
      _isPaused = false;
      startPolling();
    }
  }

  /// 2 つの Set が等しいかを比較
  bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
  }

  /// 手動でフォルダを追加する
  ///
  /// ユーザーが選択したフォルダを Sony SD カード構造として検証し、
  /// デバイスリストに追加する。
  Future<DetectedDevice?> addManualFolder(String folderPath) async {
    _log.info('Adding manual folder: $folderPath.', tag: 'DeviceDetector');

    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      _log.warning('Folder does not exist: $folderPath.', tag: 'DeviceDetector');
      return null;
    }

    // Sony α SD カード構造を検証
    final sonyFs = SonyFilesystemService(folderPath);
    final validation = await sonyFs.validate();

    final device = DetectedDevice(
      mountPoint: folderPath,
      name: folderPath.split(Platform.pathSeparator).last,
      isSonyAlphaCard: validation.isValid,
      type: DeviceType.LocalFolder,
    );

    _log.logDeviceDetected(device.displayName, folderPath, validation.isValid);

    // デバイスリストに追加（重複チェック）
    if (!_currentDevices.any((d) => d.mountPoint == folderPath)) {
      _currentDevices.add(device);

      if (onDevicesChanged != null) {
        onDevicesChanged!(_currentDevices);
      }
    }

    return device;
  }

  /// リソースを解放する
  void dispose() {
    stopPolling();
  }
}
