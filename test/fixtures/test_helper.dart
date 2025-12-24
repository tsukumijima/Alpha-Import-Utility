/// テストヘルパー
///
/// テスト用のモック SD カード構造を動的に作成・削除するヘルパー関数。
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// ファイル日時操作の MethodChannel をモックする
///
/// Windows/macOS のネイティブ実装が無いテスト環境でも
/// FileTimeService を安全に利用できるようにする。
void setUpFileTimeServiceMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('alpha_import_utility/file_time');
  final creationTimes = <String, int>{};

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    final args = call.arguments as Map<dynamic, dynamic>? ?? {};
    final path = args['path'] as String?;
    if (path == null || path.isEmpty) {
      throw PlatformException(code: 'INVALID_ARGS', message: 'Missing path.');
    }

    switch (call.method) {
      case 'setFileTimes':
        final creationMs = args['creationTimeUtcMs'] as int?;
        final modifiedMs = args['modifiedTimeUtcMs'] as int?;
        if (creationMs == null || modifiedMs == null) {
          throw PlatformException(code: 'INVALID_ARGS', message: 'Missing times.');
        }
        creationTimes[path] = creationMs;
        final file = File(path);
        if (await file.exists()) {
          await file.setLastModified(
            DateTime.fromMillisecondsSinceEpoch(modifiedMs, isUtc: true),
          );
        }
        return null;
      case 'getFileTimes':
        final file = File(path);
        final stat = await file.stat();
        final creationMs = creationTimes[path] ?? stat.modified.toUtc().millisecondsSinceEpoch;
        final modifiedMs = stat.modified.toUtc().millisecondsSinceEpoch;
        return {
          'creationTimeUtcMs': creationMs,
          'modifiedTimeUtcMs': modifiedMs,
        };
      case 'getAvailableDiskSpace':
        return 1024 * 1024 * 1024 * 1024;
      default:
        throw PlatformException(
          code: 'NOT_IMPLEMENTED',
          message: 'Method not implemented.',
        );
    }
  });
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

/// sample_media を SD カード構造にコピーする
///
/// [includeProxy] が true の場合は SUB にプロキシー動画も配置する。
/// [copiesPerFile] を指定すると、同じファイルを別名で複製して配置する。
/// 種別ごとの水増し数を指定したい場合は [photoCopiesPerFile] などを使用する。
Future<void> createSdCardFromSampleMedia(
  String rootPath, {
  bool includeProxy = true,
  int copiesPerFile = 1,
  int? photoCopiesPerFile,
  int? videoCopiesPerFile,
  int? proxyCopiesPerFile,
  int? xmlCopiesPerFile,
}) async {
  final sampleDir = Directory(p.join('test', 'fixtures', 'sample_media'));
  if (!sampleDir.existsSync()) {
    return;
  }

  await createMockSdCardStructure(
    rootPath,
    createSub: includeProxy,
  );

  final dcimPath = p.join(rootPath, 'DCIM', '100MSDCF');
  final clipPath = p.join(rootPath, 'PRIVATE', 'M4ROOT', 'CLIP');
  final subPath = p.join(rootPath, 'PRIVATE', 'M4ROOT', 'SUB');

  final files = sampleDir.listSync().whereType<File>().toList();
  for (final file in files) {
    final fileName = p.basename(file.path);
    final extension = p.extension(file.path).toLowerCase();

    String? targetDir;
    var copyCount = copiesPerFile;
    if (extension == '.jpg' ||
        extension == '.jpeg' ||
        extension == '.arw' ||
        extension == '.hif' ||
        extension == '.heif') {
      targetDir = dcimPath;
      copyCount = photoCopiesPerFile ?? copiesPerFile;
    } else if (extension == '.xml') {
      targetDir = clipPath;
      copyCount = xmlCopiesPerFile ?? copiesPerFile;
    } else if (extension == '.mp4') {
      if (fileName.toUpperCase().contains('S03') && includeProxy) {
        targetDir = subPath;
        copyCount = proxyCopiesPerFile ?? copiesPerFile;
      } else {
        targetDir = clipPath;
        copyCount = videoCopiesPerFile ?? copiesPerFile;
      }
    }

    if (targetDir == null) {
      continue;
    }

    await Directory(targetDir).create(recursive: true);
    for (var copyIndex = 0; copyIndex < copyCount; copyIndex++) {
      final copyName = copyIndex == 0
          ? fileName
          : '${p.basenameWithoutExtension(fileName)}_copy$copyIndex${p.extension(fileName)}';
      await file.copy(p.join(targetDir, copyName));
    }
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
