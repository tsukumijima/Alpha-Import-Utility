/// Sony α SD カードのファイルシステム判定・スキャン機能
///
/// Sony α カメラで使用される SD カードの構造を検証し、
/// 取り込み対象のメディアファイルを列挙する。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/media_file.dart';
import '../models/settings.dart';
import '../utils/exif_utils.dart';
import '../utils/file_utils.dart';

/// Sony SD カード構造の検証結果
class SonyFilesystemValidation {
  /// 検証が成功したかどうか
  final bool isValid;

  /// DCIM フォルダが存在するか
  final bool hasDcimFolder;

  /// MSDCF パターンのフォルダが存在するか
  final bool hasMsdcfFolder;

  /// PRIVATE/M4ROOT/CLIP フォルダが存在するか
  final bool hasClipFolder;

  /// エラーメッセージ（検証失敗時のみ）
  final String? errorMessage;

  /// 検出された MSDCF フォルダの一覧
  final List<String> msdcfFolders;

  SonyFilesystemValidation({
    required this.isValid,
    required this.hasDcimFolder,
    required this.hasMsdcfFolder,
    required this.hasClipFolder,
    this.errorMessage,
    this.msdcfFolders = const [],
  });

  /// 成功の検証結果を作成
  factory SonyFilesystemValidation.success({
    required List<String> msdcfFolders,
  }) {
    return SonyFilesystemValidation(
      isValid: true,
      hasDcimFolder: true,
      hasMsdcfFolder: true,
      hasClipFolder: true,
      msdcfFolders: msdcfFolders,
    );
  }

  /// 失敗の検証結果を作成
  factory SonyFilesystemValidation.failure({
    required String errorMessage,
    bool hasDcimFolder = false,
    bool hasMsdcfFolder = false,
    bool hasClipFolder = false,
  }) {
    return SonyFilesystemValidation(
      isValid: false,
      hasDcimFolder: hasDcimFolder,
      hasMsdcfFolder: hasMsdcfFolder,
      hasClipFolder: hasClipFolder,
      errorMessage: errorMessage,
    );
  }
}

/// Sony α SD カードのファイルシステム操作を行うサービス
class SonyFilesystemService {
  /// SD カードのルートパス
  final String rootPath;

  SonyFilesystemService(this.rootPath);

  /// MSDCF フォルダ名のパターン（例: 100MSDCF, 101MSDCF）
  static final RegExp _msdcfPattern = RegExp(r'^\d{3}MSDCF$', caseSensitive: false);

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
  /// 2. DCIM/ 配下に [0-9]{3}MSDCF パターンのフォルダが 1 つ以上存在する
  /// 3. PRIVATE/M4ROOT/CLIP/ フォルダが存在する
  Future<SonyFilesystemValidation> validate() async {
    final rootDir = Directory(rootPath);

    if (!await rootDir.exists()) {
      return SonyFilesystemValidation.failure(
        errorMessage: 'Root path does not exist: $rootPath',
      );
    }

    // DCIM フォルダの確認（大文字小文字非依存）
    final dcimPath = await _findCaseInsensitiveDirectory(rootPath, 'DCIM');
    if (dcimPath == null) {
      return SonyFilesystemValidation.failure(
        errorMessage: 'DCIM folder not found',
      );
    }

    // MSDCF パターンフォルダの確認
    final msdcfFolders = await _findMsdcfFolders(dcimPath);
    if (msdcfFolders.isEmpty) {
      return SonyFilesystemValidation.failure(
        errorMessage: 'No xxxMSDCF folder found in DCIM',
        hasDcimFolder: true,
      );
    }

    // PRIVATE/M4ROOT/CLIP フォルダの確認
    final privatePath = await _findCaseInsensitiveDirectory(rootPath, 'PRIVATE');
    if (privatePath == null) {
      return SonyFilesystemValidation.failure(
        errorMessage: 'PRIVATE folder not found',
        hasDcimFolder: true,
        hasMsdcfFolder: true,
      );
    }

    final m4rootPath = await _findCaseInsensitiveDirectory(privatePath, 'M4ROOT');
    if (m4rootPath == null) {
      return SonyFilesystemValidation.failure(
        errorMessage: 'PRIVATE/M4ROOT folder not found',
        hasDcimFolder: true,
        hasMsdcfFolder: true,
      );
    }

    final clipPath = await _findCaseInsensitiveDirectory(m4rootPath, 'CLIP');
    if (clipPath == null) {
      return SonyFilesystemValidation.failure(
        errorMessage: 'PRIVATE/M4ROOT/CLIP folder not found',
        hasDcimFolder: true,
        hasMsdcfFolder: true,
      );
    }

    return SonyFilesystemValidation.success(msdcfFolders: msdcfFolders);
  }

  /// 大文字小文字を区別せずにディレクトリを検索
  Future<String?> _findCaseInsensitiveDirectory(
    String parentPath,
    String targetName,
  ) async {
    final parentDir = Directory(parentPath);
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
    } catch (_) {
      // ディレクトリ読み取りエラー
    }

    return null;
  }

  /// MSDCF パターンに一致するフォルダを検索
  Future<List<String>> _findMsdcfFolders(String dcimPath) async {
    final folders = <String>[];
    final dcimDir = Directory(dcimPath);

    try {
      await for (final entity in dcimDir.list()) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (_msdcfPattern.hasMatch(name)) {
            folders.add(entity.path);
          }
        }
      }

      // フォルダ番号順にソート（100MSDCF, 101MSDCF, ...）
      folders.sort((a, b) {
        final aName = p.basename(a).toUpperCase();
        final bName = p.basename(b).toUpperCase();
        return aName.compareTo(bName);
      });
    } catch (_) {
      // ディレクトリ読み取りエラー
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
  Future<List<MediaFile>> scanMediaFiles(ImportSettings settings) async {
    final validation = await validate();
    if (!validation.isValid) {
      throw Exception('Invalid Sony SD card structure: ${validation.errorMessage}');
    }

    final mediaFiles = <MediaFile>[];

    // 1. DCIM フォルダ内の静止画をスキャン
    for (final msdcfPath in validation.msdcfFolders) {
      final photos = await _scanPhotosInFolder(msdcfPath);
      mediaFiles.addAll(photos);
    }

    // 2. PRIVATE/M4ROOT/CLIP 内の動画をスキャン
    final clipPath = await _getClipPath();
    if (clipPath != null) {
      final videos = await _scanVideosInFolder(
        clipPath,
        isProxyFolder: false,
        includeXml: settings.isImportVideoXML,
      );
      mediaFiles.addAll(videos);
    }

    // 3. PRIVATE/M4ROOT/SUB 内のプロキシ動画をスキャン（設定で有効な場合）
    if (settings.isImportProxyVideos) {
      final subPath = await _getSubPath();
      if (subPath != null) {
        final proxyVideos = await _scanVideosInFolder(
          subPath,
          isProxyFolder: true,
          includeXml: false, // SUB フォルダの XML は取り込まない
        );
        mediaFiles.addAll(proxyVideos);
      }
    }

    return mediaFiles;
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

  /// フォルダ内の静止画をスキャン
  Future<List<MediaFile>> _scanPhotosInFolder(String folderPath) async {
    final files = <MediaFile>[];
    final dir = Directory(folderPath);

    try {
      final entities = await dir.list().toList();

      // ファイル名でソート
      entities.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);

          // OS 生成ファイルをスキップ
          if (isOsGeneratedFile(fileName)) continue;

          final ext = getExtension(fileName).toLowerCase();
          if (_photoExtensions.contains(ext)) {
            final mediaFile = await _createMediaFile(entity, isProxyFolder: false);
            if (mediaFile != null) {
              files.add(mediaFile);
            }
          }
        }
      }
    } catch (_) {
      // フォルダ読み取りエラー
    }

    return files;
  }

  /// フォルダ内の動画をスキャン
  Future<List<MediaFile>> _scanVideosInFolder(
    String folderPath, {
    required bool isProxyFolder,
    required bool includeXml,
  }) async {
    final files = <MediaFile>[];
    final dir = Directory(folderPath);

    try {
      final entities = await dir.list().toList();

      // ファイル名でソート
      entities.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);

          // OS 生成ファイルをスキップ
          if (isOsGeneratedFile(fileName)) continue;

          final ext = getExtension(fileName).toLowerCase();

          // 動画ファイル
          if (_videoExtensions.contains(ext)) {
            final mediaFile = await _createMediaFile(entity, isProxyFolder: isProxyFolder);
            if (mediaFile != null) {
              files.add(mediaFile);
            }
          }
          // XML ファイル（設定で有効な場合のみ）
          else if (includeXml && _metaExtensions.contains(ext)) {
            final mediaFile = await _createMediaFile(entity, isProxyFolder: false);
            if (mediaFile != null) {
              files.add(mediaFile);
            }
          }
        }
      }
    } catch (_) {
      // フォルダ読み取りエラー
    }

    return files;
  }

  /// MediaFile オブジェクトを作成
  Future<MediaFile?> _createMediaFile(File file, {required bool isProxyFolder}) async {
    try {
      final fileName = p.basename(file.path);
      final ext = getExtension(fileName);
      final baseName = getBaseName(fileName);

      // メディアタイプを判定
      final mediaType = MediaTypeExtension.fromExtension(ext, isProxyFolder: isProxyFolder);
      if (mediaType == null) return null;

      // ファイル情報を取得
      final stat = await file.stat();
      final relativePath = _getRelativePath(file.path);

      // EXIF/メタデータから日時を取得
      DateTime? exifDateTime;
      if (mediaType.isPhoto) {
        final exifData = await readExifDateTime(file);
        exifDateTime = exifData.bestDateTime;
      } else if (mediaType == MediaType.Video) {
        exifDateTime = await readVideoDateTime(file);
      }

      return MediaFile(
        relativePath: relativePath,
        fileName: fileName,
        baseName: baseName,
        extension: ext,
        type: mediaType,
        fileSize: stat.size,
        exifDateTime: exifDateTime,
        fileModifiedTime: stat.modified,
        sdCardRoot: rootPath,
      );
    } catch (_) {
      // ファイル情報取得エラー
      return null;
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
