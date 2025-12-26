/// 取り込みエンジン
///
/// メディアファイルの取り込み処理を実行するコアロジック。
/// ファイルのコピー、ハッシュ計算、日時復元、メタデータ更新を行う。
library;

import 'dart:async';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../models/import_result.dart';
import '../models/media_file.dart';
import '../models/settings.dart';
import '../utils/file_utils.dart';
import '../utils/hash_utils.dart';
import 'logging_service.dart';
import 'metadata_manager.dart';
import 'sony_filesystem.dart';

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

  /// アプリバージョン（メタデータ記録用）
  late final Future<String> _appVersionFuture;

  ImportEngine({
    required this.sdCardRoot,
    required this.settings,
  }) {
    _sonyFs = SonyFilesystemService(sdCardRoot);
    _metadataManager = MetadataManager(sdCardRoot);
    _appVersionFuture = _loadAppVersion();
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
  Future<ImportResult> execute({
    ImportPlan? plan,
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ImportWarning>[];
    final importedFiles = <ImportedFileRecord>[];
    int successCount = 0;
    int skippedCount = 0;
    int errorCount = 0;
    final appVersion = await _appVersionFuture;

    try {
      final importPlan = plan ?? await prepareImportPlan();
      warnings.addAll(importPlan.warnings);
      skippedCount += importPlan.skippedCount;

      final importTargets = importPlan.items;
      _log.logImportStarted(sdCardRoot, importTargets.length);

      if (importTargets.isEmpty) {
        _log.info('No files to import.', tag: 'ImportEngine');
        return ImportResult(
          successCount: 0,
          skippedCount: skippedCount,
          warningCount: warnings.length,
          errorCount: 0,
          warnings: warnings,
          importedFiles: [],
          duration: stopwatch.elapsed,
        );
      }

      // 保存先フォルダを作成
      await ensureDirectoryExists(settings.destinationFolder);

      // Phase 5: 容量チェック
      _log.debug('Phase 5: Checking disk space.', tag: 'ImportEngine');
      final totalSize = importPlan.totalSize;
      final availableSpace = await getAvailableDiskSpace(settings.destinationFolder);
      _log.debug(
        'Required: ${formatFileSize(totalSize)}, Available: ${availableSpace != null ? formatFileSize(availableSpace) : "unknown"}.',
        tag: 'ImportEngine',
      );

      if (availableSpace == null) {
        _log.error('Failed to read disk space for destination folder.', tag: 'ImportEngine');
        throw ImportFatalException(
          '保存先の空き容量を取得できないため取り込みを中断しました。',
        );
      }

      if (availableSpace < totalSize) {
        _log.error('Insufficient disk space.', tag: 'ImportEngine');
        return ImportResult.error(
          errorMessage:
              '保存先の空き容量が不足しているため取り込みを中断しました。必要: ${formatFileSize(totalSize)}、空き: ${formatFileSize(availableSpace)}。',
        );
      }

      // Phase 6: 各ファイルの取り込み処理
      _log.debug('Phase 6: Starting file import.', tag: 'ImportEngine');
      var progress = ImportProgress(
        processedCount: 0,
        totalCount: importTargets.length,
        phase: '取り込み中...',
      );
      _notifyProgress(progress);
      var remainingBytes = totalSize;

      for (final planItem in importTargets) {
        final mediaFile = planItem.file;

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

        if (remainingBytes > 0) {
          final currentAvailableSpace = await getAvailableDiskSpace(settings.destinationFolder);
          if (currentAvailableSpace == null) {
            _log.error('Failed to read disk space during import.', tag: 'ImportEngine');
            stopwatch.stop();
            return ImportResult.error(
              errorMessage: '保存先の空き容量を取得できないため取り込みを中断しました。',
              successCount: successCount,
              skippedCount: skippedCount,
              warnings: warnings,
              importedFiles: importedFiles,
              duration: stopwatch.elapsed,
            );
          }
          if (remainingBytes > currentAvailableSpace) {
            _log.error(
              'Insufficient disk space before copying next file.',
              tag: 'ImportEngine',
            );
            stopwatch.stop();
            return ImportResult.error(
              errorMessage:
                  '保存先の空き容量が不足しているため取り込みを中断しました。必要: ${formatFileSize(remainingBytes)}、空き: ${formatFileSize(currentAvailableSpace)}。',
              successCount: successCount,
              skippedCount: skippedCount,
              warnings: warnings,
              importedFiles: importedFiles,
              duration: stopwatch.elapsed,
            );
          }
        }

        // 進捗通知
        progress = progress.startFile(
          mediaFile,
          destinationPath: planItem.destinationPath,
        );
        _notifyProgress(progress);

        // 取り込み判定と処理
        final result = await _processFile(
          planItem,
          warnings,
          onCopyProgress: (bytesCopied) {
            progress = progress.updateFileProgress(bytesCopied);
            _notifyProgress(progress);
          },
        );

        switch (result) {
          case _FileProcessResult.imported:
            successCount++;
            remainingBytes -= mediaFile.fileSize;
            if (remainingBytes < 0) {
              remainingBytes = 0;
            }
            // メタデータに追加
            if (mediaFile.xxHash != null) {
              if (_lastDestinationPath == null || _lastDestinationPath!.isEmpty) {
                throw ImportFatalException(
                  'コピー先パスを確定できないため取り込みを中断しました。',
                );
              }
              FileLightweightSignature? signature;
              try {
                signature = await computeFileLightweightSignature(File(mediaFile.absolutePath));
              } catch (ex) {
                _log.warning(
                  'Failed to compute lightweight signature for metadata.',
                  tag: 'ImportEngine',
                  error: ex,
                );
              }
              final record = ImportedFileRecord(
                sourcePath: mediaFile.relativePath,
                xxHash: mediaFile.xxHash!,
                sourceCreatedTimeUtcMs: mediaFile.sourceCreatedTimeUtcMs,
                sourceModifiedTimeUtcMs: mediaFile.sourceModifiedTimeUtcMs,
                fileSize: mediaFile.fileSize,
                lightweightSignature: signature,
                importedAt: DateTime.now().toUtc(),
                destinationPath: _lastDestinationPath!,
                appVersion: appVersion,
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
                throw ImportFatalException(
                  'メタデータの更新に失敗したため取り込みを中断しました。',
                  debugMessage: ex.toString(),
                );
              }
              importedFiles.add(record);
            }
            break;
          case _FileProcessResult.skipped:
            skippedCount++;
            remainingBytes -= mediaFile.fileSize;
            if (remainingBytes < 0) {
              remainingBytes = 0;
            }
            break;
          case _FileProcessResult.error:
            errorCount++;
            remainingBytes -= mediaFile.fileSize;
            if (remainingBytes < 0) {
              remainingBytes = 0;
            }
            break;
        }

        // ファイル完了の進捗通知
        progress = progress.completeFile();
        _notifyProgress(progress);
      }

      stopwatch.stop();

      // 取り込み完了時に累計バイト数をリセット
      StreamingCopyWithHash.resetPendingBytes();

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

      // エラー発生時も累計バイト数をリセット
      StreamingCopyWithHash.resetPendingBytes();

      _log.error('Import failed.', tag: 'ImportEngine', error: ex, stackTrace: stackTrace);
      final errorMessage = resolveFatalErrorMessage(ex);
      return ImportResult.error(
        errorMessage: errorMessage,
        successCount: successCount,
        skippedCount: skippedCount,
        warnings: warnings,
        importedFiles: importedFiles,
        duration: stopwatch.elapsed,
      );
    }
  }

  /// 取り込みプランを準備する
  ///
  /// スキャンと取り込み対象の確定までを実行し、プランを返す。
  Future<ImportPlan> prepareImportPlan() async {
    final warnings = <ImportWarning>[];
    final phaseStopwatch = Stopwatch();

    if (_isCancelled) {
      throw ImportCancelledException();
    }

    // Phase 1: SD カード構造の検証
    phaseStopwatch
      ..reset()
      ..start();
    _log.debug('Phase 1: Validating SD card structure.', tag: 'ImportEngine');
    _notifyProgress(ImportProgress.scanning());

    final validation = await _sonyFs.validate();
    if (!validation.isValid) {
      _log.error('SD card validation failed: ${validation.errorMessage}', tag: 'ImportEngine');
      throw ImportFatalException(
        'Sony SD card structure validation failed: ${validation.errorMessage}',
      );
    }

    if (_isCancelled) {
      throw ImportCancelledException();
    }

    _log.debug(
      'Phase 1 completed in ${phaseStopwatch.elapsedMilliseconds}ms.',
      tag: 'ImportEngine',
    );

    // Phase 2: 書き込み可能性の確認
    phaseStopwatch
      ..reset()
      ..start();
    _log.debug('Phase 2: Checking write permission.', tag: 'ImportEngine');
    final isWritable = await _metadataManager.isWritable();
    if (!isWritable) {
      _log.error('SD card is not writable.', tag: 'ImportEngine');
      throw ImportFatalException(
        'SD card is not writable. Cannot save import metadata.',
      );
    }

    if (_isCancelled) {
      throw ImportCancelledException();
    }

    _log.debug(
      'Phase 2 completed in ${phaseStopwatch.elapsedMilliseconds}ms.',
      tag: 'ImportEngine',
    );

    // Phase 3: 対象ファイルのスキャン
    phaseStopwatch
      ..reset()
      ..start();
    _log.debug('Phase 3: Scanning media files.', tag: 'ImportEngine');
    var scanProgress = ImportProgress.scanning();
    _notifyProgress(scanProgress);

    late final SonyFilesystemScanResult scanResult;
    try {
      scanResult = await _sonyFs.scanMediaFiles(
        settings,
        onProgress: (processedCount, currentPath) {
          scanProgress = ImportProgress.scanning(
            processedCount: processedCount,
            scanCurrentPath: currentPath,
          );
          _notifyProgress(scanProgress);
        },
        isCancelled: () => _isCancelled,
      );
    } on SonyFilesystemScanCancelled {
      throw ImportCancelledException();
    }
    final mediaFiles = scanResult.mediaFiles;
    warnings.addAll(scanResult.warnings);
    mediaFiles.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    _log.debug(
      'Sorted media files by relative path.',
      tag: 'ImportEngine',
    );
    _log.info('Found ${mediaFiles.length} media files in SD card.', tag: 'ImportEngine');
    _log.debug(
      'Phase 3 completed in ${phaseStopwatch.elapsedMilliseconds}ms.',
      tag: 'ImportEngine',
    );

    if (_isCancelled) {
      throw ImportCancelledException();
    }

    // Phase 4: 取り込み対象の確定
    phaseStopwatch
      ..reset()
      ..start();
    _log.debug('Phase 4: Determining import targets.', tag: 'ImportEngine');
    if (mediaFiles.isNotEmpty) {
      scanProgress = ImportProgress.preparingTargets(
        processedCount: 0,
        totalCount: mediaFiles.length,
        phase: '取り込み対象を判定中...',
      );
      _notifyProgress(scanProgress);
    }
    final plan = await _buildImportTargets(
      mediaFiles,
      warnings,
      onProgress: (processedCount, totalCount, currentPath, phase) {
        scanProgress = ImportProgress.preparingTargets(
          processedCount: processedCount,
          totalCount: totalCount,
          currentPath: currentPath,
          phase: phase,
        );
        _notifyProgress(scanProgress);
      },
    );
    _log.debug(
      'Phase 4 completed in ${phaseStopwatch.elapsedMilliseconds}ms.',
      tag: 'ImportEngine',
    );

    if (_isCancelled) {
      throw ImportCancelledException();
    }

    return ImportPlan(
      items: plan.items,
      totalSize: plan.totalSize,
      skippedCount: plan.skippedCount,
      warnings: warnings,
    );
  }

  /// 最後にコピーしたファイルの保存先パス（メタデータ記録用）
  String? _lastDestinationPath;

  /// 進捗を通知
  void _notifyProgress(ImportProgress progress) {
    if (onProgress != null) {
      onProgress!(progress);
    }
  }

  /// アプリバージョンを取得する
  ///
  /// 取得に失敗した場合は 'unknown' を返す。
  Future<String> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        return info.version;
      }
    } catch (ex) {
      _log.warning(
        'Failed to load app version, using fallback.',
        tag: 'ImportEngine',
        error: ex,
      );
    }
    return 'unknown';
  }

  /// 取り込み対象のファイルを確定する
  ///
  /// 既に取り込み済みのファイルを除外し、取り込み対象の合計サイズも算出する。
  Future<({List<ImportPlanItem> items, int totalSize, int skippedCount})> _buildImportTargets(
    List<MediaFile> mediaFiles,
    List<ImportWarning> warnings, {
    void Function(int processedCount, int totalCount, String? currentPath, String phase)? onProgress,
  }) async {
    final items = <ImportPlanItem>[];
    var totalSize = 0;
    var skippedCount = 0;
    final appVersion = await _appVersionFuture;
    final candidates = <({MediaFile file, bool needsDestinationCheck})>[];
    final metadata = await _metadataManager.load();
    final recordBySourcePath = {
      for (final record in metadata.files) normalizeSourcePathForLookup(record.sourcePath): record,
    };
    final signatureCache = <String, FileLightweightSignature>{};
    final destinationFolderIndex = _DestinationFolderIndex(_log);
    final updatedRecords = <ImportedFileRecord>[];
    final scannedPaths = mediaFiles.map((file) => normalizeSourcePathForLookup(file.relativePath)).toSet();
    const int progressLogInterval = 200;
    const int progressUiInterval = 1;
    final totalFiles = mediaFiles.length;
    var processedCount = 0;

    final recordsToRemove = <String>{};
    for (final record in metadata.files) {
      final normalizedRecordPath = normalizeSourcePathForLookup(record.sourcePath);
      if (_isSourcePathInScanScope(record.sourcePath) && !scannedPaths.contains(normalizedRecordPath)) {
        recordsToRemove.add(record.sourcePath);
      }
    }

    // 既存レコードの保存先フォルダは先にスナップショットを作成して I/O を削減する
    final destinationFoldersForRecords = <String>{};
    for (final file in mediaFiles) {
      final normalizedSourcePath = normalizeSourcePathForLookup(file.relativePath);
      final existingRecord = recordBySourcePath[normalizedSourcePath];
      if (existingRecord == null) {
        continue;
      }
      final normalizedDestinationPath = existingRecord.destinationPath.replaceAll('\\', '/');
      final destinationFolderPath = p.posix.dirname(normalizedDestinationPath);
      final destinationFolder = destinationFolderPath == '.'
          ? settings.destinationFolder
          : p.join(settings.destinationFolder, destinationFolderPath);
      destinationFoldersForRecords.add(destinationFolder);
    }
    await destinationFolderIndex.prewarm(destinationFoldersForRecords);

    for (final file in mediaFiles) {
      if (_isCancelled) {
        throw ImportCancelledException();
      }
      processedCount++;
      final shouldReportUi = processedCount % progressUiInterval == 0 || processedCount == totalFiles;
      final shouldReportLog = processedCount % progressLogInterval == 0 || processedCount == totalFiles;
      if (onProgress != null && shouldReportUi) {
        onProgress(
          processedCount,
          totalFiles,
          file.relativePath,
          '取り込み対象を判定中...',
        );
      }
      if (shouldReportLog) {
        _log.debug(
          'Import target scan progress: $processedCount/$totalFiles (last: ${file.relativePath}).',
          tag: 'ImportEngine',
        );
      }
      // 書き込み中ファイルはスキップ
      // 性能最適化: スキャン時に取得済みの更新日時を再利用し、追加の stat() 呼び出しを回避する。
      // トレードオフ: スキャン〜判定間にファイルが変更された場合は検出できないが、
      // カメラの USB MSC 接続中は撮影不可であり、SD カードの場合も故意に操作しない限り
      // ファイル変更は発生しないため、実用上は問題ない。
      const int writingThresholdSeconds = 30;
      final modifiedUtc = DateTime.fromMillisecondsSinceEpoch(
        file.sourceModifiedTimeUtcMs,
        isUtc: true,
      );
      final nowUtc = DateTime.now().toUtc();
      final diffFromModified = nowUtc.difference(modifiedUtc);
      if (diffFromModified.inSeconds.abs() < writingThresholdSeconds) {
        warnings.add(
          ImportWarning(
            type: ImportWarningType.FileInUseSkipped,
            file: file,
            message: 'File appears to be in use, skipping.',
          ),
        );
        skippedCount++;
        continue;
      }

      // 取り込み済みかどうかを確認
      final normalizedSourcePath = normalizeSourcePathForLookup(file.relativePath);
      final existingRecord = recordBySourcePath[normalizedSourcePath];
      if (existingRecord != null) {
        final normalizedDestinationPath = existingRecord.destinationPath.replaceAll('\\', '/');
        final destinationFolderPath = p.posix.dirname(normalizedDestinationPath);
        final destinationFolder = destinationFolderPath == '.'
            ? settings.destinationFolder
            : p.join(settings.destinationFolder, destinationFolderPath);
        final destinationFileName = p.posix.basename(normalizedDestinationPath);
        final destPath = p.join(destinationFolder, destinationFileName);
        final destExists = await destinationFolderIndex.containsFile(
          destinationFolder,
          destinationFileName,
          confirmWhenMissing: true,
        );

        if (destExists) {
          final destFile = File(destPath);
          final shouldSkip = await _shouldSkipWithExistingRecord(
            existingRecord,
            file,
            destFile,
            signatureCache,
            updatedRecords,
          );
          if (shouldSkip) {
            skippedCount++;
            continue;
          }
        } else {
          final shouldSkip = await _trySkipWithRestoredOriginalDestination(
            existingRecord,
            file,
            destinationFolderIndex,
            signatureCache,
            updatedRecords,
          );
          if (shouldSkip) {
            skippedCount++;
            continue;
          }
          // 保存先がない場合は再取り込み
        }
        candidates.add((file: file, needsDestinationCheck: false));
      } else {
        candidates.add((file: file, needsDestinationCheck: true));
      }
    }

    if (recordsToRemove.isNotEmpty || updatedRecords.isNotEmpty) {
      var updatedMetadata = metadata;
      if (recordsToRemove.isNotEmpty) {
        updatedMetadata = updatedMetadata.removeRecordsBySourcePath(recordsToRemove);
      }
      if (updatedRecords.isNotEmpty) {
        updatedMetadata = updatedMetadata.upsertRecords(updatedRecords);
      }
      await _metadataManager.save(updatedMetadata);
    }

    final totalCandidates = candidates.length;
    var resolvedCount = 0;
    final resolvedCandidates = <({MediaFile file, bool needsDestinationCheck})>[];

    for (final candidate in candidates) {
      if (_isCancelled) {
        throw ImportCancelledException();
      }

      resolvedCount++;
      final shouldReportUi = resolvedCount % progressUiInterval == 0 || resolvedCount == totalCandidates;
      final shouldReportLog = resolvedCount % progressLogInterval == 0 || resolvedCount == totalCandidates;
      if (onProgress != null && shouldReportUi) {
        onProgress(
          resolvedCount,
          totalCandidates,
          candidate.file.relativePath,
          // UI 表示上、英字と日本語の間に半角スペースを入れるため先頭スペースを維持する
          ' EXIF を解析中...',
        );
      }
      if (shouldReportLog) {
        _log.debug(
          'Import target EXIF progress: $resolvedCount/$totalCandidates (last: ${candidate.file.relativePath}).',
          tag: 'ImportEngine',
        );
      }
      final resolvedFile = await _sonyFs.resolveMediaFileWithExif(
        candidate.file,
        cameraTimezone: settings.cameraTimezone,
        restoreToleranceSeconds: settings.dateRestoreToleranceSeconds,
      );

      resolvedCandidates.add(
        (
          file: resolvedFile,
          needsDestinationCheck: candidate.needsDestinationCheck,
        ),
      );
    }

    // EXIF 解決後に保存先フォルダの一覧をまとめて取得し、exists チェックの I/O を削減する
    final destinationFoldersForCandidates = <String>{};
    for (final candidate in resolvedCandidates) {
      final destinationFolder = _getDestinationFolder(candidate.file);
      destinationFoldersForCandidates.add(destinationFolder);
    }
    if (destinationFoldersForCandidates.isNotEmpty && onProgress != null) {
      onProgress(
        0,
        destinationFoldersForCandidates.length,
        null,
        '保存先フォルダを確認中...',
      );
    }
    await destinationFolderIndex.prewarm(
      destinationFoldersForCandidates,
      onProgress: (processedCount, totalCount, folderPath) {
        final shouldReportUi = processedCount % progressUiInterval == 0 || processedCount == totalCount;
        final shouldReportLog = processedCount % progressLogInterval == 0 || processedCount == totalCount;
        if (onProgress != null && shouldReportUi) {
          onProgress(
            processedCount,
            totalCount,
            folderPath,
            '保存先フォルダを確認中...',
          );
        }
        if (shouldReportLog) {
          _log.debug(
            'Destination folder prewarm progress: $processedCount/$totalCount (last: ${folderPath ?? 'unknown'}).',
            tag: 'ImportEngine',
          );
        }
      },
    );

    final totalResolvedCandidates = resolvedCandidates.length;
    var resolvedCandidateIndex = 0;
    for (final candidate in resolvedCandidates) {
      if (_isCancelled) {
        throw ImportCancelledException();
      }

      resolvedCandidateIndex++;
      final shouldReportUi =
          resolvedCandidateIndex % progressUiInterval == 0 || resolvedCandidateIndex == totalResolvedCandidates;
      final shouldReportLog =
          resolvedCandidateIndex % progressLogInterval == 0 || resolvedCandidateIndex == totalResolvedCandidates;
      if (onProgress != null && shouldReportUi) {
        onProgress(
          resolvedCandidateIndex,
          totalResolvedCandidates,
          candidate.file.relativePath,
          '保存先の重複を確認中...',
        );
      }
      if (shouldReportLog) {
        _log.debug(
          'Destination check progress: $resolvedCandidateIndex/$totalResolvedCandidates (last: ${candidate.file.relativePath}).',
          tag: 'ImportEngine',
        );
      }

      if (candidate.needsDestinationCheck) {
        final destFolder = _getDestinationFolder(candidate.file);
        final destPath = p.join(destFolder, candidate.file.fileName);
        final destFile = File(destPath);
        final destExists = await destinationFolderIndex.containsFile(
          destFolder,
          candidate.file.fileName,
          confirmWhenMissing: false,
        );
        if (destExists) {
          candidate.file.xxHash ??= await computeFileHash(File(candidate.file.absolutePath));
          final destHash = await computeFileHash(destFile);
          if (hashesMatch(candidate.file.xxHash!, destHash)) {
            final subfolderPath = settings.generateSubfolderPath(candidate.file.effectiveDateTimeLocal);
            final destinationRelativePath = p.posix.join(subfolderPath, candidate.file.fileName);
            final record = await _buildSkippedRecord(
              file: candidate.file,
              destinationPath: destinationRelativePath,
              appVersion: appVersion,
              signatureCache: signatureCache,
            );
            updatedRecords.add(record);
            skippedCount++;
            continue;
          }
        }
      }

      final destinationFolder = _getDestinationFolder(candidate.file);
      final destinationFileName = await _resolvePlannedDestinationFileName(
        candidate.file,
        destinationFolder,
        destinationFolderIndex,
      );
      final destinationPath = p.join(destinationFolder, destinationFileName);
      items.add(
        ImportPlanItem(
          file: candidate.file,
          sourcePath: candidate.file.relativePath,
          destinationPath: destinationPath,
          destinationFileName: destinationFileName,
          destinationFolder: destinationFolder,
        ),
      );
      totalSize += candidate.file.fileSize;
    }

    return (items: items, totalSize: totalSize, skippedCount: skippedCount);
  }

  /// 既存レコードに対してスキップ可能かを判定する
  Future<bool> _shouldSkipWithExistingRecord(
    ImportedFileRecord record,
    MediaFile file,
    File destinationFile,
    Map<String, FileLightweightSignature> signatureCache,
    List<ImportedFileRecord> updatedRecords,
  ) async {
    final hasTimeInfo = record.sourceCreatedTimeUtcMs > 0 && record.sourceModifiedTimeUtcMs > 0;
    final hasSizeInfo = record.fileSize > 0;
    final isSizeMatch = hasSizeInfo && record.fileSize == file.fileSize;
    final isTimeMatch =
        hasTimeInfo &&
        record.sourceCreatedTimeUtcMs == file.sourceCreatedTimeUtcMs &&
        record.sourceModifiedTimeUtcMs == file.sourceModifiedTimeUtcMs;

    if (!isSizeMatch) {
      return false;
    }

    if (isTimeMatch) {
      if (record.lightweightSignature != null) {
        final sourceSignature = await _getSignatureForFile(
          file.absolutePath,
          signatureCache,
        );
        if (record.lightweightSignature!.matches(sourceSignature)) {
          return true;
        }
        return false;
      }

      final sourceSignature = await _getSignatureForFile(
        file.absolutePath,
        signatureCache,
      );
      final destSignature = await _getSignatureForFile(
        destinationFile.path,
        signatureCache,
      );
      if (sourceSignature.matches(destSignature)) {
        updatedRecords.add(
          _withUpdatedSignatureAndTimes(record, file, sourceSignature),
        );
        return true;
      }
      return false;
    }

    if (!hasTimeInfo) {
      final sourceSignature = await _getSignatureForFile(
        file.absolutePath,
        signatureCache,
      );
      final destSignature = await _getSignatureForFile(
        destinationFile.path,
        signatureCache,
      );
      if (sourceSignature.matches(destSignature)) {
        updatedRecords.add(
          _withUpdatedSignatureAndTimes(record, file, sourceSignature),
        );
        return true;
      }
    }

    if (hasTimeInfo) {
      // タイムスタンプが不一致でも、内容が一致すれば同一ファイルとして扱う
      final sourceSignature = await _getSignatureForFile(
        file.absolutePath,
        signatureCache,
      );
      final destSignature = await _getSignatureForFile(
        destinationFile.path,
        signatureCache,
      );
      if (sourceSignature.matches(destSignature)) {
        updatedRecords.add(
          _withUpdatedSignatureAndTimes(record, file, sourceSignature),
        );
        return true;
      }
    }

    return false;
  }

  /// 保存先ファイルが失われた場合に、元のファイル名で復元されたファイルを判定する
  ///
  /// 同一フォルダ内に元のファイル名が存在し、サイズとシグネチャが一致した場合はスキップ対象とする。
  Future<bool> _trySkipWithRestoredOriginalDestination(
    ImportedFileRecord record,
    MediaFile file,
    _DestinationFolderIndex destinationFolderIndex,
    Map<String, FileLightweightSignature> signatureCache,
    List<ImportedFileRecord> updatedRecords,
  ) async {
    final normalizedDestinationPath = record.destinationPath.replaceAll('\\', '/');
    final destinationFolder = p.posix.dirname(normalizedDestinationPath);
    final destinationFolderPath = destinationFolder == '.' ? '' : destinationFolder;
    final candidateFolderPath = destinationFolderPath.isEmpty
        ? settings.destinationFolder
        : p.join(settings.destinationFolder, destinationFolderPath);
    final candidatePath = destinationFolderPath.isEmpty
        ? p.join(settings.destinationFolder, file.fileName)
        : p.join(settings.destinationFolder, destinationFolderPath, file.fileName);
    final candidateFile = File(candidatePath);
    final candidateExists = await destinationFolderIndex.containsFile(
      candidateFolderPath,
      file.fileName,
      confirmWhenMissing: true,
    );
    if (!candidateExists) {
      return false;
    }

    // サイズが一致しない場合は別ファイルとして扱う
    if (record.fileSize <= 0 || record.fileSize != file.fileSize) {
      return false;
    }

    final matchResult = await _isRestoredDestinationMatch(
      record,
      candidateFile,
      signatureCache,
    );
    if (!matchResult.isMatch) {
      return false;
    }

    final updatedDestinationPath = destinationFolderPath.isEmpty
        ? file.fileName
        : p.posix.join(destinationFolderPath, file.fileName);
    if (matchResult.shouldUpdateSignature && matchResult.signature != null) {
      updatedRecords.add(
        _withUpdatedDestinationPathAndSignature(
          record,
          updatedDestinationPath,
          matchResult.signature!,
        ),
      );
    } else {
      updatedRecords.add(
        _withUpdatedDestinationPath(record, updatedDestinationPath),
      );
    }
    return true;
  }

  /// 復元済みの保存先ファイルが同一かを判定する
  ///
  /// 軽量シグネチャがある場合はそれを優先し、無い場合はフルハッシュで判定する。
  Future<({bool isMatch, FileLightweightSignature? signature, bool shouldUpdateSignature})> _isRestoredDestinationMatch(
    ImportedFileRecord record,
    File candidateFile,
    Map<String, FileLightweightSignature> signatureCache,
  ) async {
    if (record.lightweightSignature != null) {
      final candidateSignature = await _getSignatureForFile(
        candidateFile.path,
        signatureCache,
      );
      if (record.lightweightSignature!.matches(candidateSignature)) {
        return (isMatch: true, signature: candidateSignature, shouldUpdateSignature: false);
      }
      final candidateHash = await computeFileHash(candidateFile);
      if (hashesMatch(record.xxHash, candidateHash)) {
        return (isMatch: true, signature: candidateSignature, shouldUpdateSignature: true);
      }
      return (isMatch: false, signature: candidateSignature, shouldUpdateSignature: false);
    }

    final candidateHash = await computeFileHash(candidateFile);
    return (isMatch: hashesMatch(record.xxHash, candidateHash), signature: null, shouldUpdateSignature: false);
  }

  /// シグネチャを取得し、キャッシュに保存する
  Future<FileLightweightSignature> _getSignatureForFile(
    String filePath,
    Map<String, FileLightweightSignature> signatureCache,
  ) async {
    final cached = signatureCache[filePath];
    if (cached != null) {
      return cached;
    }
    final signature = await computeFileLightweightSignature(File(filePath));
    signatureCache[filePath] = signature;
    return signature;
  }

  /// レコードの保存先パスだけを更新したコピーを作成する
  ImportedFileRecord _withUpdatedDestinationPath(
    ImportedFileRecord record,
    String destinationPath,
  ) {
    return ImportedFileRecord(
      sourcePath: record.sourcePath,
      xxHash: record.xxHash,
      sourceCreatedTimeUtcMs: record.sourceCreatedTimeUtcMs,
      sourceModifiedTimeUtcMs: record.sourceModifiedTimeUtcMs,
      fileSize: record.fileSize,
      lightweightSignature: record.lightweightSignature,
      importedAt: record.importedAt,
      destinationPath: destinationPath,
      appVersion: record.appVersion,
    );
  }

  /// レコードの保存先パスとシグネチャを更新したコピーを作成する
  ImportedFileRecord _withUpdatedDestinationPathAndSignature(
    ImportedFileRecord record,
    String destinationPath,
    FileLightweightSignature signature,
  ) {
    return ImportedFileRecord(
      sourcePath: record.sourcePath,
      xxHash: record.xxHash,
      sourceCreatedTimeUtcMs: record.sourceCreatedTimeUtcMs,
      sourceModifiedTimeUtcMs: record.sourceModifiedTimeUtcMs,
      fileSize: record.fileSize,
      lightweightSignature: signature,
      importedAt: record.importedAt,
      destinationPath: destinationPath,
      appVersion: record.appVersion,
    );
  }

  /// レコードのシグネチャとファイル時刻を更新したコピーを作成する
  ImportedFileRecord _withUpdatedSignatureAndTimes(
    ImportedFileRecord record,
    MediaFile file,
    FileLightweightSignature signature,
  ) {
    return ImportedFileRecord(
      sourcePath: record.sourcePath,
      xxHash: record.xxHash,
      sourceCreatedTimeUtcMs: file.sourceCreatedTimeUtcMs,
      sourceModifiedTimeUtcMs: file.sourceModifiedTimeUtcMs,
      fileSize: file.fileSize,
      lightweightSignature: signature,
      importedAt: record.importedAt,
      destinationPath: record.destinationPath,
      appVersion: record.appVersion,
    );
  }

  /// スキップ済みファイルのレコードを構築する
  ///
  /// 保存先に同一ファイルが存在する場合、コピーを行わずにメタデータへ登録する。
  Future<ImportedFileRecord> _buildSkippedRecord({
    required MediaFile file,
    required String destinationPath,
    required String appVersion,
    required Map<String, FileLightweightSignature> signatureCache,
  }) async {
    final sourceHash = file.xxHash ?? await computeFileHash(File(file.absolutePath));
    file.xxHash = sourceHash;
    FileLightweightSignature? signature;
    try {
      signature = await _getSignatureForFile(
        file.absolutePath,
        signatureCache,
      );
    } catch (ex) {
      _log.warning(
        'Failed to compute lightweight signature for skipped metadata.',
        tag: 'ImportEngine',
        error: ex,
      );
    }

    return ImportedFileRecord(
      sourcePath: file.relativePath,
      xxHash: sourceHash,
      sourceCreatedTimeUtcMs: file.sourceCreatedTimeUtcMs,
      sourceModifiedTimeUtcMs: file.sourceModifiedTimeUtcMs,
      fileSize: file.fileSize,
      lightweightSignature: signature,
      importedAt: DateTime.now().toUtc(),
      destinationPath: destinationPath,
      appVersion: appVersion,
    );
  }

  /// メタデータの削除対象かどうかを判定する
  bool _isSourcePathInScanScope(String sourcePath) {
    final normalized = normalizeSourcePathForLookup(sourcePath);
    if (normalized.startsWith('dcim/')) {
      return true;
    }
    if (normalized.startsWith('private/m4root/clip/')) {
      if (normalized.endsWith('.xml')) {
        return settings.isImportVideoXML;
      }
      return true;
    }
    if (normalized.startsWith('private/m4root/sub/')) {
      return settings.isImportProxyVideos;
    }
    return false;
  }

  /// 単一ファイルの取り込み処理
  Future<_FileProcessResult> _processFile(
    ImportPlanItem planItem,
    List<ImportWarning> warnings, {
    void Function(int bytesCopied)? onCopyProgress,
  }) async {
    final file = planItem.file;

    try {
      // EXIF/メタデータの読み取り失敗を警告として記録
      if (file.type.isPhoto && !file.isExifDateTimeValid) {
        _log.warning(
          'EXIF datetime missing, using source file time: ${file.relativePath}.',
          tag: 'ImportEngine',
        );
        warnings.add(
          ImportWarning(
            type: ImportWarningType.ExifReadFailed,
            file: file,
            message: 'Failed to read EXIF datetime, using source file time.',
          ),
        );
      } else if (file.type == MediaType.Video && file.exifDateTimeLocal == null) {
        _log.warning(
          'Video XML datetime missing, using source file time: ${file.relativePath}.',
          tag: 'ImportEngine',
        );
        warnings.add(
          ImportWarning(
            type: ImportWarningType.ExifReadFailed,
            file: file,
            message: 'Failed to read video XML datetime, using source file time.',
          ),
        );
      }

      // 書き込み中ファイルの再チェック（取り込み直前の安全確認）
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

      // ファイルをコピー
      _lastDestinationPath = await _copyFileWithHash(
        file,
        warnings,
        onCopyProgress: onCopyProgress,
        plannedFileName: planItem.destinationFileName,
      );

      return _FileProcessResult.imported;
    } on ImportFatalException {
      rethrow;
    } on FileSystemException catch (ex) {
      _log.error(
        'File system error detected, aborting import.',
        tag: 'ImportEngine',
        error: ex,
      );
      throw ImportFatalException(
        'ファイルの読み書きに失敗したため取り込みを中断しました。ファイル: ${file.fileName}。',
        debugMessage: ex.toString(),
      );
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
    final subfolderPath = settings.generateSubfolderPath(file.effectiveDateTimeLocal);
    return p.join(settings.destinationFolder, subfolderPath);
  }

  /// 取り込み先のファイル名を事前に決定する
  ///
  /// 既存ファイルとの重複がある場合はサフィックス付きの名前を返す。
  Future<String> _resolvePlannedDestinationFileName(
    MediaFile file,
    String destinationFolder,
    _DestinationFolderIndex destinationFolderIndex,
  ) async {
    return destinationFolderIndex.resolveUniqueFileName(
      destinationFolder,
      file.fileName,
    );
  }

  /// 日時復元に使用するターゲット日時を解決
  ///
  /// 写真は作成/更新のうち古い方を基準に判定し、動画は開始/終了で判定する。
  /// 許容誤差内であれば取り込み元の日時を維持し、ずれていれば撮影日時に統一する。
  ({DateTime creationTimeUtc, DateTime modifiedTimeUtc}) _resolveRestoreDateTimes(
    MediaFile file,
  ) {
    final tolerance = settings.dateRestoreToleranceSeconds;

    if (file.type == MediaType.Video) {
      final sourceCreationUtc = file.sourceCreatedTimeUtc;
      final sourceModifiedUtc = file.sourceModifiedTimeUtc;
      final startUtc = file.effectiveDateTimeUtc;
      final endUtc = file.capturedEndTimeUtc;

      final startDiff = startUtc.difference(sourceCreationUtc).inSeconds.abs();
      final endDiff = endUtc.difference(sourceModifiedUtc).inSeconds.abs();

      if (startDiff <= tolerance && endDiff <= tolerance) {
        return (
          creationTimeUtc: sourceCreationUtc,
          modifiedTimeUtc: sourceModifiedUtc,
        );
      }

      return (creationTimeUtc: startUtc, modifiedTimeUtc: endUtc);
    }

    final sourceReferenceUtc = file.sourceReferenceTimeUtc;
    final captureUtc = file.effectiveDateTimeUtc;
    final diffSeconds = captureUtc.difference(sourceReferenceUtc).inSeconds.abs();
    if (diffSeconds <= tolerance) {
      return (
        creationTimeUtc: sourceReferenceUtc,
        modifiedTimeUtc: sourceReferenceUtc,
      );
    }

    return (creationTimeUtc: captureUtc, modifiedTimeUtc: captureUtc);
  }

  /// ファイルをコピーしてハッシュを計算
  ///
  /// RandomAccessFile ベースのストリーミングコピーを使用し、
  /// 書き込み時に同時にハッシュを計算する。
  /// コピー後のハッシュ検証は行わない（システムコールが成功すればデータは正しく転送されている）。
  Future<String> _copyFileWithHash(
    MediaFile file,
    List<ImportWarning> warnings, {
    void Function(int bytesCopied)? onCopyProgress,
    String? plannedFileName,
  }) async {
    final sourceFile = File(file.absolutePath);
    final destFolder = _getDestinationFolder(file);

    // 保存先フォルダを作成
    await ensureDirectoryExists(destFolder);

    // ファイル名を決定（重複時はサフィックス付与）
    var destFileName = plannedFileName ?? file.fileName;

    // 既存ファイルとの重複チェック
    final plannedFile = File(p.join(destFolder, destFileName));
    if (await plannedFile.exists()) {
      destFileName = await generateUniqueFileName(Directory(destFolder), destFileName);
    }

    // 元のファイル名と異なる場合は警告を記録
    if (destFileName != file.fileName) {
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

    try {
      // ストリーミングコピー + ハッシュ計算（RandomAccessFile ベース）
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

      // 日時復元
      if (settings.isRestoreDateTimeFromExif) {
        try {
          final targetTimes = _resolveRestoreDateTimes(file);
          await restoreFileDateTime(
            file: destFile,
            creationTimeUtc: targetTimes.creationTimeUtc,
            modifiedTimeUtc: targetTimes.modifiedTimeUtc,
          );
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
      final relativeDestPath = settings.generateSubfolderPath(file.effectiveDateTimeLocal);
      _lastDestinationPath = p.posix.join(relativeDestPath, destFileName);

      // 成功
      _log.logFileCopied(file.relativePath, destPath);
      return _lastDestinationPath!;
    } on ImportFatalException {
      if (await destFile.exists()) {
        try {
          await destFile.delete();
        } catch (_) {
          // コピー失敗時の残骸削除に失敗しても中断を優先する
        }
      }
      rethrow;
    } on UnsupportedError {
      if (await destFile.exists()) {
        try {
          await destFile.delete();
        } catch (_) {
          // コピー失敗時の残骸削除に失敗しても中断を優先する
        }
      }
      rethrow;
    } on FileSystemException catch (ex) {
      if (await destFile.exists()) {
        try {
          await destFile.delete();
        } catch (_) {
          // コピー失敗時の残骸削除に失敗しても中断を優先する
        }
      }
      if (_isNoSpaceError(ex)) {
        throw ImportFatalException(
          '保存先の空き容量が不足しているため取り込みを中断しました。ファイル: ${file.fileName}。',
          debugMessage: ex.toString(),
        );
      }
      rethrow;
    }
  }

  /// 空き容量不足のエラーかどうかを判定する
  bool _isNoSpaceError(FileSystemException ex) {
    final errorCode = ex.osError?.errorCode;
    if (errorCode == null) {
      return false;
    }
    // macOS/Linux: 28, Windows: 112
    return errorCode == 28 || errorCode == 112;
  }

  /// 中断理由をユーザー向けメッセージに変換する
  String resolveFatalErrorMessage(Object ex) {
    if (ex is ImportFatalException) {
      return ex.userMessage;
    }
    if (ex is ImportCancelledException) {
      return '取り込みがキャンセルされました。';
    }
    if (ex is UnsupportedError) {
      return 'ファイル日時の取得または復元に必要なネイティブ API が利用できないため取り込みを中断しました。';
    }
    if (ex is FileSystemException) {
      return 'ファイルの読み書きに失敗したため取り込みを中断しました。';
    }
    return '取り込み中にエラーが発生したため中断しました。';
  }
}

/// 保存先フォルダの一覧をキャッシュするインデックス
///
/// SMB などの遅い I/O 環境でも、フォルダ単位の一覧取得で
/// per-file の exists 呼び出しを削減する。
class _DestinationFolderIndex {
  /// ロガー
  final LoggingService _log;

  /// フォルダパスごとのスナップショット
  final Map<String, _DestinationFolderSnapshot> _snapshots = {};

  /// 読み取り失敗済みのフォルダ
  final Set<String> _failedFolders = {};

  _DestinationFolderIndex(this._log);

  /// フォルダ内に対象ファイルが存在するかを判定する
  ///
  /// スナップショットに存在しない場合は false を返すが、
  /// [confirmWhenMissing] が true の場合は per-file の exists で再確認する。
  Future<bool> containsFile(
    String folderPath,
    String fileName, {
    required bool confirmWhenMissing,
  }) async {
    final snapshot = await _getSnapshot(folderPath);
    if (snapshot != null) {
      if (snapshot.fileNames.contains(fileName)) {
        return true;
      }
      if (confirmWhenMissing) {
        return File(p.join(folderPath, fileName)).exists();
      }
      return false;
    }

    return File(p.join(folderPath, fileName)).exists();
  }

  /// 指定されたフォルダ群のスナップショットを事前に作成する
  Future<void> prewarm(
    Iterable<String> folderPaths, {
    void Function(int processedCount, int totalCount, String? folderPath)? onProgress,
  }) async {
    final folderList = folderPaths.toList();
    final totalCount = folderList.length;
    var processedCount = 0;
    for (final folderPath in folderList) {
      await _getSnapshot(folderPath);
      processedCount++;
      if (onProgress != null) {
        onProgress(processedCount, totalCount, folderPath);
      }
    }
  }

  /// 既存ファイルとの重複を避けたファイル名を決定する
  Future<String> resolveUniqueFileName(
    String folderPath,
    String fileName,
  ) async {
    final snapshot = await _getSnapshot(folderPath);
    if (snapshot == null) {
      return generateUniqueFileName(Directory(folderPath), fileName);
    }

    final baseName = getBaseName(fileName);
    final extension = getExtension(fileName);
    var candidate = fileName;
    var counter = 1;

    while (snapshot.fileNames.contains(candidate)) {
      candidate = '$baseName ($counter)$extension';
      counter++;

      // 無限ループ防止（通常は到達しない）
      if (counter > 10000) {
        throw Exception('Failed to generate unique file name for: $fileName');
      }
    }

    snapshot.fileNames.add(candidate);
    return candidate;
  }

  /// フォルダ一覧のスナップショットを取得する
  Future<_DestinationFolderSnapshot?> _getSnapshot(
    String folderPath,
  ) async {
    final cached = _snapshots[folderPath];
    if (cached != null) {
      return cached;
    }
    if (_failedFolders.contains(folderPath)) {
      return null;
    }

    final directory = Directory(folderPath);
    final isDirectoryExists = await directory.exists();
    if (!isDirectoryExists) {
      final snapshot = _DestinationFolderSnapshot.empty();
      _snapshots[folderPath] = snapshot;
      return snapshot;
    }

    try {
      final fileNames = <String>{};
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File) {
          fileNames.add(p.basename(entity.path));
        }
      }
      final snapshot = _DestinationFolderSnapshot(
        fileNames: fileNames,
      );
      _snapshots[folderPath] = snapshot;
      return snapshot;
    } catch (ex) {
      _failedFolders.add(folderPath);
      _log.warning(
        'Failed to list destination folder, falling back to per-file checks.',
        tag: 'ImportEngine',
        error: ex,
      );
      return null;
    }
  }
}

/// 保存先フォルダのスナップショット
class _DestinationFolderSnapshot {
  /// ファイル名一覧
  final Set<String> fileNames;

  _DestinationFolderSnapshot({
    required this.fileNames,
  });

  /// 空のスナップショットを生成する
  factory _DestinationFolderSnapshot.empty() {
    return _DestinationFolderSnapshot(
      fileNames: <String>{},
    );
  }
}

/// 取り込み処理を中断するための致命的例外
class ImportFatalException implements Exception {
  /// ユーザー向けの中断理由
  final String userMessage;

  /// デバッグ用の詳細メッセージ
  final String? debugMessage;

  ImportFatalException(this.userMessage, {this.debugMessage});

  @override
  String toString() {
    return debugMessage == null ? userMessage : '$userMessage ($debugMessage)';
  }
}

/// 取り込み準備中のキャンセル例外
class ImportCancelledException implements Exception {
  /// ユーザー向けのキャンセル理由
  final String message;

  ImportCancelledException([
    this.message = 'Import cancelled by user.',
  ]);

  @override
  String toString() {
    return message;
  }
}

/// ファイル処理結果
enum _FileProcessResult {
  imported,
  skipped,
  error,
}
