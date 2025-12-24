/// SD カード上のメタデータ管理機能
///
/// PRIVATE/AIU/METADATA.JSON ファイルの読み書きを行う。
/// 取り込み済みファイルの記録を管理し、重複取り込みを防止する。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/import_result.dart';
import 'logging_service.dart';

/// メタデータファイルのパス定数
const String _metadataFolderName = 'AIU';
const String _metadataFileName = 'METADATA.JSON';

/// メタデータ管理サービス
///
/// SD カード上の PRIVATE/AIU/METADATA.JSON ファイルを管理する。
/// 取り込み済みファイルの記録を読み書きし、取り込み判定に使用する。
class MetadataManager {
  /// SD カードのルートパス
  final String sdCardRoot;

  /// ロガー
  final _log = LoggingService.instance;

  /// メタデータの内容（メモリ上のキャッシュ）
  ImportMetadata? _metadata;

  /// 最後に読み込んだファイルの更新日時（キャッシュ有効性判定用）
  DateTime? _lastLoadedModified;

  MetadataManager(this.sdCardRoot);

  /// メタデータファイルのパスを取得
  String get metadataFilePath {
    return p.join(sdCardRoot, 'PRIVATE', _metadataFolderName, _metadataFileName);
  }

  /// メタデータフォルダのパスを取得
  String get metadataFolderPath {
    return p.join(sdCardRoot, 'PRIVATE', _metadataFolderName);
  }

  /// メタデータを読み込む
  ///
  /// ファイルが存在しない場合は空のメタデータを返す。
  /// ファイルが破損している場合も空のメタデータを返す（エラーをログに記録）。
  Future<ImportMetadata> load() async {
    final file = File(metadataFilePath);

    // ファイルが存在しない場合は空のメタデータを返す
    if (!await file.exists()) {
      _log.debug(
        'Metadata file does not exist, returning empty metadata: $metadataFilePath.',
        tag: 'MetadataManager',
      );
      _metadata = ImportMetadata.empty();
      _lastLoadedModified = null;
      return _metadata!;
    }

    try {
      // ファイルの更新日時をチェック
      final stat = await file.stat();

      // キャッシュが有効な場合はそれを返す
      if (_metadata != null && _lastLoadedModified != null && stat.modified == _lastLoadedModified) {
        _log.debug('Using cached metadata.', tag: 'MetadataManager');
        return _metadata!;
      }

      // ファイルを読み込んでパース
      _log.debug(
        'Loading metadata from file: $metadataFilePath.',
        tag: 'MetadataManager',
      );
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _metadata = ImportMetadata.fromJson(json);
      _lastLoadedModified = stat.modified;

      _log.info(
        'Metadata loaded: ${_metadata!.files.length} file records.',
        tag: 'MetadataManager',
      );
      return _metadata!;
    } catch (ex, stackTrace) {
      // JSON パースエラーなど - 破損したファイルとして扱う
      // エラーログを記録して空のメタデータを返す
      _log.error(
        'Failed to parse metadata file, treating as empty: $metadataFilePath.',
        tag: 'MetadataManager',
        error: ex,
        stackTrace: stackTrace,
      );
      _metadata = ImportMetadata.empty();
      _lastLoadedModified = null;
      return _metadata!;
    }
  }

  /// メタデータを保存する
  ///
  /// 一時ファイルに書き込んでからリネームすることで、
  /// 書き込み中の強制終了による破損を防止する。
  Future<void> save(ImportMetadata metadata) async {
    final folder = Directory(metadataFolderPath);
    final file = File(metadataFilePath);
    final tempFile = File('$metadataFilePath.tmp');

    _log.debug(
      'Saving metadata to: $metadataFilePath.',
      tag: 'MetadataManager',
    );

    // フォルダを作成（存在しない場合）
    if (!await folder.exists()) {
      _log.debug(
        'Creating metadata folder: $metadataFolderPath.',
        tag: 'MetadataManager',
      );
      await folder.create(recursive: true);
    }

    // JSON に変換（読みやすいフォーマット）
    final encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(metadata.toJson());

    // 一時ファイルに書き込み
    await tempFile.writeAsString(jsonString);

    // 既存ファイルがあれば削除
    if (await file.exists()) {
      await file.delete();
    }

    // 一時ファイルをリネーム
    await tempFile.rename(metadataFilePath);

    // キャッシュを更新
    _metadata = metadata;
    _lastLoadedModified = (await file.stat()).modified;

    _log.info(
      'Metadata saved: ${metadata.files.length} file records.',
      tag: 'MetadataManager',
    );
  }

  /// 単一のレコードを追加して保存
  ///
  /// 既存のメタデータに新しいレコードを追加し、即座に保存する。
  /// 各ファイルのコピー完了後に呼び出すことで、
  /// 中断時も進捗を保持できる。
  Future<void> addRecord(ImportedFileRecord record) async {
    _log.debug(
      'Adding record: ${record.sourcePath}.',
      tag: 'MetadataManager',
    );
    final metadata = await load();
    final updatedMetadata = metadata.upsertRecord(record);
    await save(updatedMetadata);
  }

  /// 複数のレコードを追加して保存
  Future<void> addRecords(List<ImportedFileRecord> records) async {
    if (records.isEmpty) return;

    _log.debug(
      'Adding ${records.length} records.',
      tag: 'MetadataManager',
    );
    final metadata = await load();
    final updatedMetadata = metadata.upsertRecords(records);
    await save(updatedMetadata);
  }

  /// 指定したソースパスのレコードを検索
  ///
  /// 取り込み済みかどうかの判定に使用する。
  Future<ImportedFileRecord?> findRecord(String sourcePath) async {
    final metadata = await load();
    return metadata.findBySourcePath(sourcePath);
  }

  /// 指定したソースパスが取り込み済みかどうかを確認
  Future<bool> isImported(String sourcePath) async {
    final record = await findRecord(sourcePath);
    return record != null;
  }

  /// メタデータファイルが存在するかどうかを確認
  Future<bool> exists() async {
    final file = File(metadataFilePath);
    return file.exists();
  }

  /// キャッシュをクリア
  ///
  /// 次回の load() で必ずファイルから読み込み直す。
  void clearCache() {
    _metadata = null;
    _lastLoadedModified = null;
  }

  /// SD カードが書き込み可能かどうかをテスト
  ///
  /// メタデータフォルダへのファイル作成を試みて判定する。
  Future<bool> isWritable() async {
    _log.debug(
      'Testing write access to: $metadataFolderPath.',
      tag: 'MetadataManager',
    );

    try {
      final folder = Directory(metadataFolderPath);
      final testFile = File(p.join(metadataFolderPath, '.write_test'));

      // フォルダを作成
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      // テストファイルを書き込み
      await testFile.writeAsString('test');
      await testFile.delete();

      _log.debug('Write access test passed.', tag: 'MetadataManager');
      return true;
    } catch (ex) {
      _log.warning(
        'Write access test failed.',
        tag: 'MetadataManager',
        error: ex,
      );
      return false;
    }
  }
}
