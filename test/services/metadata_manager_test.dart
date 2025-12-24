/// メタデータ管理サービスのテスト
///
/// SD カード上の METADATA.JSON ファイルの読み書き機能をテストする。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:alpha_import_utility/models/import_result.dart';
import 'package:alpha_import_utility/services/metadata_manager.dart';
import '../fixtures/test_helper.dart';

void main() {
  group('MetadataManager', () {
    group('load', () {
      test('ファイルが存在しない場合は空のメタデータを返す', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);

          final metadata = await manager.load();

          expect(metadata.files, isEmpty);
          expect(metadata.version, equals('1.0.0'));
        } finally {
          await cleanup();
        }
      });

      test('既存のメタデータファイルを読み込める', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          // メタデータファイルを作成
          await createMockMetadataJson(
            tempDir,
            files: [
              {
                'sourcePath': 'DCIM/100MSDCF/DSC00001.ARW',
                'xxHash': 'a1b2c3d4e5f67890',
                'fileSize': 25165824,
                'importedAt': '2025-12-24T15:28:00.000Z',
                'destinationPath': '2025_12_24/DSC00001.ARW',
                'appVersion': '1.0.0',
              },
            ],
          );

          final manager = MetadataManager(tempDir);
          final metadata = await manager.load();

          expect(metadata.files.length, equals(1));
          expect(metadata.files[0].sourcePath, equals('DCIM/100MSDCF/DSC00001.ARW'));
          expect(metadata.files[0].xxHash, equals('a1b2c3d4e5f67890'));
          expect(metadata.files[0].fileSize, equals(25165824));
          expect(metadata.files[0].destinationPath, equals('2025_12_24/DSC00001.ARW'));
        } finally {
          await cleanup();
        }
      });

      test('破損したファイルの場合は空のメタデータを返す', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          // 破損した JSON ファイルを作成
          final metadataPath = p.join(tempDir, 'PRIVATE', 'AIU', 'METADATA.JSON');
          final metadataFile = File(metadataPath);
          await metadataFile.parent.create(recursive: true);
          await metadataFile.writeAsString('{ invalid json }');

          final manager = MetadataManager(tempDir);
          final metadata = await manager.load();

          // 破損ファイルは空として扱う
          expect(metadata.files, isEmpty);
        } finally {
          await cleanup();
        }
      });

      test('キャッシュが有効な場合はファイルを再読み込みしない', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockMetadataJson(
            tempDir,
            files: [
              {
                'sourcePath': 'DCIM/100MSDCF/DSC00001.ARW',
                'xxHash': 'a1b2c3d4e5f67890',
                'fileSize': 25165824,
                'importedAt': '2025-12-24T15:28:00.000Z',
                'destinationPath': '2025_12_24/DSC00001.ARW',
                'appVersion': '1.0.0',
              },
            ],
          );

          final manager = MetadataManager(tempDir);

          // 1 回目の読み込み
          final metadata1 = await manager.load();
          expect(metadata1.files.length, equals(1));

          // 2 回目の読み込み（キャッシュから）
          final metadata2 = await manager.load();
          expect(metadata2.files.length, equals(1));

          // 同じインスタンスであることを確認
          expect(identical(metadata1, metadata2), isTrue);
        } finally {
          await cleanup();
        }
      });
    });

    group('save', () {
      test('メタデータを保存できる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);
          final metadata = ImportMetadata(
            lastUpdated: DateTime.utc(2025, 12, 24, 15, 30),
            files: [
              ImportedFileRecord(
                sourcePath: 'DCIM/100MSDCF/DSC00001.ARW',
                xxHash: 'a1b2c3d4e5f67890',
                fileSize: 25165824,
                importedAt: DateTime.utc(2025, 12, 24, 15, 28),
                destinationPath: '2025_12_24/DSC00001.ARW',
                appVersion: '1.0.0',
              ),
            ],
          );

          await manager.save(metadata);

          // ファイルが作成されていることを確認
          final file = File(manager.metadataFilePath);
          expect(await file.exists(), isTrue);

          // 内容を確認
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          expect(json['version'], equals('1.0.0'));
          expect((json['files'] as List).length, equals(1));
        } finally {
          await cleanup();
        }
      });

      test('保存後に再読み込みできる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);
          final originalMetadata = ImportMetadata(
            lastUpdated: DateTime.utc(2025, 12, 24, 15, 30),
            files: [
              ImportedFileRecord(
                sourcePath: 'DCIM/100MSDCF/DSC00001.ARW',
                xxHash: 'a1b2c3d4e5f67890',
                fileSize: 25165824,
                importedAt: DateTime.utc(2025, 12, 24, 15, 28),
                destinationPath: '2025_12_24/DSC00001.ARW',
                appVersion: '1.0.0',
              ),
            ],
          );

          await manager.save(originalMetadata);

          // 新しいマネージャーで読み込み
          final manager2 = MetadataManager(tempDir);
          final loadedMetadata = await manager2.load();

          expect(loadedMetadata.files.length, equals(1));
          expect(loadedMetadata.files[0].sourcePath, equals('DCIM/100MSDCF/DSC00001.ARW'));
          expect(loadedMetadata.files[0].xxHash, equals('a1b2c3d4e5f67890'));
        } finally {
          await cleanup();
        }
      });

      test('フォルダが存在しない場合は自動作成される', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);
          final metadata = ImportMetadata.empty();

          // PRIVATE/AIU フォルダが存在しない状態で保存
          await manager.save(metadata);

          // ファイルが作成されていることを確認
          expect(await File(manager.metadataFilePath).exists(), isTrue);
        } finally {
          await cleanup();
        }
      });
    });

    group('addRecord', () {
      test('レコードを追加して保存できる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);
          final record = ImportedFileRecord(
            sourcePath: 'DCIM/100MSDCF/DSC00001.ARW',
            xxHash: 'a1b2c3d4e5f67890',
            fileSize: 25165824,
            importedAt: DateTime.utc(2025, 12, 24, 15, 28),
            destinationPath: '2025_12_24/DSC00001.ARW',
            appVersion: '1.0.0',
          );

          await manager.addRecord(record);

          // 保存されていることを確認
          final metadata = await manager.load();
          expect(metadata.files.length, equals(1));
          expect(metadata.files[0].sourcePath, equals('DCIM/100MSDCF/DSC00001.ARW'));
        } finally {
          await cleanup();
        }
      });

      test('複数のレコードを順番に追加できる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);

          // 1 つ目のレコードを追加
          await manager.addRecord(
            ImportedFileRecord(
              sourcePath: 'DCIM/100MSDCF/DSC00001.ARW',
              xxHash: 'hash1',
              fileSize: 1000,
              importedAt: DateTime.utc(2025, 12, 24),
              destinationPath: '2025_12_24/DSC00001.ARW',
              appVersion: '1.0.0',
            ),
          );

          // 2 つ目のレコードを追加
          await manager.addRecord(
            ImportedFileRecord(
              sourcePath: 'DCIM/100MSDCF/DSC00002.ARW',
              xxHash: 'hash2',
              fileSize: 2000,
              importedAt: DateTime.utc(2025, 12, 24),
              destinationPath: '2025_12_24/DSC00002.ARW',
              appVersion: '1.0.0',
            ),
          );

          final metadata = await manager.load();
          expect(metadata.files.length, equals(2));
        } finally {
          await cleanup();
        }
      });
    });

    group('addRecords', () {
      test('複数のレコードを一括追加できる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);
          final records = [
            ImportedFileRecord(
              sourcePath: 'DCIM/100MSDCF/DSC00001.ARW',
              xxHash: 'hash1',
              fileSize: 1000,
              importedAt: DateTime.utc(2025, 12, 24),
              destinationPath: '2025_12_24/DSC00001.ARW',
              appVersion: '1.0.0',
            ),
            ImportedFileRecord(
              sourcePath: 'DCIM/100MSDCF/DSC00002.ARW',
              xxHash: 'hash2',
              fileSize: 2000,
              importedAt: DateTime.utc(2025, 12, 24),
              destinationPath: '2025_12_24/DSC00002.ARW',
              appVersion: '1.0.0',
            ),
          ];

          await manager.addRecords(records);

          final metadata = await manager.load();
          expect(metadata.files.length, equals(2));
        } finally {
          await cleanup();
        }
      });

      test('空のリストを追加しても問題ない', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);

          // 空のリストを追加
          await manager.addRecords([]);

          // エラーなく完了し、ファイルは存在しない
          expect(await manager.exists(), isFalse);
        } finally {
          await cleanup();
        }
      });
    });

    group('findRecord', () {
      test('存在するレコードを検索できる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockMetadataJson(
            tempDir,
            files: [
              {
                'sourcePath': 'DCIM/100MSDCF/DSC00001.ARW',
                'xxHash': 'a1b2c3d4e5f67890',
                'fileSize': 25165824,
                'importedAt': '2025-12-24T15:28:00.000Z',
                'destinationPath': '2025_12_24/DSC00001.ARW',
                'appVersion': '1.0.0',
              },
            ],
          );

          final manager = MetadataManager(tempDir);
          final record = await manager.findRecord('DCIM/100MSDCF/DSC00001.ARW');

          expect(record, isNotNull);
          expect(record!.xxHash, equals('a1b2c3d4e5f67890'));
        } finally {
          await cleanup();
        }
      });

      test('存在しないレコードは null を返す', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockMetadataJson(tempDir);

          final manager = MetadataManager(tempDir);
          final record = await manager.findRecord('DCIM/100MSDCF/DSC00001.ARW');

          expect(record, isNull);
        } finally {
          await cleanup();
        }
      });
    });

    group('isImported', () {
      test('取り込み済みのファイルは true を返す', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockMetadataJson(
            tempDir,
            files: [
              {
                'sourcePath': 'DCIM/100MSDCF/DSC00001.ARW',
                'xxHash': 'a1b2c3d4e5f67890',
                'fileSize': 25165824,
                'importedAt': '2025-12-24T15:28:00.000Z',
                'destinationPath': '2025_12_24/DSC00001.ARW',
                'appVersion': '1.0.0',
              },
            ],
          );

          final manager = MetadataManager(tempDir);
          final imported = await manager.isImported('DCIM/100MSDCF/DSC00001.ARW');

          expect(imported, isTrue);
        } finally {
          await cleanup();
        }
      });

      test('未取り込みのファイルは false を返す', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockMetadataJson(tempDir);

          final manager = MetadataManager(tempDir);
          final imported = await manager.isImported('DCIM/100MSDCF/DSC00001.ARW');

          expect(imported, isFalse);
        } finally {
          await cleanup();
        }
      });
    });

    group('exists', () {
      test('ファイルが存在する場合は true を返す', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockMetadataJson(tempDir);

          final manager = MetadataManager(tempDir);
          final exists = await manager.exists();

          expect(exists, isTrue);
        } finally {
          await cleanup();
        }
      });

      test('ファイルが存在しない場合は false を返す', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);
          final exists = await manager.exists();

          expect(exists, isFalse);
        } finally {
          await cleanup();
        }
      });
    });

    group('clearCache', () {
      test('キャッシュをクリアすると次回はファイルから読み込む', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockMetadataJson(
            tempDir,
            files: [
              {
                'sourcePath': 'DCIM/100MSDCF/DSC00001.ARW',
                'xxHash': 'a1b2c3d4e5f67890',
                'fileSize': 25165824,
                'importedAt': '2025-12-24T15:28:00.000Z',
                'destinationPath': '2025_12_24/DSC00001.ARW',
                'appVersion': '1.0.0',
              },
            ],
          );

          final manager = MetadataManager(tempDir);

          // 1 回目の読み込み
          final metadata1 = await manager.load();

          // キャッシュをクリア
          manager.clearCache();

          // 2 回目の読み込み
          final metadata2 = await manager.load();

          // 異なるインスタンスであることを確認
          expect(identical(metadata1, metadata2), isFalse);
        } finally {
          await cleanup();
        }
      });
    });

    group('isWritable', () {
      test('書き込み可能な場合は true を返す', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final manager = MetadataManager(tempDir);
          final writable = await manager.isWritable();

          expect(writable, isTrue);
        } finally {
          await cleanup();
        }
      });
    });

    group('metadataFilePath', () {
      test('正しいパスを返す', () {
        final manager = MetadataManager('/sd_card');
        expect(
          manager.metadataFilePath,
          equals(p.join('/sd_card', 'PRIVATE', 'AIU', 'METADATA.JSON')),
        );
      });
    });
  });

  group('ImportMetadata', () {
    test('empty factory は空のメタデータを作成する', () {
      final metadata = ImportMetadata.empty();

      expect(metadata.files, isEmpty);
      expect(metadata.version, equals('1.0.0'));
    });

    test('findBySourcePath は存在するレコードを返す', () {
      final metadata = ImportMetadata(
        lastUpdated: DateTime.utc(2025, 12, 24),
        files: [
          ImportedFileRecord(
            sourcePath: 'DCIM/100MSDCF/DSC00001.ARW',
            xxHash: 'hash1',
            fileSize: 1000,
            importedAt: DateTime.utc(2025, 12, 24),
            destinationPath: '2025_12_24/DSC00001.ARW',
            appVersion: '1.0.0',
          ),
        ],
      );

      final record = metadata.findBySourcePath('DCIM/100MSDCF/DSC00001.ARW');

      expect(record, isNotNull);
      expect(record!.xxHash, equals('hash1'));
    });

    test('findBySourcePath は存在しないパスで null を返す', () {
      final metadata = ImportMetadata.empty();

      final record = metadata.findBySourcePath('non/existent/path');

      expect(record, isNull);
    });

    test('addRecord は新しいメタデータを返す', () {
      final original = ImportMetadata.empty();
      final record = ImportedFileRecord(
        sourcePath: 'DCIM/100MSDCF/DSC00001.ARW',
        xxHash: 'hash1',
        fileSize: 1000,
        importedAt: DateTime.utc(2025, 12, 24),
        destinationPath: '2025_12_24/DSC00001.ARW',
        appVersion: '1.0.0',
      );

      final updated = original.addRecord(record);

      expect(updated.files.length, equals(1));
      expect(original.files.length, equals(0)); // 元は変更されない
    });

    test('addRecords は複数のレコードを追加できる', () {
      final original = ImportMetadata.empty();
      final records = [
        ImportedFileRecord(
          sourcePath: 'DCIM/100MSDCF/DSC00001.ARW',
          xxHash: 'hash1',
          fileSize: 1000,
          importedAt: DateTime.utc(2025, 12, 24),
          destinationPath: '2025_12_24/DSC00001.ARW',
          appVersion: '1.0.0',
        ),
        ImportedFileRecord(
          sourcePath: 'DCIM/100MSDCF/DSC00002.ARW',
          xxHash: 'hash2',
          fileSize: 2000,
          importedAt: DateTime.utc(2025, 12, 24),
          destinationPath: '2025_12_24/DSC00002.ARW',
          appVersion: '1.0.0',
        ),
      ];

      final updated = original.addRecords(records);

      expect(updated.files.length, equals(2));
    });
  });

  group('ImportedFileRecord', () {
    test('JSON シリアライズ・デシリアライズが正しく動作する', () {
      final original = ImportedFileRecord(
        sourcePath: 'DCIM/100MSDCF/DSC00001.ARW',
        xxHash: 'a1b2c3d4e5f67890',
        fileSize: 25165824,
        importedAt: DateTime.utc(2025, 12, 24, 15, 28),
        destinationPath: '2025_12_24/DSC00001.ARW',
        appVersion: '1.0.0',
      );

      final json = original.toJson();
      final restored = ImportedFileRecord.fromJson(json);

      expect(restored.sourcePath, equals(original.sourcePath));
      expect(restored.xxHash, equals(original.xxHash));
      expect(restored.fileSize, equals(original.fileSize));
      expect(restored.destinationPath, equals(original.destinationPath));
      expect(restored.appVersion, equals(original.appVersion));
    });
  });
}
