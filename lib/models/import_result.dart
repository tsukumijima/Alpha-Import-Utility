/// 取り込み結果関連のモデル定義
///
/// 取り込み処理の結果、警告、エラーを保持する。
library;

import 'package:json_annotation/json_annotation.dart';

import 'media_file.dart';

part 'import_result.g.dart';

/// 取り込み警告の種類
enum ImportWarningType {
  /// 同名だが内容が異なるファイルを別名で保存した
  ///
  /// 例: DSC00001.ARW → DSC00001 (1).ARW
  DuplicateRenamed,

  /// EXIF 読み取りに失敗した（ファイル日時を使用）
  ExifReadFailed,

  /// 日時復元に失敗した
  DateRestoreFailed,

  /// ハッシュ検証に失敗した（再コピーを実施）
  HashVerificationFailed,

  /// メタデータ更新をスキップした（SD カードが読み取り専用など）
  MetadataUpdateSkipped,

  /// 未知のファイル拡張子を検出した（取り込み対象外）
  UnknownExtensionFound,

  /// 書き込み中と思われるファイルをスキップした
  FileInUseSkipped,
}

/// ImportWarningType の拡張メソッド
extension ImportWarningTypeExtension on ImportWarningType {
  /// 警告の重要度（高いほど重要）
  int get severity {
    switch (this) {
      case ImportWarningType.HashVerificationFailed:
        return 3; // 最重要：データ整合性に関わる
      case ImportWarningType.DuplicateRenamed:
        return 2; // 重要：ファイル名が変わった
      case ImportWarningType.DateRestoreFailed:
      case ImportWarningType.MetadataUpdateSkipped:
        return 1; // 中程度：機能が一部動作しなかった
      case ImportWarningType.ExifReadFailed:
      case ImportWarningType.UnknownExtensionFound:
      case ImportWarningType.FileInUseSkipped:
        return 0; // 低：情報提供のみ
    }
  }
}

/// 取り込み警告を表すクラス
class ImportWarning {
  /// 警告の種類
  final ImportWarningType type;

  /// 対象ファイル
  final MediaFile file;

  /// 警告メッセージ（詳細情報）
  final String message;

  /// 発生日時
  final DateTime timestamp;

  ImportWarning({
    required this.type,
    required this.file,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'ImportWarning(type: ${type.name}, file: ${file.fileName}, message: $message)';
  }
}

/// SD カードに記録する取り込み済みファイルのレコード
///
/// PRIVATE/AIU/METADATA.JSON に保存される各ファイルの情報。
@JsonSerializable()
class ImportedFileRecord {
  /// SD カード内の相対パス（例: 'DCIM/100MSDCF/DSC00001.ARW'）
  final String sourcePath;

  /// xxHash64 ハッシュ値（16 進数文字列）
  final String xxHash;

  /// 取り込み元ファイルの作成日時（UTC ミリ秒）
  final int sourceCreatedTimeUtcMs;

  /// 取り込み元ファイルの更新日時（UTC ミリ秒）
  final int sourceModifiedTimeUtcMs;

  /// ファイルサイズ（バイト）
  final int fileSize;

  /// 軽量シグネチャ（部分ハッシュ）
  ///
  /// 差分判定の高速化に使用する。
  final FileLightweightSignature? lightweightSignature;

  /// 取り込み日時（UTC）
  final DateTime importedAt;

  /// コピー先パス（保存先フォルダからの相対パス）
  ///
  /// 例: '2025_12_24/DSC00001.ARW'
  final String destinationPath;

  /// 取り込み時のアプリバージョン
  final String appVersion;

  ImportedFileRecord({
    required this.sourcePath,
    required this.xxHash,
    required this.sourceCreatedTimeUtcMs,
    required this.sourceModifiedTimeUtcMs,
    required this.fileSize,
    required this.lightweightSignature,
    required this.importedAt,
    required this.destinationPath,
    required this.appVersion,
  });

  /// JSON からデシリアライズ
  factory ImportedFileRecord.fromJson(Map<String, dynamic> json) => _$ImportedFileRecordFromJson(json);

  /// JSON にシリアライズ
  Map<String, dynamic> toJson() => _$ImportedFileRecordToJson(this);

  @override
  String toString() {
    return 'ImportedFileRecord(source: $sourcePath, dest: $destinationPath)';
  }
}

/// 軽量シグネチャ（部分ハッシュ）を表すクラス
///
/// サイズが同じファイルの差分判定を高速化するために使用する。
@JsonSerializable()
class FileLightweightSignature {
  /// チャンクサイズ（バイト）
  final int chunkSize;

  /// 先頭チャンクのハッシュ
  final String headHash;

  /// 中間チャンクのハッシュ
  final String middleHash;

  /// 末尾チャンクのハッシュ
  final String tailHash;

  FileLightweightSignature({
    required this.chunkSize,
    required this.headHash,
    required this.middleHash,
    required this.tailHash,
  });

  /// JSON からデシリアライズ
  factory FileLightweightSignature.fromJson(Map<String, dynamic> json) => _$FileLightweightSignatureFromJson(json);

  /// JSON にシリアライズ
  Map<String, dynamic> toJson() => _$FileLightweightSignatureToJson(this);

  /// シグネチャが一致するかを判定
  bool matches(FileLightweightSignature other) {
    return chunkSize == other.chunkSize &&
        headHash == other.headHash &&
        middleHash == other.middleHash &&
        tailHash == other.tailHash;
  }
}

/// SD カード上のメタデータファイルの内容
///
/// PRIVATE/AIU/METADATA.JSON のルートオブジェクト。
@JsonSerializable()
class ImportMetadata {
  /// メタデータフォーマットのバージョン
  final String version;

  /// 最終更新日時（UTC）
  final DateTime lastUpdated;

  /// 取り込み済みファイルの一覧
  final List<ImportedFileRecord> files;

  ImportMetadata({
    this.version = '2.0.0',
    required this.lastUpdated,
    required this.files,
  });

  /// 空のメタデータを作成
  factory ImportMetadata.empty() {
    return ImportMetadata(lastUpdated: DateTime.now().toUtc(), files: []);
  }

  /// JSON からデシリアライズ
  factory ImportMetadata.fromJson(Map<String, dynamic> json) => _$ImportMetadataFromJson(json);

  /// JSON にシリアライズ
  Map<String, dynamic> toJson() => _$ImportMetadataToJson(this);

  /// 指定したソースパスのレコードを検索
  ///
  /// 見つからない場合は null を返す
  ImportedFileRecord? findBySourcePath(String sourcePath) {
    try {
      return files.firstWhere((record) => record.sourcePath == sourcePath);
    } catch (_) {
      return null;
    }
  }

  /// 新しいレコードを追加したメタデータを返す
  ImportMetadata addRecord(ImportedFileRecord record) {
    return ImportMetadata(
      version: version,
      lastUpdated: DateTime.now().toUtc(),
      files: [...files, record],
    );
  }

  /// 既存レコードを置き換えるか、新規に追加したメタデータを返す
  ///
  /// 同じ [sourcePath] を持つレコードが存在する場合は置換する。
  ImportMetadata upsertRecord(ImportedFileRecord record) {
    final updatedFiles = [...files];
    final index = updatedFiles.indexWhere((existing) => existing.sourcePath == record.sourcePath);
    if (index >= 0) {
      updatedFiles[index] = record;
    } else {
      updatedFiles.add(record);
    }

    return ImportMetadata(
      version: version,
      lastUpdated: DateTime.now().toUtc(),
      files: updatedFiles,
    );
  }

  /// 指定したソースパスのレコードを削除したメタデータを返す
  ImportMetadata removeRecordsBySourcePath(Set<String> sourcePaths) {
    if (sourcePaths.isEmpty) {
      return this;
    }

    final updatedFiles = files.where((record) => !sourcePaths.contains(record.sourcePath)).toList();
    return ImportMetadata(
      version: version,
      lastUpdated: DateTime.now().toUtc(),
      files: updatedFiles,
    );
  }

  /// 複数のレコードを追加したメタデータを返す
  ImportMetadata addRecords(List<ImportedFileRecord> newRecords) {
    return ImportMetadata(
      version: version,
      lastUpdated: DateTime.now().toUtc(),
      files: [...files, ...newRecords],
    );
  }

  /// 複数のレコードを置換または追加したメタデータを返す
  ImportMetadata upsertRecords(List<ImportedFileRecord> newRecords) {
    if (newRecords.isEmpty) {
      return this;
    }

    final updatedFiles = [...files];
    for (final record in newRecords) {
      final index = updatedFiles.indexWhere((existing) => existing.sourcePath == record.sourcePath);
      if (index >= 0) {
        updatedFiles[index] = record;
      } else {
        updatedFiles.add(record);
      }
    }

    return ImportMetadata(
      version: version,
      lastUpdated: DateTime.now().toUtc(),
      files: updatedFiles,
    );
  }

  @override
  String toString() {
    return 'ImportMetadata(version: $version, files: ${files.length})';
  }
}

/// 取り込み処理全体の結果
class ImportResult {
  /// 取り込み成功件数
  final int successCount;

  /// スキップ件数（取り込み済み）
  final int skippedCount;

  /// 警告件数
  final int warningCount;

  /// エラー件数
  final int errorCount;

  /// 警告の一覧
  final List<ImportWarning> warnings;

  /// 取り込んだファイルのレコード一覧
  final List<ImportedFileRecord> importedFiles;

  /// 処理時間
  final Duration duration;

  /// キャンセルされたかどうか
  final bool wasCancelled;

  /// エラーメッセージ（エラー終了時のみ）
  final String? errorMessage;

  ImportResult({
    required this.successCount,
    required this.skippedCount,
    required this.warningCount,
    required this.errorCount,
    required this.warnings,
    required this.importedFiles,
    required this.duration,
    this.wasCancelled = false,
    this.errorMessage,
  });

  /// 空の結果を作成
  factory ImportResult.empty() {
    return ImportResult(
      successCount: 0,
      skippedCount: 0,
      warningCount: 0,
      errorCount: 0,
      warnings: [],
      importedFiles: [],
      duration: Duration.zero,
    );
  }

  /// キャンセル結果を作成
  factory ImportResult.cancelled({
    required int successCount,
    required int skippedCount,
    required List<ImportWarning> warnings,
    required List<ImportedFileRecord> importedFiles,
    required Duration duration,
  }) {
    return ImportResult(
      successCount: successCount,
      skippedCount: skippedCount,
      warningCount: warnings.length,
      errorCount: 0,
      warnings: warnings,
      importedFiles: importedFiles,
      duration: duration,
      wasCancelled: true,
    );
  }

  /// エラー結果を作成
  factory ImportResult.error({
    required String errorMessage,
    int successCount = 0,
    int skippedCount = 0,
    List<ImportWarning>? warnings,
    List<ImportedFileRecord>? importedFiles,
    Duration? duration,
  }) {
    return ImportResult(
      successCount: successCount,
      skippedCount: skippedCount,
      warningCount: warnings?.length ?? 0,
      errorCount: 1,
      warnings: warnings ?? [],
      importedFiles: importedFiles ?? [],
      duration: duration ?? Duration.zero,
      errorMessage: errorMessage,
    );
  }

  /// 処理が正常に完了したか
  bool get isSuccess => !wasCancelled && errorCount == 0;

  @override
  String toString() {
    return 'ImportResult(success: $successCount, skipped: $skippedCount, warnings: $warningCount, '
        'errors: $errorCount, duration: $duration, cancelled: $wasCancelled)';
  }
}

/// 取り込み予定のファイルを表すクラス
class ImportPlanItem {
  /// 対象ファイル
  final MediaFile file;

  /// 取り込み元の相対パス
  final String sourcePath;

  /// 取り込み先のフルパス
  final String destinationPath;

  /// 取り込み先のファイル名
  final String destinationFileName;

  /// 取り込み先のフォルダパス
  final String destinationFolder;

  ImportPlanItem({
    required this.file,
    required this.sourcePath,
    required this.destinationPath,
    required this.destinationFileName,
    required this.destinationFolder,
  });

  /// 別名保存が予定されているか
  bool get isRenamed => destinationFileName != file.fileName;
}

/// 取り込み前のプランを表すクラス
///
/// スキャン結果と取り込み対象の一覧を保持する。
class ImportPlan {
  /// 取り込み対象の一覧
  final List<ImportPlanItem> items;

  /// 取り込み対象の合計サイズ
  final int totalSize;

  /// スキップされたファイル数
  final int skippedCount;

  /// 準備段階で発生した警告
  final List<ImportWarning> warnings;

  ImportPlan({
    required this.items,
    required this.totalSize,
    required this.skippedCount,
    required this.warnings,
  });

  /// 取り込み対象の数
  int get targetCount => items.length;
}

/// 取り込み処理のフェーズ
///
/// ImportEngine の各処理段階を表す。UI はこの値に基づいて
/// ダイアログタイトルやステータステキストを決定する。
enum ImportPhase {
  /// 初期化中（エンジン起動直後）
  Initializing,

  /// SD カード構造の検証中
  ValidatingSDCard,

  /// 書き込み可能性の確認中
  CheckingWritePermission,

  /// メディアファイルのスキャン中
  ScanningMediaFiles,

  /// 取り込み対象の判定中（メタデータ照合）
  DeterminingTargets,

  /// EXIF / メタデータの解析中
  ParsingExif,

  /// 保存先フォルダの確認中
  CheckingDestination,

  /// ディスク容量の確認中
  CheckingDiskSpace,

  /// ファイル取り込み中（実際のコピー処理）
  Importing,
}

/// 取り込み進捗の状態
class ImportProgress {
  /// 現在の処理フェーズ
  final ImportPhase importPhase;

  /// 現在処理中のファイル
  final MediaFile? currentFile;

  /// 処理済みファイル数
  final int processedCount;

  /// 総ファイル数
  final int totalCount;

  /// 現在のファイルのコピー進捗（0.0 〜 1.0）
  final double currentFileProgress;

  /// 現在のファイルのコピー済みバイト数
  final int currentFileCopiedBytes;

  /// 現在のファイルの総バイト数
  final int currentFileTotalBytes;

  /// 処理フェーズの説明（詳細な説明用、importPhase と併用）
  ///
  /// 通常は null。特殊なケースで詳細メッセージを表示したい場合にのみ設定する。
  /// null または空文字の場合、UI は importPhase からローカライズされたテキストを取得する。
  final String? phase;

  /// スキャン中の現在ファイルパス
  final String? scanCurrentPath;

  /// コピー中の取り込み先パス（絶対パス）
  final String? currentDestinationPath;

  ImportProgress({
    required this.importPhase,
    this.currentFile,
    required this.processedCount,
    required this.totalCount,
    this.currentFileProgress = 0.0,
    this.currentFileCopiedBytes = 0,
    this.currentFileTotalBytes = 0,
    this.phase,
    this.scanCurrentPath,
    this.currentDestinationPath,
  });

  /// 初期状態を作成
  factory ImportProgress.initial() {
    return ImportProgress(
      importPhase: ImportPhase.Initializing,
      processedCount: 0,
      totalCount: 0,
    );
  }

  /// スキャン中の進捗を作成
  factory ImportProgress.scanning({
    int processedCount = 0,
    String? scanCurrentPath,
    String? phase,
  }) {
    return ImportProgress(
      importPhase: ImportPhase.ScanningMediaFiles,
      processedCount: processedCount,
      totalCount: 0,
      phase: phase,
      scanCurrentPath: scanCurrentPath,
    );
  }

  /// 取り込み対象の確定中の進捗を作成
  factory ImportProgress.preparingTargets({
    required ImportPhase importPhase,
    required int processedCount,
    required int totalCount,
    String? currentPath,
    String? phase,
  }) {
    return ImportProgress(
      importPhase: importPhase,
      processedCount: processedCount,
      totalCount: totalCount,
      phase: phase,
      scanCurrentPath: currentPath,
    );
  }

  /// 全体の進捗率（0.0 〜 1.0）
  double get overallProgress {
    if (totalCount == 0) return 0.0;
    return processedCount / totalCount;
  }

  /// 新しいファイルの処理を開始
  ImportProgress startFile(
    MediaFile file, {
    String? destinationPath,
    String? phase,
  }) {
    return ImportProgress(
      importPhase: ImportPhase.Importing,
      currentFile: file,
      processedCount: processedCount,
      totalCount: totalCount,
      currentFileProgress: 0.0,
      currentFileCopiedBytes: 0,
      currentFileTotalBytes: file.fileSize,
      phase: phase,
      currentDestinationPath: destinationPath,
    );
  }

  /// ファイルコピー進捗を更新
  ImportProgress updateFileProgress(int copiedBytes) {
    final progress = currentFileTotalBytes > 0 ? copiedBytes / currentFileTotalBytes : 0.0;
    return ImportProgress(
      importPhase: importPhase,
      currentFile: currentFile,
      processedCount: processedCount,
      totalCount: totalCount,
      currentFileProgress: progress,
      currentFileCopiedBytes: copiedBytes,
      currentFileTotalBytes: currentFileTotalBytes,
      phase: phase,
      scanCurrentPath: null,
      currentDestinationPath: currentDestinationPath,
    );
  }

  /// ファイル処理完了
  ImportProgress completeFile() {
    return ImportProgress(
      importPhase: importPhase,
      currentFile: null,
      processedCount: processedCount + 1,
      totalCount: totalCount,
      currentFileProgress: 0.0,
      currentFileCopiedBytes: 0,
      currentFileTotalBytes: 0,
      phase: phase,
      scanCurrentPath: null,
      currentDestinationPath: null,
    );
  }

  @override
  String toString() {
    return 'ImportProgress(processed: $processedCount, total: $totalCount, phase: $phase)';
  }
}
