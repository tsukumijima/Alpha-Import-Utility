/// Sony α SD カードのファイルシステム判定・スキャン機能
///
/// Sony α カメラで使用される SD カードの構造を検証し、
/// 取り込み対象のメディアファイルを列挙する。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/media_file.dart';
import '../models/import_result.dart';
import '../models/settings.dart';
import '../utils/exif_utils.dart';
import '../utils/file_utils.dart';
import '../utils/timezone_utils.dart';
import 'logging_service.dart';

/// Sony SD カード構造の検証結果
class SonyFilesystemValidation {
  /// 検証が成功したかどうか
  final bool isValid;

  /// DCIM フォルダが存在するか
  final bool hasDcimFolder;

  /// DCF フォルダ（3桁番号 + 5文字のサフィックス）が存在するか
  ///
  /// Sony カメラのデフォルトは "xxxMSDCF" だが、ユーザーがカスタマイズ可能。
  /// 日付形式の場合は "xxx10405" のように数字5桁になる。
  final bool hasDcfFolder;

  /// PRIVATE/M4ROOT/CLIP フォルダが存在するか
  final bool hasClipFolder;

  /// エラーメッセージ（検証失敗時のみ）
  final String? errorMessage;

  /// 検出された DCF フォルダの一覧
  final List<String> dcfFolders;

  SonyFilesystemValidation({
    required this.isValid,
    required this.hasDcimFolder,
    required this.hasDcfFolder,
    required this.hasClipFolder,
    this.errorMessage,
    this.dcfFolders = const [],
  });

  /// 成功の検証結果を作成
  factory SonyFilesystemValidation.success({
    required List<String> dcfFolders,
  }) {
    return SonyFilesystemValidation(
      isValid: true,
      hasDcimFolder: true,
      hasDcfFolder: true,
      hasClipFolder: true,
      dcfFolders: dcfFolders,
    );
  }

  /// 失敗の検証結果を作成
  factory SonyFilesystemValidation.failure({
    required String errorMessage,
    bool hasDcimFolder = false,
    bool hasDcfFolder = false,
    bool hasClipFolder = false,
  }) {
    return SonyFilesystemValidation(
      isValid: false,
      hasDcimFolder: hasDcimFolder,
      hasDcfFolder: hasDcfFolder,
      hasClipFolder: hasClipFolder,
      errorMessage: errorMessage,
    );
  }
}

/// Sony SD カードのスキャン結果
class SonyFilesystemScanResult {
  /// 取り込み対象のメディアファイル一覧
  final List<MediaFile> mediaFiles;

  /// スキャン時に検出した警告一覧
  final List<ImportWarning> warnings;

  SonyFilesystemScanResult({
    required this.mediaFiles,
    required this.warnings,
  });
}

/// Sony α SD カードのファイルシステム操作を行うサービス
class SonyFilesystemService {
  /// SD カードのルートパス
  final String rootPath;

  /// ロガー
  final _log = LoggingService.instance;

  SonyFilesystemService(this.rootPath);

  /// DCF フォルダ名のパターン
  ///
  /// Sony カメラでは以下の形式が使用される:
  /// - 標準形式: 3桁番号 + 5文字のサフィックス（例: 100MSDCF, 100ALPHA）
  /// - 日付形式: 3桁番号 + 5桁の日付（例: 10010405 = 100番 + 04月05日）
  ///
  /// サフィックスはカメラ設定でカスタマイズ可能なため、
  /// 3桁番号 + 任意の5文字（英数字・アンダースコア）にマッチさせる。
  static final RegExp _dcfFolderPattern = RegExp(
    r'^\d{3}[A-Z0-9_]{5}$',
    caseSensitive: false,
  );

  /// 取り込み対象の静止画拡張子
  static const Set<String> _photoExtensions = {'.jpg', '.jpeg', '.arw', '.hif', '.heif'};

  /// 取り込み対象の動画拡張子
  static const Set<String> _videoExtensions = {'.mp4'};

  /// 取り込み対象のメタデータ拡張子
  static const Set<String> _metaExtensions = {'.xml'};

  /// Sony SD カード構造を検証する
  ///
  /// 以下の条件を全て満たす場合に有効と判定する:
  /// 1. DCIM/ フォルダが存在する
  /// 2. DCIM/ 配下に DCF 形式（3桁番号 + 5文字）のフォルダが 1 つ以上存在する
  /// 3. PRIVATE/M4ROOT/CLIP/ フォルダが存在する
  Future<SonyFilesystemValidation> validate() async {
    _log.debug('Starting Sony SD card validation for: $rootPath.', tag: 'SonyFilesystem');

    final rootDir = Directory(rootPath);

    if (!await rootDir.exists()) {
      _log.warning('Validation failed: Root path does not exist: $rootPath.', tag: 'SonyFilesystem');
      return SonyFilesystemValidation.failure(
        errorMessage: 'Root path does not exist: $rootPath',
      );
    }

    // DCIM フォルダの確認（大文字小文字非依存）
    final dcimPath = await _findCaseInsensitiveDirectory(rootPath, 'DCIM');
    if (dcimPath == null) {
      _log.debug('Validation failed: DCIM folder not found in $rootPath.', tag: 'SonyFilesystem');
      return SonyFilesystemValidation.failure(
        errorMessage: 'DCIM folder not found',
      );
    }
    _log.debug('Found DCIM folder: $dcimPath.', tag: 'SonyFilesystem');

    // DCF フォルダの確認（3桁番号 + 5文字のサフィックス）
    final dcfFolders = await _findDcfFolders(dcimPath);
    if (dcfFolders.isEmpty) {
      // DCIM 内のフォルダ一覧をログに出力（デバッグ用）
      final dcimContents = await _listDirectoryContents(dcimPath);
      _log.warning(
        'Validation failed: No DCF folder (3-digit number + 5-char suffix) found in DCIM. '
        'Contents: $dcimContents.',
        tag: 'SonyFilesystem',
      );
      return SonyFilesystemValidation.failure(
        errorMessage: 'No DCF folder found in DCIM (expected format: 100XXXXX)',
        hasDcimFolder: true,
      );
    }
    _log.debug(
      'Found ${dcfFolders.length} DCF folder(s): ${dcfFolders.map((f) => p.basename(f)).join(", ")}.',
      tag: 'SonyFilesystem',
    );

    // PRIVATE/M4ROOT/CLIP フォルダの確認
    final privatePath = await _findCaseInsensitiveDirectory(rootPath, 'PRIVATE');
    if (privatePath == null) {
      _log.debug('Validation failed: PRIVATE folder not found in $rootPath.', tag: 'SonyFilesystem');
      return SonyFilesystemValidation.failure(
        errorMessage: 'PRIVATE folder not found',
        hasDcimFolder: true,
        hasDcfFolder: true,
      );
    }

    final m4rootPath = await _findCaseInsensitiveDirectory(privatePath, 'M4ROOT');
    if (m4rootPath == null) {
      _log.debug('Validation failed: M4ROOT folder not found in $privatePath.', tag: 'SonyFilesystem');
      return SonyFilesystemValidation.failure(
        errorMessage: 'PRIVATE/M4ROOT folder not found',
        hasDcimFolder: true,
        hasDcfFolder: true,
      );
    }

    final clipPath = await _findCaseInsensitiveDirectory(m4rootPath, 'CLIP');
    if (clipPath == null) {
      _log.debug('Validation failed: CLIP folder not found in $m4rootPath.', tag: 'SonyFilesystem');
      return SonyFilesystemValidation.failure(
        errorMessage: 'PRIVATE/M4ROOT/CLIP folder not found',
        hasDcimFolder: true,
        hasDcfFolder: true,
      );
    }

    _log.info('Sony SD card validation successful: $rootPath.', tag: 'SonyFilesystem');
    return SonyFilesystemValidation.success(dcfFolders: dcfFolders);
  }

  /// ディレクトリの内容を一覧取得（デバッグ用）
  Future<List<String>> _listDirectoryContents(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      return <String>[];
    }

    try {
      final contents = <String>[];
      await for (final entity in dir.list()) {
        final name = p.basename(entity.path);
        final type = entity is Directory ? 'dir' : 'file';
        contents.add('$name ($type)');
      }
      return contents;
    } catch (ex) {
      _log.error(
        'Failed to list directory contents: $dirPath.',
        tag: 'SonyFilesystem',
        error: ex,
      );
      rethrow;
    }
  }

  /// 大文字小文字を区別せずにディレクトリを検索
  Future<String?> _findCaseInsensitiveDirectory(
    String parentPath,
    String targetName,
  ) async {
    final parentDir = Directory(parentPath);
    if (!await parentDir.exists()) {
      return null;
    }

    final targetLower = targetName.toLowerCase();

    try {
      await for (final entity in parentDir.list()) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (name.toLowerCase() == targetLower) {
            return entity.path;
          }
        }
      }
    } catch (ex) {
      // ディレクトリ読み取りエラー（権限不足など）
      _log.error(
        'Failed to list directory: $parentPath (looking for $targetName).',
        tag: 'SonyFilesystem',
        error: ex,
      );
      rethrow;
    }

    return null;
  }

  /// DCF フォルダパターン（3桁番号 + 5文字）に一致するフォルダを検索
  Future<List<String>> _findDcfFolders(String dcimPath) async {
    final folders = <String>[];
    final dcimDir = Directory(dcimPath);
    if (!await dcimDir.exists()) {
      return folders;
    }

    try {
      await for (final entity in dcimDir.list()) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (_dcfFolderPattern.hasMatch(name)) {
            folders.add(entity.path);
          }
        }
      }

      // フォルダ番号順にソート（100MSDCF, 101ALPHA, ...）
      folders.sort((a, b) {
        final aName = p.basename(a).toUpperCase();
        final bName = p.basename(b).toUpperCase();
        return aName.compareTo(bName);
      });
    } catch (ex) {
      _log.error('Failed to read DCIM directory: $dcimPath.', tag: 'SonyFilesystem', error: ex);
      rethrow;
    }

    return folders;
  }

  /// 取り込み対象のメディアファイルをスキャンする
  ///
  /// [settings] に従って取り込み対象ファイルを列挙する。
  /// ファイルはスキャン順序に従ってソートされる:
  /// 1. DCIM/100MSDCF/ → DCIM/101MSDCF/ → ...（番号順）
  /// 2. PRIVATE/M4ROOT/CLIP/
  /// 3. PRIVATE/M4ROOT/SUB/（設定で有効な場合のみ）
  ///
  /// 各フォルダ内はファイル名でソートされる。
  Future<SonyFilesystemScanResult> scanMediaFiles(ImportSettings settings) async {
    final validation = await validate();
    if (!validation.isValid) {
      throw Exception('Invalid Sony SD card structure: ${validation.errorMessage}');
    }

    final mediaFiles = <MediaFile>[];
    final warnings = <ImportWarning>[];

    // 1. DCIM フォルダ内の静止画をスキャン
    final photoFiles = <MediaFile>[];
    for (final dcfPath in validation.dcfFolders) {
      final photos = await _scanPhotosInFolder(
        dcfPath,
        warnings,
        cameraTimezone: settings.cameraTimezone,
        restoreToleranceSeconds: settings.dateRestoreToleranceSeconds,
      );
      photoFiles.addAll(photos);
    }
    mediaFiles.addAll(
      _applyRawExifFallback(
        photoFiles,
        cameraTimezone: settings.cameraTimezone,
        restoreToleranceSeconds: settings.dateRestoreToleranceSeconds,
      ),
    );

    // 2. PRIVATE/M4ROOT/CLIP 内の動画をスキャン
    final clipPath = await _getClipPath();
    if (clipPath != null) {
      final videos = await _scanVideosInFolder(
        clipPath,
        isProxyFolder: false,
        includeXml: settings.isImportVideoXML,
        warnings: warnings,
        cameraTimezone: settings.cameraTimezone,
        restoreToleranceSeconds: settings.dateRestoreToleranceSeconds,
      );
      mediaFiles.addAll(videos);
    }

    // 3. PRIVATE/M4ROOT/SUB 内のプロキシー動画をスキャン（設定で有効な場合）
    if (settings.isImportProxyVideos) {
      final subPath = await _getSubPath();
      if (subPath != null) {
        final proxyVideos = await _scanVideosInFolder(
          subPath,
          isProxyFolder: true,
          includeXml: false, // SUB フォルダの XML は取り込まない
          warnings: warnings,
          cameraTimezone: settings.cameraTimezone,
          restoreToleranceSeconds: settings.dateRestoreToleranceSeconds,
        );
        mediaFiles.addAll(proxyVideos);
      }
    }

    return SonyFilesystemScanResult(
      mediaFiles: mediaFiles,
      warnings: warnings,
    );
  }

  /// CLIP フォルダのパスを取得
  Future<String?> _getClipPath() async {
    final privatePath = await _findCaseInsensitiveDirectory(rootPath, 'PRIVATE');
    if (privatePath == null) return null;

    final m4rootPath = await _findCaseInsensitiveDirectory(privatePath, 'M4ROOT');
    if (m4rootPath == null) return null;

    return _findCaseInsensitiveDirectory(m4rootPath, 'CLIP');
  }

  /// SUB フォルダのパスを取得
  Future<String?> _getSubPath() async {
    final privatePath = await _findCaseInsensitiveDirectory(rootPath, 'PRIVATE');
    if (privatePath == null) return null;

    final m4rootPath = await _findCaseInsensitiveDirectory(privatePath, 'M4ROOT');
    if (m4rootPath == null) return null;

    return _findCaseInsensitiveDirectory(m4rootPath, 'SUB');
  }

  /// RAW ファイルの EXIF を JPEG/HIF から補完する
  ///
  /// RAW に EXIF が無い場合、同一フォルダ内で同じベース名の JPEG/HIF が
  /// 持つ EXIF をフォールバックとして適用する。
  List<MediaFile> _applyRawExifFallback(
    List<MediaFile> photoFiles, {
    required String cameraTimezone,
    required int restoreToleranceSeconds,
  }) {
    final fallbackByKey = <String, ({DateTime local, int? utcMs, bool hasTimezone})>{};

    for (final file in photoFiles) {
      if (file.type == MediaType.JPEGPhoto || file.type == MediaType.HEIFPhoto) {
        if (file.isExifDateTimeValid) {
          fallbackByKey[_buildBaseNameKey(file)] = (
            local: file.exifDateTimeLocal!,
            utcMs: file.exifDateTimeUtcMs,
            hasTimezone: file.hasExifTimezone,
          );
        }
      }
    }

    if (fallbackByKey.isEmpty) {
      return photoFiles;
    }

    return photoFiles.map((file) {
      if (file.type == MediaType.RAWPhoto && !file.isExifDateTimeValid) {
        final fallback = fallbackByKey[_buildBaseNameKey(file)];
        if (fallback != null) {
          return _copyMediaFileWithExifDateTime(
            file,
            fallback.local,
            fallback.utcMs,
            fallback.hasTimezone,
            cameraTimezone,
            restoreToleranceSeconds,
          );
        }
      }
      return file;
    }).toList();
  }

  /// EXIF フォールバックを適用した MediaFile を生成する
  MediaFile _copyMediaFileWithExifDateTime(
    MediaFile file,
    DateTime exifDateTimeLocal,
    int? exifDateTimeUtcMs,
    bool hasExifTimezone,
    String cameraTimezone,
    int restoreToleranceSeconds,
  ) {
    final referenceUtcMs = _getReferenceUtcMs((
      creationTimeUtcMs: file.sourceCreatedTimeUtcMs,
      modifiedTimeUtcMs: file.sourceModifiedTimeUtcMs,
    ));
    final resolvedTimes = _resolveCaptureTimes(
      exifLocalDateTime: exifDateTimeLocal,
      exifUtcMs: exifDateTimeUtcMs,
      hasExifTimezone: hasExifTimezone,
      sourceReferenceUtcMs: referenceUtcMs,
      cameraTimezone: cameraTimezone,
      restoreToleranceSeconds: restoreToleranceSeconds,
    );
    final captureLocalDateTime = _resolveCaptureLocalDateTime(
      exifDateTimeLocal,
      resolvedTimes.captureStartUtcMs,
      cameraTimezone,
    );

    return MediaFile(
      relativePath: file.relativePath,
      fileName: file.fileName,
      baseName: file.baseName,
      extension: file.extension,
      type: file.type,
      fileSize: file.fileSize,
      exifDateTimeLocal: exifDateTimeLocal,
      exifDateTimeUtcMs: exifDateTimeUtcMs,
      hasExifTimezone: hasExifTimezone,
      sourceCreatedTimeUtcMs: file.sourceCreatedTimeUtcMs,
      sourceModifiedTimeUtcMs: file.sourceModifiedTimeUtcMs,
      capturedStartTimeUtcMs: resolvedTimes.captureStartUtcMs,
      capturedEndTimeUtcMs: resolvedTimes.captureStartUtcMs,
      captureLocalDateTime: captureLocalDateTime,
      sdCardRoot: file.sdCardRoot,
      xxHash: file.xxHash,
    );
  }

  /// 撮影日時を確定する
  ({int captureStartUtcMs}) _resolveCaptureTimes({
    required DateTime? exifLocalDateTime,
    required int? exifUtcMs,
    required bool hasExifTimezone,
    required int sourceReferenceUtcMs,
    required String cameraTimezone,
    required int restoreToleranceSeconds,
  }) {
    if (exifLocalDateTime == null) {
      return (captureStartUtcMs: sourceReferenceUtcMs);
    }

    if (hasExifTimezone && exifUtcMs != null) {
      return (captureStartUtcMs: exifUtcMs);
    }

    final cameraOffset = getTimezoneOffsetDuration(cameraTimezone);
    final cameraBasedUtcMs = cameraOffset == null
        ? null
        : _toUtcDateTime(exifLocalDateTime, cameraOffset).millisecondsSinceEpoch;

    if (cameraBasedUtcMs != null &&
        _isWithinTolerance(cameraBasedUtcMs, sourceReferenceUtcMs, restoreToleranceSeconds)) {
      return (captureStartUtcMs: cameraBasedUtcMs);
    }

    final inferredOffset = _inferOffsetFromSource(
      exifLocalDateTime,
      sourceReferenceUtcMs,
      restoreToleranceSeconds,
    );
    if (inferredOffset != null) {
      return (captureStartUtcMs: _toUtcDateTime(exifLocalDateTime, inferredOffset).millisecondsSinceEpoch);
    }

    if (cameraBasedUtcMs != null) {
      return (captureStartUtcMs: cameraBasedUtcMs);
    }

    return (captureStartUtcMs: sourceReferenceUtcMs);
  }

  /// サブフォルダ命名に使用するローカル日時を解決する
  DateTime _resolveCaptureLocalDateTime(
    DateTime? exifLocalDateTime,
    int captureStartUtcMs,
    String cameraTimezone,
  ) {
    if (exifLocalDateTime != null) {
      return exifLocalDateTime;
    }

    final cameraOffset = getTimezoneOffsetDuration(cameraTimezone);
    if (cameraOffset != null) {
      return DateTime.fromMillisecondsSinceEpoch(captureStartUtcMs, isUtc: true).add(cameraOffset);
    }

    return DateTime.fromMillisecondsSinceEpoch(captureStartUtcMs, isUtc: true).toLocal();
  }

  /// 撮影終了日時を計算する
  int _resolveCaptureEndUtcMs({
    required int capturedStartUtcMs,
    required int? durationFrames,
    required double? frameRate,
  }) {
    if (durationFrames == null || frameRate == null || frameRate <= 0) {
      return capturedStartUtcMs;
    }

    final durationSeconds = durationFrames / frameRate;
    final durationMs = (durationSeconds * 1000).round();
    return capturedStartUtcMs + durationMs;
  }

  /// 取り込み元ファイルの作成・更新時刻を取得する
  Future<({int creationTimeUtcMs, int modifiedTimeUtcMs})> _getSourceFileTimes(
    File file,
  ) async {
    return getFileTimes(file.path);
  }

  /// 作成日時と更新日時のうち古い方を取得する
  int _getReferenceUtcMs(
    ({int creationTimeUtcMs, int modifiedTimeUtcMs}) sourceTimes,
  ) {
    return sourceTimes.creationTimeUtcMs <= sourceTimes.modifiedTimeUtcMs
        ? sourceTimes.creationTimeUtcMs
        : sourceTimes.modifiedTimeUtcMs;
  }

  /// 許容誤差内かどうかを判定する
  bool _isWithinTolerance(
    int candidateUtcMs,
    int referenceUtcMs,
    int restoreToleranceSeconds,
  ) {
    final diffSeconds = (candidateUtcMs - referenceUtcMs).abs() / Duration.millisecondsPerSecond;
    return diffSeconds <= restoreToleranceSeconds;
  }

  /// ファイル時刻からタイムゾーンを推測する
  Duration? _inferOffsetFromSource(
    DateTime exifLocalDateTime,
    int sourceReferenceUtcMs,
    int restoreToleranceSeconds,
  ) {
    const inferenceUnitMinutes = 30;
    const maxOffsetHours = 18;

    final inferredOffset = _calculateOffsetFromSource(
      exifLocalDateTime,
      sourceReferenceUtcMs,
    );
    if (inferredOffset == null) {
      return null;
    }

    if (inferredOffset.inMinutes.abs() > maxOffsetHours * 60) {
      return null;
    }

    final remainder = inferredOffset.inMinutes.abs() % inferenceUnitMinutes;
    if (remainder != 0) {
      return null;
    }

    if (inferredOffset.inSeconds.abs() <= restoreToleranceSeconds) {
      return null;
    }

    return inferredOffset;
  }

  /// ファイル時刻から推測されるタイムゾーンオフセットを計算する
  Duration? _calculateOffsetFromSource(
    DateTime exifLocalDateTime,
    int sourceReferenceUtcMs,
  ) {
    final exifFloatingUtc = DateTime.utc(
      exifLocalDateTime.year,
      exifLocalDateTime.month,
      exifLocalDateTime.day,
      exifLocalDateTime.hour,
      exifLocalDateTime.minute,
      exifLocalDateTime.second,
      exifLocalDateTime.millisecond,
      exifLocalDateTime.microsecond,
    );

    final sourceReferenceUtc = DateTime.fromMillisecondsSinceEpoch(
      sourceReferenceUtcMs,
      isUtc: true,
    );

    return exifFloatingUtc.difference(sourceReferenceUtc);
  }

  /// ローカル時刻とオフセットから UTC を算出する
  DateTime _toUtcDateTime(DateTime localDateTime, Duration offset) {
    return DateTime.utc(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
      localDateTime.hour,
      localDateTime.minute,
      localDateTime.second,
      localDateTime.millisecond,
      localDateTime.microsecond,
    ).subtract(offset);
  }

  /// フォルダ単位でベース名の一致判定に使うキーを生成する
  String _buildBaseNameKey(MediaFile file) {
    final directory = p.dirname(file.relativePath);
    return '$directory|${file.baseName}';
  }

  /// フォルダ内の静止画をスキャン
  Future<List<MediaFile>> _scanPhotosInFolder(
    String folderPath,
    List<ImportWarning> warnings, {
    required String cameraTimezone,
    required int restoreToleranceSeconds,
  }) async {
    final files = <MediaFile>[];
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      throw FileSystemException('Photo folder not found.', folderPath);
    }

    try {
      final entities = await dir.list().toList();

      // ファイル名でソート
      entities.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      _log.debug(
        'Scanning photo folder: $folderPath (${entities.length} entries).',
        tag: 'SonyFilesystem',
      );

      int processedCount = 0;
      const int progressLogInterval = 50;

      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);

          // OS 生成ファイルをスキップ
          if (isOsGeneratedFile(fileName)) continue;

          final ext = getExtension(fileName).toLowerCase();
          if (_photoExtensions.contains(ext)) {
            final mediaFile = await _createMediaFile(
              entity,
              isProxyFolder: false,
              cameraTimezone: cameraTimezone,
              restoreToleranceSeconds: restoreToleranceSeconds,
            );
            if (mediaFile != null) {
              files.add(mediaFile);
            }
          } else if (ext.isNotEmpty) {
            await _addUnknownExtensionWarning(
              entity,
              warnings,
              cameraTimezone,
            );
          }

          processedCount += 1;
          if (processedCount % progressLogInterval == 0) {
            _log.debug(
              'Photo scan progress: $processedCount/${entities.length} in $folderPath (last: $fileName).',
              tag: 'SonyFilesystem',
            );
            await Future<void>.delayed(Duration.zero);
          }
        }
      }
      _log.debug(
        'Photo scan completed: $folderPath (${files.length} files).',
        tag: 'SonyFilesystem',
      );
    } catch (ex) {
      _log.error(
        'Failed to scan photo folder: $folderPath.',
        tag: 'SonyFilesystem',
        error: ex,
      );
      rethrow;
    }

    return files;
  }

  /// フォルダ内の動画をスキャン
  Future<List<MediaFile>> _scanVideosInFolder(
    String folderPath, {
    required bool isProxyFolder,
    required bool includeXml,
    required List<ImportWarning> warnings,
    required String cameraTimezone,
    required int restoreToleranceSeconds,
  }) async {
    final files = <MediaFile>[];
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      throw FileSystemException('Video folder not found.', folderPath);
    }

    try {
      final entities = await dir.list().toList();

      // ファイル名でソート
      entities.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      _log.debug(
        'Scanning video folder: $folderPath (${entities.length} entries).',
        tag: 'SonyFilesystem',
      );

      int processedCount = 0;
      const int progressLogInterval = 50;

      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);

          // OS 生成ファイルをスキップ
          if (isOsGeneratedFile(fileName)) continue;

          final ext = getExtension(fileName).toLowerCase();

          // 動画ファイル
          if (_videoExtensions.contains(ext)) {
            final mediaFile = await _createMediaFile(
              entity,
              isProxyFolder: isProxyFolder,
              cameraTimezone: cameraTimezone,
              restoreToleranceSeconds: restoreToleranceSeconds,
            );
            if (mediaFile != null) {
              files.add(mediaFile);
            }
          }
          // XML ファイル（設定で有効な場合のみ）
          else if (includeXml && _metaExtensions.contains(ext)) {
            final mediaFile = await _createMediaFile(
              entity,
              isProxyFolder: false,
              cameraTimezone: cameraTimezone,
              restoreToleranceSeconds: restoreToleranceSeconds,
            );
            if (mediaFile != null) {
              files.add(mediaFile);
            }
          } else if (!_metaExtensions.contains(ext) && ext.isNotEmpty) {
            await _addUnknownExtensionWarning(
              entity,
              warnings,
              cameraTimezone,
            );
          }

          processedCount += 1;
          if (processedCount % progressLogInterval == 0) {
            _log.debug(
              'Video scan progress: $processedCount/${entities.length} in $folderPath (last: $fileName).',
              tag: 'SonyFilesystem',
            );
            await Future<void>.delayed(Duration.zero);
          }
        }
      }
      _log.debug(
        'Video scan completed: $folderPath (${files.length} files).',
        tag: 'SonyFilesystem',
      );
    } catch (ex) {
      _log.error(
        'Failed to scan video folder: $folderPath.',
        tag: 'SonyFilesystem',
        error: ex,
      );
      rethrow;
    }

    return files;
  }

  /// 未知の拡張子を警告として追加
  Future<void> _addUnknownExtensionWarning(
    File file,
    List<ImportWarning> warnings,
    String cameraTimezone,
  ) async {
    try {
      final fileName = p.basename(file.path);
      final extension = getExtension(fileName).toLowerCase();
      final baseName = getBaseName(fileName);
      final stat = await file.stat();
      final sourceTimes = await _getSourceFileTimes(file);
      final relativePath = _getRelativePath(file.path);
      final referenceUtcMs = _getReferenceUtcMs(sourceTimes);
      final captureLocalDateTime = _resolveCaptureLocalDateTime(
        null,
        referenceUtcMs,
        cameraTimezone,
      );

      final mediaFile = MediaFile(
        relativePath: relativePath,
        fileName: fileName,
        baseName: baseName,
        extension: extension,
        type: MediaType.Unknown,
        fileSize: stat.size,
        exifDateTimeLocal: null,
        exifDateTimeUtcMs: null,
        hasExifTimezone: false,
        sourceCreatedTimeUtcMs: sourceTimes.creationTimeUtcMs,
        sourceModifiedTimeUtcMs: sourceTimes.modifiedTimeUtcMs,
        capturedStartTimeUtcMs: referenceUtcMs,
        capturedEndTimeUtcMs: referenceUtcMs,
        captureLocalDateTime: captureLocalDateTime,
        sdCardRoot: rootPath,
      );

      warnings.add(
        ImportWarning(
          type: ImportWarningType.UnknownExtensionFound,
          file: mediaFile,
          message: 'Unknown file extension: $extension.',
        ),
      );
    } catch (ex) {
      _log.warning(
        'Failed to add unknown extension warning for: ${file.path}.',
        tag: 'SonyFilesystem',
        error: ex,
      );
      if (ex is FileSystemException || ex is UnsupportedError) {
        rethrow;
      }
      // 未知ファイルの警告追加に失敗した場合は無視する
    }
  }

  /// MediaFile オブジェクトを作成
  Future<MediaFile?> _createMediaFile(
    File file, {
    required bool isProxyFolder,
    required String cameraTimezone,
    required int restoreToleranceSeconds,
  }) async {
    final filePath = file.path;
    final stopwatch = Stopwatch()..start();
    final statStopwatch = Stopwatch();
    final fileTimesStopwatch = Stopwatch();
    Stopwatch? exifStopwatch;
    try {
      final fileName = p.basename(filePath);
      final ext = getExtension(fileName);
      final baseName = getBaseName(fileName);

      // メディアタイプを判定
      final mediaType = MediaTypeExtension.fromExtension(ext, isProxyFolder: isProxyFolder);
      if (mediaType == null) return null;

      // ファイル情報を取得
      statStopwatch.start();
      final stat = await file.stat();
      statStopwatch.stop();
      fileTimesStopwatch.start();
      final sourceTimes = await _getSourceFileTimes(file);
      fileTimesStopwatch.stop();
      final referenceUtcMs = _getReferenceUtcMs(sourceTimes);
      final relativePath = _getRelativePath(file.path);

      // EXIF/メタデータから日時を取得
      DateTime? exifDateTimeLocal;
      int? exifDateTimeUtcMs;
      bool hasExifTimezone = false;
      int? durationFrames;
      double? frameRate;

      if (mediaType.isPhoto) {
        exifStopwatch = Stopwatch()..start();
        final exifData = await readExifDateTime(
          file,
          cameraTimezone: cameraTimezone,
        );
        exifStopwatch.stop();
        exifDateTimeLocal = exifData.bestLocalDateTime;
        exifDateTimeUtcMs = exifData.bestUtcDateTime?.millisecondsSinceEpoch;
        hasExifTimezone = exifData.hasTimezoneOffset;
      } else if (mediaType == MediaType.Video) {
        exifStopwatch = Stopwatch()..start();
        final videoDateTime = await readVideoDateTime(
          file,
          cameraTimezone: cameraTimezone,
        );
        exifStopwatch.stop();
        exifDateTimeLocal = videoDateTime?.localDateTime;
        exifDateTimeUtcMs = videoDateTime?.utcDateTime?.millisecondsSinceEpoch;
        hasExifTimezone = videoDateTime?.hasTimezoneOffset ?? false;
        durationFrames = videoDateTime?.durationFrames;
        frameRate = videoDateTime?.frameRate;
      }

      final resolvedTimes = _resolveCaptureTimes(
        exifLocalDateTime: exifDateTimeLocal,
        exifUtcMs: exifDateTimeUtcMs,
        hasExifTimezone: hasExifTimezone,
        sourceReferenceUtcMs: referenceUtcMs,
        cameraTimezone: cameraTimezone,
        restoreToleranceSeconds: restoreToleranceSeconds,
      );

      final capturedStartUtcMs = resolvedTimes.captureStartUtcMs;
      final captureLocalDateTime = _resolveCaptureLocalDateTime(
        exifDateTimeLocal,
        capturedStartUtcMs,
        cameraTimezone,
      );
      final capturedEndUtcMs = _resolveCaptureEndUtcMs(
        capturedStartUtcMs: capturedStartUtcMs,
        durationFrames: durationFrames,
        frameRate: frameRate,
      );

      return MediaFile(
        relativePath: relativePath,
        fileName: fileName,
        baseName: baseName,
        extension: ext,
        type: mediaType,
        fileSize: stat.size,
        exifDateTimeLocal: exifDateTimeLocal,
        exifDateTimeUtcMs: exifDateTimeUtcMs,
        hasExifTimezone: hasExifTimezone,
        sourceCreatedTimeUtcMs: sourceTimes.creationTimeUtcMs,
        sourceModifiedTimeUtcMs: sourceTimes.modifiedTimeUtcMs,
        capturedStartTimeUtcMs: capturedStartUtcMs,
        capturedEndTimeUtcMs: capturedEndUtcMs,
        captureLocalDateTime: captureLocalDateTime,
        sdCardRoot: rootPath,
      );
    } catch (ex) {
      _log.warning(
        'Failed to create MediaFile for $filePath. Reason: $ex.',
        tag: 'SonyFilesystem',
        error: ex,
      );
      if (ex is FileSystemException || ex is UnsupportedError) {
        rethrow;
      }
      return null;
    } finally {
      stopwatch.stop();
      final shouldLogDuration = stopwatch.elapsedMilliseconds >= 1000;
      if (shouldLogDuration) {
        final statMs = statStopwatch.elapsedMilliseconds;
        final fileTimesMs = fileTimesStopwatch.elapsedMilliseconds;
        final exifMs = exifStopwatch?.elapsedMilliseconds ?? 0;
        _log.debug(
          'MediaFile creation took ${stopwatch.elapsedMilliseconds}ms '
          '(stat=${statMs}ms, fileTimes=${fileTimesMs}ms, exif=${exifMs}ms) '
          'for $filePath.',
          tag: 'SonyFilesystem',
        );
      }
    }
  }

  /// ルートパスからの相対パスを取得
  String _getRelativePath(String absolutePath) {
    // パスの正規化と相対パス計算
    final normalized = p.normalize(absolutePath);
    final rootNormalized = p.normalize(rootPath);

    if (normalized.startsWith(rootNormalized)) {
      var relative = normalized.substring(rootNormalized.length);
      // 先頭のセパレータを削除
      if (relative.startsWith(p.separator)) {
        relative = relative.substring(1);
      }
      return relative;
    }

    return normalized;
  }

  /// SD カードが書き込み可能かどうかを確認
  ///
  /// PRIVATE/AIU フォルダへの書き込みをテストして判定する。
  Future<bool> isWritable() async {
    try {
      final privatePath = await _findCaseInsensitiveDirectory(rootPath, 'PRIVATE');
      if (privatePath == null) {
        // PRIVATE フォルダがない場合は作成を試みる
        final newPrivatePath = p.join(rootPath, 'PRIVATE');
        await Directory(newPrivatePath).create();
        await Directory(newPrivatePath).delete();
        return true;
      }

      // AIU フォルダの作成をテスト
      final aiuPath = p.join(privatePath, 'AIU');
      final testFilePath = p.join(aiuPath, '.write_test');

      await Directory(aiuPath).create(recursive: true);
      final testFile = File(testFilePath);
      await testFile.writeAsString('test');
      await testFile.delete();

      return true;
    } catch (_) {
      return false;
    }
  }
}
