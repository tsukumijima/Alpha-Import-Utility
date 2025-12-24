/// テストヘルパー
///
/// テスト用のモック SD カード構造を動的に作成・削除するヘルパー関数。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// テスト用の一時ディレクトリを作成
///
/// テスト終了後に削除するためのクリーンアップ関数も返す。
Future<(String, Future<void> Function())> createTempDirectory() async {
  final tempDir = await Directory.systemTemp.createTemp('alpha_import_test_');
  return (
    tempDir.path,
    () async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    },
  );
}

/// モック Sony SD カード構造を作成
///
/// 指定されたディレクトリに Sony α カメラの SD カード構造を作成する。
Future<void> createMockSdCardStructure(
  String rootPath, {
  bool createDcim = true,
  bool createMsdcfFolder = true,
  bool createM4root = true,
  bool createClip = true,
  bool createSub = false,
  List<MockMediaFile> mockFiles = const [],
}) async {
  // DCIM フォルダ
  if (createDcim) {
    final dcimPath = p.join(rootPath, 'DCIM');
    await Directory(dcimPath).create(recursive: true);

    if (createMsdcfFolder) {
      final msdcfPath = p.join(dcimPath, '100MSDCF');
      await Directory(msdcfPath).create();
    }
  }

  // PRIVATE/M4ROOT フォルダ
  if (createM4root) {
    final m4rootPath = p.join(rootPath, 'PRIVATE', 'M4ROOT');
    await Directory(m4rootPath).create(recursive: true);

    if (createClip) {
      final clipPath = p.join(m4rootPath, 'CLIP');
      await Directory(clipPath).create();
    }

    if (createSub) {
      final subPath = p.join(m4rootPath, 'SUB');
      await Directory(subPath).create();
    }
  }

  // モックファイルを作成
  for (final mockFile in mockFiles) {
    await mockFile.create(rootPath);
  }
}

/// モックメディアファイル
class MockMediaFile {
  /// ルートからの相対パス
  final String relativePath;

  /// ファイルサイズ（バイト）
  final int size;

  /// ファイルの更新日時
  ///
  /// 未指定の場合は現在時刻から 1 分前に設定する。
  final DateTime? modifiedTime;

  const MockMediaFile({
    required this.relativePath,
    this.size = 1024,
    this.modifiedTime,
  });

  /// ファイルを作成
  Future<void> create(String rootPath) async {
    final filePath = p.join(rootPath, relativePath);
    final file = File(filePath);

    // 親ディレクトリを作成
    await file.parent.create(recursive: true);

    // ダミーデータを書き込み
    final data = Uint8List(size);
    for (var i = 0; i < size; i++) {
      data[i] = i % 256;
    }
    await file.writeAsBytes(data);

    // 更新日時を設定
    final targetModifiedTime = modifiedTime ?? DateTime.now().subtract(const Duration(minutes: 1));
    await file.setLastModified(targetModifiedTime);
  }

  /// JPEG ファイルのモック
  static MockMediaFile jpeg(String name, {int size = 5 * 1024 * 1024}) {
    return MockMediaFile(
      relativePath: 'DCIM/100MSDCF/$name.JPG',
      size: size,
    );
  }

  /// ARW ファイルのモック
  static MockMediaFile arw(String name, {int size = 25 * 1024 * 1024}) {
    return MockMediaFile(
      relativePath: 'DCIM/100MSDCF/$name.ARW',
      size: size,
    );
  }

  /// MP4 動画ファイルのモック
  static MockMediaFile video(String name, {int size = 100 * 1024 * 1024}) {
    return MockMediaFile(
      relativePath: 'PRIVATE/M4ROOT/CLIP/$name.MP4',
      size: size,
    );
  }

  /// プロキシ動画ファイルのモック
  static MockMediaFile proxyVideo(String name, {int size = 10 * 1024 * 1024}) {
    return MockMediaFile(
      relativePath: 'PRIVATE/M4ROOT/SUB/$name.MP4',
      size: size,
    );
  }

  /// XML メタデータファイルのモック
  static MockMediaFile videoMeta(String name) {
    return MockMediaFile(
      relativePath: 'PRIVATE/M4ROOT/CLIP/${name}M01.XML',
      size: 2048,
    );
  }
}

/// テスト用の METADATA.JSON を作成
Future<void> createMockMetadataJson(
  String rootPath, {
  List<Map<String, dynamic>> files = const [],
}) async {
  final metadataPath = p.join(rootPath, 'PRIVATE', 'AIU', 'METADATA.JSON');
  final metadataFile = File(metadataPath);

  await metadataFile.parent.create(recursive: true);

  final content =
      '''
{
  "version": "1.0.0",
  "lastUpdated": "${DateTime.now().toUtc().toIso8601String()}",
  "files": ${_filesToJson(files)}
}
''';

  await metadataFile.writeAsString(content);
}

/// メタデータの files 配列を JSON 文字列に変換する
String _filesToJson(List<Map<String, dynamic>> files) {
  if (files.isEmpty) return '[]';

  final buffer = StringBuffer('[');
  for (var i = 0; i < files.length; i++) {
    if (i > 0) buffer.write(',');
    buffer.write('\n    ');
    buffer.write(_mapToJson(files[i]));
  }
  buffer.write('\n  ]');
  return buffer.toString();
}

/// Map を JSON 文字列に変換する
String _mapToJson(Map<String, dynamic> map) {
  final entries = map.entries
      .map((e) {
        final value = e.value is String ? '"${e.value}"' : e.value;
        return '"${e.key}": $value';
      })
      .join(', ');
  return '{$entries}';
}
