/// デバイス検出機能
///
/// リムーバブルドライブを検出し、Sony α SD カードを識別する。
/// 定期的なポーリングによるデバイス接続・切断の監視機能を提供する。
library;

import 'dart:async';
import 'dart:io';

import 'package:disks_desktop/disks_desktop.dart';
import 'package:path/path.dart' as p;

import 'file_time_service.dart';
import 'logging_service.dart';
import 'sony_filesystem.dart';

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

  /// PMHOME の最大想定サイズ（バイト）
  ///
  /// Sony カメラの PMHOME はおおむね 64MB 程度のため、安全側で 128MB を上限とする。
  static const int _pmhomeMaxBytes = 128 * 1024 * 1024;

  /// ポーリングタイマー
  Timer? _pollingTimer;

  /// ポーリングが一時停止中かどうか
  bool _isPaused = false;

  /// ポーリングスキャンが実行中かどうか
  ///
  /// Timer.periodic のコールバックが async で scan() を await する際、
  /// スキャンに時間がかかると次のタイマーイベントと重複する可能性があるため、
  /// このフラグで多重実行を防止する。
  bool _isPollingInProgress = false;

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
    final seenMountPoints = <String>{};

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

      // マウントポイントを取得
      if (mountPoints.isEmpty) {
        _log.debug('Skipping disk with no mount points: $volumeName.', tag: 'DeviceDetector');
        continue;
      }

      // 各デバイスの処理を try-catch で囲み、一つのデバイスでエラーが発生しても
      // 他のデバイスのスキャンは継続できるようにする
      // （例: SD カードリーダーにカードが入っていない場合など）
      try {
        // PMHOME ボリュームはスキップ（ライセンス情報のみ）
        final isPmhomeVolume = await _isPMHOMEVolume(
          disk,
          mountPoint,
          volumeName,
        );
        if (isPmhomeVolume) {
          _log.debug('Skipping PMHOME volume (license info only).', tag: 'DeviceDetector');
          continue;
        }

        // 同一マウントポイントの重複を排除
        final normalizedMountPoint = _normalizeMountPoint(mountPoint);
        if (seenMountPoints.contains(normalizedMountPoint)) {
          _log.debug(
            'Skipping duplicated mount point: $mountPoint.',
            tag: 'DeviceDetector',
          );
          continue;
        }
        seenMountPoints.add(normalizedMountPoint);

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
        final diskSpace = await _getDiskSpace(
          mountPoint,
          disk.size,
        );

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
      } on FileSystemException catch (ex) {
        // デバイスが準備できていない場合（SD カード未挿入など）はスキップ
        _log.debug(
          'Skipping device $volumeName at $mountPoint (not ready): $ex.',
          tag: 'DeviceDetector',
        );
        continue;
      }
    }

    return devices;
  }

  /// マウントポイントを正規化する
  ///
  /// 大文字小文字の違いや末尾の区切り文字差を吸収する。
  String _normalizeMountPoint(String mountPoint) {
    var normalized = mountPoint.trim();

    if (normalized.length > 1 && normalized.endsWith(Platform.pathSeparator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    if (Platform.isWindows) {
      normalized = normalized.toLowerCase();
    }

    return normalized;
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

  /// PMHOME ボリュームかどうかを判定
  ///
  /// ラベルが取得できない環境向けに、容量とルート直下の構造から判定する。
  /// SD カードリーダーにカードが入っていない場合など、デバイスが準備できていない
  /// 状態ではファイルシステムアクセスで例外が発生するため、その場合は false を返す。
  Future<bool> _isPMHOMEVolume(
    Disk disk,
    String mountPoint,
    String volumeName,
  ) async {
    // ボリューム名でまず判定（ファイルシステムアクセス不要）
    final normalizedVolumeName = volumeName.trim();
    if (normalizedVolumeName.isNotEmpty && normalizedVolumeName.toUpperCase() == 'PMHOME') {
      return true;
    }

    final normalizedMountName = p.basename(p.normalize(mountPoint)).trim();
    if (normalizedMountName.isNotEmpty && normalizedMountName.toUpperCase() == 'PMHOME') {
      return true;
    }

    // 容量が大きすぎる場合は PMHOME ではない
    final totalSize = disk.size;
    if (totalSize != null && totalSize > _pmhomeMaxBytes) {
      return false;
    }

    // ファイルシステムへのアクセスを試みる
    // SD カードリーダーにカードが入っていない場合など、デバイスが準備できていない
    // 状態では例外が発生するため、try-catch で囲む
    try {
      final rootDir = Directory(mountPoint);
      if (!await rootDir.exists()) {
        return false;
      }

      final rootEntries = await rootDir.list(followLinks: false).toList();
      if (rootEntries.isEmpty) {
        return false;
      }

      final rootEntryNames = rootEntries.map((entry) => p.basename(entry.path)).toList();
      final hasLicenseFolder = rootEntryNames.any(
        (entryName) => entryName.toUpperCase() == 'LICENSE',
      );
      if (!hasLicenseFolder) {
        return false;
      }

      // ルート直下に LICENSE 以外のフォルダやファイルがある場合は PMHOME とみなさない
      const allowedSystemEntries = [
        'LICENSE',
        'SYSTEM VOLUME INFORMATION',
        '\$RECYCLE.BIN',
      ];
      for (final entryName in rootEntryNames) {
        if (!allowedSystemEntries.contains(entryName.toUpperCase())) {
          return false;
        }
      }

      return true;
    } on FileSystemException catch (ex) {
      // デバイスが準備できていない場合（SD カード未挿入など）
      _log.debug(
        'Cannot access mount point $mountPoint (device may not be ready): $ex.',
        tag: 'DeviceDetector',
      );
      return false;
    }
  }

  /// SD カードリーダーを示すボリューム名のパターン
  ///
  /// Windows では SD カードリーダーが disk.card=false として認識されることがあるため、
  /// ボリューム名からカードリーダーを推測する。
  static final List<RegExp> _cardReaderNamePatterns = [
    RegExp(r'card\s*reader', caseSensitive: false),
    RegExp(r'flash\s*reader', caseSensitive: false),
    RegExp(r'sd\s*card', caseSensitive: false),
    RegExp(r'memory\s*card', caseSensitive: false),
    RegExp(r'multi.*reader', caseSensitive: false),
  ];

  /// ディスク情報からデバイスタイプを判定
  ///
  /// 判定優先順位:
  /// 1. disk.card == true → SD カード
  /// 2. ボリューム名がカードリーダーを示す場合 → SD カード
  /// 3. disk.usb == true → USB ストレージ（カメラ直接接続など）
  /// 4. disk.removable == true → 不明（SD カードとして扱う）
  DeviceType _determineDeviceType(Disk disk) {
    // disks_desktop が明示的にカードとして認識している場合
    if (disk.card == true) {
      return DeviceType.SDCard;
    }

    // ボリューム名からカードリーダーを推測
    // Windows では SD カードリーダーが disk.card=false, disk.usb=true と
    // 認識されることがあるため、名前ベースで判定する
    final volumeName = disk.description;
    for (final pattern in _cardReaderNamePatterns) {
      if (pattern.hasMatch(volumeName)) {
        _log.debug(
          'Detected SD card reader by volume name pattern: $volumeName.',
          tag: 'DeviceDetector',
        );
        return DeviceType.SDCard;
      }
    }

    // USB デバイスとして認識されている場合（カメラ直接接続など）
    if (disk.usb == true) {
      return DeviceType.USBStorage;
    }

    // リムーバブルだが上記に該当しない場合
    if (disk.removable) {
      return DeviceType.SDCard;
    }

    return DeviceType.Unknown;
  }

  /// マウントポイントの空き容量情報を取得
  ///
  /// ネイティブ実装経由で空き容量を取得し、総容量から使用量を算出する。
  /// 返り値は (totalBytes, usedBytes, freeBytes) のタプル。
  /// 取得に失敗した場合は null を返す。
  Future<({int total, int used, int free})?> _getDiskSpace(
    String mountPoint,
    int? totalSize,
  ) async {
    try {
      if (totalSize == null || totalSize <= 0) {
        return null;
      }

      final freeBytes = await FileTimeService.instance.getAvailableDiskSpace(
        mountPoint,
      );
      if (freeBytes == null) {
        return null;
      }

      return (
        total: totalSize,
        used: totalSize - freeBytes,
        free: freeBytes,
      );
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
        // 前回のスキャンが完了していなければスキップ
        if (_isPollingInProgress) {
          _log.debug(
            'Skipping polling scan: previous scan still in progress.',
            tag: 'DeviceDetector',
          );
          return;
        }

        _isPollingInProgress = true;
        try {
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
        } finally {
          _isPollingInProgress = false;
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
