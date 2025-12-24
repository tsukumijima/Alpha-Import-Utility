/// ロギングサービス
///
/// アプリケーションのログをファイルに出力する。
/// ログファイルは起動ごとに新規作成され、以下の場所に保存される:
/// - macOS: ~/Library/Application Support/Alpha-Import-Utility/Logs/
/// - Windows: %APPDATA%/Alpha-Import-Utility/Logs/
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// ログレベル
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// ロギングサービス
///
/// シングルトンパターンで実装し、アプリ全体で共有する。
/// ログはファイルとコンソールの両方に出力される。
class LoggingService {
  /// シングルトンインスタンス
  static LoggingService? _instance;

  /// ログファイル
  File? _logFile;

  /// ログファイルへの書き込み用シンク
  IOSink? _logSink;

  /// 初期化済みフラグ
  bool _initialized = false;

  /// プライベートコンストラクタ
  LoggingService._();

  /// シングルトンインスタンスを取得
  static LoggingService get instance {
    _instance ??= LoggingService._();
    return _instance!;
  }

  /// 初期化
  ///
  /// ログディレクトリを作成し、新しいログファイルを開く。
  /// アプリ起動時に一度呼び出す必要がある。
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final logDir = await _getLogDirectory();
      await logDir.create(recursive: true);

      // ログファイル名を生成（YYYYMMDD_HHMMSS.log）
      final now = DateTime.now();
      final fileName =
          '${now.year}${_padZero(now.month)}${_padZero(now.day)}_'
          '${_padZero(now.hour)}${_padZero(now.minute)}${_padZero(now.second)}.log';

      _logFile = File(p.join(logDir.path, fileName));
      _logSink = _logFile!.openWrite(mode: FileMode.append);

      _initialized = true;

      // 起動ログを出力
      info('Application started.');
      info('Log file: ${_logFile!.path}.');
      info('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}.');
    } catch (ex) {
      // ログ初期化に失敗してもアプリは続行する（コンソール出力のみ）
      // ignore: avoid_print
      print('Failed to initialize logging: $ex');
    }
  }

  /// ログディレクトリを取得
  ///
  /// macOS: ~/Library/Application Support/Alpha-Import-Utility/Logs/
  /// Windows: %APPDATA%/Alpha-Import-Utility/Logs/
  Future<Directory> _getLogDirectory() async {
    final String basePath;

    if (Platform.isMacOS) {
      // macOS: ~/Library/Application Support/
      final home = Platform.environment['HOME'] ?? '/tmp';
      basePath = p.join(home, 'Library', 'Application Support');
    } else if (Platform.isWindows) {
      // Windows: %APPDATA%
      basePath =
          Platform.environment['APPDATA'] ?? p.join(Platform.environment['USERPROFILE'] ?? '', 'AppData', 'Roaming');
    } else {
      // Linux/その他: ~/.local/share/
      final home = Platform.environment['HOME'] ?? '/tmp';
      basePath = p.join(home, '.local', 'share');
    }

    return Directory(p.join(basePath, 'Alpha-Import-Utility', 'Logs'));
  }

  /// 数値を 2 桁のゼロ埋め文字列に変換
  String _padZero(int value) => value.toString().padLeft(2, '0');

  /// ログメッセージをフォーマット
  String _formatMessage(LogLevel level, String message, {String? tag}) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${_padZero(now.month)}-${_padZero(now.day)} '
        '${_padZero(now.hour)}:${_padZero(now.minute)}:${_padZero(now.second)}.${now.millisecond.toString().padLeft(3, '0')}';

    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag != null ? '[$tag] ' : '';

    return '$timestamp $levelStr $tagStr$message';
  }

  /// ログを出力
  void _log(LogLevel level, String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final formattedMessage = _formatMessage(level, message, tag: tag);

    // コンソール出力
    // ignore: avoid_print
    print(formattedMessage);

    // エラー情報があれば追加出力
    if (error != null) {
      // ignore: avoid_print
      print('  Error: $error');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print('  StackTrace:\n$stackTrace');
    }

    // ファイル出力
    if (_logSink != null) {
      _logSink!.writeln(formattedMessage);
      if (error != null) {
        _logSink!.writeln('  Error: $error');
      }
      if (stackTrace != null) {
        _logSink!.writeln('  StackTrace:\n$stackTrace');
      }
    }
  }

  /// デバッグログを出力
  void debug(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  /// 情報ログを出力
  void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// 警告ログを出力
  void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// エラーログを出力
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// デバイス検出のログ
  void logDeviceDetected(String deviceName, String mountPoint, bool isSonyCard) {
    info(
      'Device detected: $deviceName at $mountPoint (Sony SD: $isSonyCard).',
      tag: 'DeviceDetector',
    );
  }

  /// デバイス切断のログ
  void logDeviceDisconnected(String mountPoint) {
    info('Device disconnected: $mountPoint.', tag: 'DeviceDetector');
  }

  /// 取り込み開始のログ
  void logImportStarted(String sourcePath, int fileCount) {
    info(
      'Import started from $sourcePath ($fileCount files).',
      tag: 'ImportEngine',
    );
  }

  /// 取り込み完了のログ
  void logImportCompleted(int successCount, int skippedCount, int errorCount, Duration duration) {
    info(
      'Import completed: $successCount success, $skippedCount skipped, $errorCount errors '
      '(${duration.inSeconds}s).',
      tag: 'ImportEngine',
    );
  }

  /// ファイルコピーのログ
  void logFileCopied(String sourceFile, String destFile) {
    debug('Copied: $sourceFile -> $destFile.', tag: 'ImportEngine');
  }

  /// ファイルスキップのログ
  void logFileSkipped(String sourceFile, String reason) {
    debug('Skipped: $sourceFile ($reason).', tag: 'ImportEngine');
  }

  /// 設定変更のログ
  void logSettingsChanged(String settingName, String newValue) {
    info('Settings changed: $settingName = $newValue.', tag: 'Settings');
  }

  /// リソースを解放
  Future<void> dispose() async {
    info('Application terminated.');
    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;
    _logFile = null;
    _initialized = false;
  }

  /// ログファイルのパスを取得（UI 表示用）
  String? get logFilePath => _logFile?.path;

  /// ログディレクトリのパスを取得（UI 表示用）
  Future<String> getLogDirectoryPath() async {
    final logDir = await _getLogDirectory();
    return logDir.path;
  }
}
