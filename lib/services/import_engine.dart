/// 取り込みエンジン
///
/// メディアファイルの取り込み処理を実行するコアロジック。
/// ファイルのコピー、ハッシュ検証、日時復元、メタデータ更新を行う。
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/media_file.dart';
import '../models/settings.dart';
import '../models/import_result.dart';
import '../utils/hash_utils.dart';
import '../utils/file_utils.dart';
import 'sony_filesystem.dart';
import 'metadata_manager.dart';
import 'logging_service.dart';

/// アプリバージョン（メタデータ記録用）
const String _appVersion = '1.0.0';

/// ハッシュ検証失敗時の最大リトライ回数
const int _maxCopyRetries = 3;

/// 取り込みエンジン
///
/// SD カードからのメディアファイル取り込みを制御する。
/// 進捗通知、キャンセル対応、エラーハンドリングを提供する。
class ImportEngine {
  /// SD カードのルートパス
  final String sdCardRoot;

  /// 取り込み設定
  final ImportSettings settings;

  /// Sony ファイルシステムサービス
  late final SonyFilesystemService _sonyFs;

  /// メタデータマネージャ
  late final MetadataManager _metadataManager;

  /// ロガー
  final _log = LoggingService.instance;

  /// キャンセルフラグ
  bool _isCancelled = false;

  /// 進捗通知コールバック
  void Function(ImportProgress progress)? onProgress;

  ImportEngine({
    required this.sdCardRoot,
    required this.settings,
  }) {
    _sonyFs = SonyFilesystemService(sdCardRoot);
    _metadataManager = MetadataManager(sdCardRoot);
    _log.debug('ImportEngine initialized for $sdCardRoot.', tag: 'ImportEngine');
  }

  /// 取り込み処理をキャンセルする
  ///
  /// 現在処理中のファイルが完了した後に停止する。
  void cancel() {
    _log.info('Import cancelled by user.', tag: 'ImportEngine');
    _isCancelled = true;
  }

  /// 取り込み処理を実行する
  ///
  /// 以下の手順で処理を行う:
  /// 1. SD カード構造の検証
  /// 2. 書き込み可能性の確認
  /// 3. 対象ファイルのスキャン
  /// 4. 容量チェック
  /// 5. 各ファイルの取り込み処理
  /// 6. 結果の返却
  Future<ImportResult> execute() async {
    _log.logImportStarted(sdCardRoot, 0);
    final stopwatch = Stopwatch()..start();
    final warnings = <ImportWarning>[];
    final importedFiles = <ImportedFileRecord>[];
    int successCount = 0;
    int skippedCount = 0;

    try {
      // Phase 1: SD カード構造の検証
      _log.debug('Phase 1: Validating SD card structure.', tag: 'ImportEngine');
      _notifyProgress(ImportProgress.initial());

      final validation = await _sonyFs.validate();
      if (!validation.isValid) {
        _log.error('SD card validation failed: ${validation.errorMessage}', tag: 'ImportEngine');
        return ImportResult.error(
          errorMessage: 'Sony SD card structure validation failed: ${validation.errorMessage}',
        );
      }

      // Phase 2: 書き込み可能性の確認
      _log.debug('Phase 2: Checking write permission.', tag: 'ImportEngine');
      final isWritable = await _metadataManager.isWritable();
      if (!isWritable) {
        _log.error('SD card is not writable.', tag: 'ImportEngine');
        return ImportResult.error(
          errorMessage: 'SD card is not writable. Cannot save import metadata.',
        );
      }

      // Phase 3: 対象ファイルのスキャン
      _log.debug('Phase 3: Scanning media files.', tag: 'ImportEngine');
      final mediaFiles = await _sonyFs.scanMediaFiles(settings);
      _log.info('Found ${mediaFiles.length} media files to import.', tag: 'ImportEngine');

      if (mediaFiles.isEmpty) {
        _log.info('No files to import.', tag: 'ImportEngine');
        return ImportResult(
          successCount: 0,
          skippedCount: 0,
          warningCount: 0,
          errorCount: 0,
          warnings: [],
          importedFiles: [],
          duration: stopwatch.elapsed,
        );
      }

      // Phase 4: 容量チェック
      _log.debug('Phase 4: Checking disk space.', tag: 'ImportEngine');
      final totalSize = mediaFiles.fold<int>(0, (sum, f) => sum + f.fileSize);
      final availableSpace = await getAvailableDiskSpace(settings.destinationFolder);
      _log.debug(
        'Required: ${formatFileSize(totalSize)}, Available: ${availableSpace != null ? formatFileSize(availableSpace) : "unknown"}.',
        tag: 'ImportEngine',
      );

      if (availableSpace != null && availableSpace < totalSize) {
        _log.error('Insufficient disk space.', tag: 'ImportEngine');
        return ImportResult.error(
          errorMessage:
              'Insufficient disk space. Required: ${formatFileSize(totalSize)}, Available: ${formatFileSize(availableSpace)}',
        );
      }

      // 保存先フォルダを作成
      await ensureDirectoryExists(settings.destinationFolder);

      // Phase 5: 各ファイルの取り込み処理
      _log.debug('Phase 5: Starting file import.', tag: 'ImportEngine');
      _notifyProgress(
        ImportProgress(
          processedCount: 0,
          totalCount: mediaFiles.length,
          phase: 'Importing...',
        ),
      );

      for (var index = 0; index < mediaFiles.length; index++) {
        // キャンセルチェック
        if (_isCancelled) {
          return ImportResult.cancelled(
            successCount: successCount,
            skippedCount: skippedCount,
            warnings: warnings,
            importedFiles: importedFiles,
            duration: stopwatch.elapsed,
          );
        }

        final mediaFile = mediaFiles[index];

        // 進捗通知
        _notifyProgress(
          ImportProgress(
            currentFile: mediaFile,
            processedCount: index,
            totalCount: mediaFiles.length,
            phase: 'Importing...',
          ).startFile(mediaFile),
        );

        // 取り込み判定と処理
        final result = await _processFile(mediaFile, warnings);

        switch (result) {
          case _FileProcessResult.imported:
            successCount++;
            // メタデータに追加
            if (mediaFile.xxHash != null) {
              final record = ImportedFileRecord(
                sourcePath: mediaFile.relativePath,
                xxHash: mediaFile.xxHash!,
                fileSize: mediaFile.fileSize,
                importedAt: DateTime.now().toUtc(),
                destinationPath: _lastDestinationPath ?? '',
                appVersion: _appVersion,
              );
              await _metadataManager.addRecord(record);
              importedFiles.add(record);
            }
            break;
          case _FileProcessResult.skipped:
            skippedCount++;
            break;
          case _FileProcessResult.error:
            // エラーは警告として記録済み
            break;
        }

        // ファイル完了の進捗通知
        _notifyProgress(
          ImportProgress(
            processedCount: index + 1,
            totalCount: mediaFiles.length,
            phase: 'Importing...',
          ),
        );
      }

      stopwatch.stop();

      _log.logImportCompleted(successCount, skippedCount, warnings.length, stopwatch.elapsed);

      return ImportResult(
        successCount: successCount,
        skippedCount: skippedCount,
        warningCount: warnings.length,
        errorCount: 0,
        warnings: warnings,
        importedFiles: importedFiles,
        duration: stopwatch.elapsed,
      );
    } catch (ex, stackTrace) {
      stopwatch.stop();
      _log.error('Import failed.', tag: 'ImportEngine', error: ex, stackTrace: stackTrace);
      return ImportResult.error(
        errorMessage: 'Import failed: $ex',
        successCount: successCount,
        skippedCount: skippedCount,
        warnings: warnings,
        importedFiles: importedFiles,
        duration: stopwatch.elapsed,
      );
    }
  }

  /// 最後にコピーしたファイルの保存先パス（メタデータ記録用）
  String? _lastDestinationPath;

  /// 進捗を通知
  void _notifyProgress(ImportProgress progress) {
    if (onProgress != null) {
      onProgress!(progress);
    }
  }

  /// 単一ファイルの取り込み処理
  Future<_FileProcessResult> _processFile(
    MediaFile file,
    List<ImportWarning> warnings,
  ) async {
    try {
      // 書き込み中ファイルのチェック
      final sourceFile = File(file.absolutePath);
      if (await isFileBeingWritten(sourceFile)) {
        warnings.add(
          ImportWarning(
            type: ImportWarningType.FileInUseSkipped,
            file: file,
            message: 'File appears to be in use, skipping',
          ),
        );
        return _FileProcessResult.skipped;
      }

      // 取り込み済みかどうかを確認
      final existingRecord = await _metadataManager.findRecord(file.relativePath);

      if (existingRecord != null) {
        // メタデータに記録がある場合
        final destPath = p.join(settings.destinationFolder, existingRecord.destinationPath);
        final destFile = File(destPath);

        if (await destFile.exists()) {
          // コピー先にファイルが存在する → スキップ
          return _FileProcessResult.skipped;
        } else {
          // コピー先にファイルがない → PC 側で削除されたので再取り込み
          // 記録は上書きされる
        }
      } else {
        // メタデータに記録がない場合
        // コピー先に同名ファイルがあるかチェック
        final destFolder = _getDestinationFolder(file);
        final destPath = p.join(destFolder, file.fileName);
        final destFile = File(destPath);

        if (await destFile.exists()) {
          // 同名ファイルが存在 → ハッシュ比較
          file.xxHash ??= await computeFileHash(sourceFile);
          final destHash = await computeFileHash(destFile);

          if (hashesMatch(file.xxHash!, destHash)) {
            // 同一ファイル → スキップ
            return _FileProcessResult.skipped;
          } else {
            // 別内容 → 別名で取り込み
            // ファイル名は _copyFileWithHash 内で生成される
          }
        }
      }

      // ファイルをコピー
      await _copyFileWithHash(file, warnings);

      return _FileProcessResult.imported;
    } catch (ex) {
      warnings.add(
        ImportWarning(
          type: ImportWarningType.HashVerificationFailed,
          file: file,
          message: 'Failed to process file: $ex',
        ),
      );
      return _FileProcessResult.error;
    }
  }

  /// 取り込み先フォルダパスを取得
  String _getDestinationFolder(MediaFile file) {
    final subfolderPath = settings.generateSubfolderPath(file.effectiveDateTime);
    return p.join(settings.destinationFolder, subfolderPath);
  }

  /// ファイルをコピーしてハッシュを計算
  Future<void> _copyFileWithHash(
    MediaFile file,
    List<ImportWarning> warnings,
  ) async {
    final sourceFile = File(file.absolutePath);
    final destFolder = _getDestinationFolder(file);

    // 保存先フォルダを作成
    await ensureDirectoryExists(destFolder);

    // ファイル名を決定（重複時はサフィックス付与）
    var destFileName = file.fileName;

    // プロキシ動画の場合、ファイル名が本編と衝突する可能性があるか確認
    if (file.type == MediaType.ProxyVideo) {
      final mainVideoPath = p.join(destFolder, file.fileName);
      if (await File(mainVideoPath).exists()) {
        // 衝突する場合は _proxy サフィックスを付与
        destFileName = '${file.baseName}_proxy${file.extension}';
      }
    }

    // 既存ファイルとの重複チェック
    destFileName = await generateUniqueFileName(Directory(destFolder), destFileName);

    // 元のファイル名と異なる場合は警告を記録
    if (destFileName != file.fileName && !(file.type == MediaType.ProxyVideo && destFileName.contains('_proxy'))) {
      warnings.add(
        ImportWarning(
          type: ImportWarningType.DuplicateRenamed,
          file: file,
          message: 'Renamed to $destFileName due to existing file',
        ),
      );
    }

    final destPath = p.join(destFolder, destFileName);
    final destFile = File(destPath);

    // リトライループ
    for (var attempt = 1; attempt <= _maxCopyRetries; attempt++) {
      try {
        // ストリーミングコピー + ハッシュ計算
        final copier = StreamingCopyWithHash(
          source: sourceFile,
          destination: destFile,
          onProgress: (bytesCopied) {
            // ファイルコピーの進捗（現在は使用していないが、将来的に使用可能）
          },
        );

        final sourceHash = await copier.execute();
        file.xxHash = sourceHash;

        // コピー後のハッシュ検証
        final destHash = await computeFileHash(destFile);

        if (!hashesMatch(sourceHash, destHash)) {
          if (attempt < _maxCopyRetries) {
            // リトライ - コピー先を削除して再試行
            await destFile.delete();
            continue;
          } else {
            // 最大リトライ回数に達した
            warnings.add(
              ImportWarning(
                type: ImportWarningType.HashVerificationFailed,
                file: file,
                message: 'Hash verification failed after $attempt attempts',
              ),
            );
            await destFile.delete();
            throw Exception('Hash verification failed');
          }
        }

        // 日時復元
        if (settings.isRestoreDateTimeFromExif) {
          try {
            await restoreFileDateTime(destFile, file.effectiveDateTime);
          } catch (_) {
            warnings.add(
              ImportWarning(
                type: ImportWarningType.DateRestoreFailed,
                file: file,
                message: 'Failed to restore file datetime',
              ),
            );
          }
        }

        // 相対パスを記録
        final relativeDestPath = settings.generateSubfolderPath(file.effectiveDateTime);
        _lastDestinationPath = p.join(relativeDestPath, destFileName);

        // 成功
        _log.logFileCopied(file.relativePath, destPath);
        return;
      } catch (ex) {
        if (attempt >= _maxCopyRetries) {
          rethrow;
        }
        // リトライ
      }
    }
  }
}

/// ファイル処理結果
enum _FileProcessResult {
  imported,
  skipped,
  error,
}
