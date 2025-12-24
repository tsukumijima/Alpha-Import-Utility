/// 取り込みエンジン
///
/// メディアファイルの取り込み処理を実行するコアロジック。
/// ファイルのコピー、ハッシュ検証、日時復元、メタデータ更新を行う。
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/import_result.dart';
import '../models/media_file.dart';
import '../models/settings.dart';
import '../utils/file_utils.dart';
import '../utils/hash_utils.dart';
import 'logging_service.dart';
import 'metadata_manager.dart';
import 'sony_filesystem.dart';

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
    final stopwatch = Stopwatch()..start();
    final warnings = <ImportWarning>[];
    final importedFiles = <ImportedFileRecord>[];
    int successCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

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
      final scanResult = await _sonyFs.scanMediaFiles(settings);
      final mediaFiles = scanResult.mediaFiles;
      warnings.addAll(scanResult.warnings);
      mediaFiles.sort((a, b) {
        final dateCompare = a.effectiveDateTime.compareTo(b.effectiveDateTime);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.relativePath.compareTo(b.relativePath);
      });
      _log.debug('Sorted media files by capture datetime.', tag: 'ImportEngine');
      _log.info('Found ${mediaFiles.length} media files to import.', tag: 'ImportEngine');

      _log.logImportStarted(sdCardRoot, mediaFiles.length);

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
      var progress = ImportProgress(
        processedCount: 0,
        totalCount: mediaFiles.length,
        phase: 'Importing...',
      );
      _notifyProgress(progress);

      for (final mediaFile in mediaFiles) {
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

        // 進捗通知
        progress = progress.startFile(mediaFile);
        _notifyProgress(progress);

        // 取り込み判定と処理
        final result = await _processFile(
          mediaFile,
          warnings,
          onCopyProgress: (bytesCopied) {
            progress = progress.updateFileProgress(bytesCopied);
            _notifyProgress(progress);
          },
        );

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
              try {
                await _metadataManager.addRecord(record);
              } catch (ex, stackTrace) {
                _log.error(
                  'Failed to update metadata file, aborting import.',
                  tag: 'ImportEngine',
                  error: ex,
                  stackTrace: stackTrace,
                );
                throw Exception('Metadata update failed.');
              }
              importedFiles.add(record);
            }
            break;
          case _FileProcessResult.skipped:
            skippedCount++;
            break;
          case _FileProcessResult.error:
            errorCount++;
            break;
        }

        // ファイル完了の進捗通知
        progress = progress.completeFile();
        _notifyProgress(progress);
      }

      stopwatch.stop();

      _log.logImportCompleted(successCount, skippedCount, errorCount, stopwatch.elapsed);

      return ImportResult(
        successCount: successCount,
        skippedCount: skippedCount,
        warningCount: warnings.length,
        errorCount: errorCount,
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
    List<ImportWarning> warnings, {
    void Function(int bytesCopied)? onCopyProgress,
  }) async {
    try {
      // EXIF/メタデータの読み取り失敗を警告として記録
      if (file.type.isPhoto && !file.isExifDateTimeValid) {
        warnings.add(
          ImportWarning(
            type: ImportWarningType.ExifReadFailed,
            file: file,
            message: 'Failed to read EXIF datetime, using file modified time.',
          ),
        );
      } else if (file.type == MediaType.Video && file.exifDateTime == null) {
        warnings.add(
          ImportWarning(
            type: ImportWarningType.ExifReadFailed,
            file: file,
            message: 'Failed to read video XML datetime, using file modified time.',
          ),
        );
      }

      // 書き込み中ファイルのチェック
      final sourceFile = File(file.absolutePath);
      if (await isFileBeingWritten(sourceFile)) {
        warnings.add(
          ImportWarning(
            type: ImportWarningType.FileInUseSkipped,
            file: file,
            message: 'File appears to be in use, skipping.',
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
      await _copyFileWithHash(file, warnings, onCopyProgress: onCopyProgress);

      return _FileProcessResult.imported;
    } on UnsupportedError {
      rethrow;
    } catch (ex) {
      warnings.add(
        ImportWarning(
          type: ImportWarningType.HashVerificationFailed,
          file: file,
          message: 'Failed to process file: $ex.',
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

  /// 日時復元に使用するターゲット日時を解決
  ///
  /// EXIF 日時が有効かつファイル日時との差が許容範囲外の場合のみ EXIF を使用する。
  /// それ以外はファイルシステムの更新日時を優先する。
  DateTime _resolveRestoreDateTime(MediaFile file) {
    if (!file.isExifDateTimeValid) {
      return file.fileModifiedTime;
    }

    final exifDateTime = file.exifDateTime!;
    final diffSeconds = exifDateTime.difference(file.fileModifiedTime).inSeconds.abs();
    if (diffSeconds <= settings.dateRestoreToleranceSeconds) {
      return file.fileModifiedTime;
    }

    return exifDateTime;
  }

  /// ファイルをコピーしてハッシュを計算
  Future<void> _copyFileWithHash(
    MediaFile file,
    List<ImportWarning> warnings, {
    void Function(int bytesCopied)? onCopyProgress,
  }) async {
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
          message: 'Renamed to $destFileName due to existing file.',
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
            if (onCopyProgress != null) {
              onCopyProgress(bytesCopied);
            }
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
                message: 'Hash verification failed after $attempt attempts.',
              ),
            );
            await destFile.delete();
            throw Exception('Hash verification failed');
          }
        }

        // 日時復元
        if (settings.isRestoreDateTimeFromExif) {
          try {
            final targetDateTime = _resolveRestoreDateTime(file);
            await restoreFileDateTime(destFile, targetDateTime);
          } on UnsupportedError {
            rethrow;
          } catch (ex) {
            warnings.add(
              ImportWarning(
                type: ImportWarningType.DateRestoreFailed,
                file: file,
                message: 'Failed to restore file datetime: $ex.',
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
      } on UnsupportedError {
        if (await destFile.exists()) {
          try {
            await destFile.delete();
          } catch (_) {
            // コピー失敗時の残骸削除に失敗しても中断を優先する
          }
        }
        rethrow;
      } catch (ex) {
        if (await destFile.exists()) {
          try {
            await destFile.delete();
          } catch (_) {
            // コピー失敗時の残骸削除に失敗しても再試行を優先する
          }
        }
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
