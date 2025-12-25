/// Sony ファイルシステムサービスのテスト
///
/// SD カード構造の検証とメディアファイルスキャン機能をテストする。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:alpha_import_utility/models/media_file.dart';
import 'package:alpha_import_utility/models/import_result.dart';
import 'package:alpha_import_utility/models/settings.dart';
import 'package:alpha_import_utility/services/sony_filesystem.dart';
import 'package:alpha_import_utility/utils/exif_utils.dart';
import 'package:alpha_import_utility/utils/timezone_utils.dart';
import '../fixtures/test_helper.dart';

void main() {
  setUpAll(() {
    setUpFileTimeServiceMocks();
  });

  group('SonyFilesystemService', () {
    group('validate', () {
      test('正常な Sony SD カード構造を検証できる', () async {
        // Arrange: 一時ディレクトリにモック SD カード構造を作成
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(tempDir);
          final service = SonyFilesystemService(tempDir);

          // Act
          final validation = await service.validate();

          // Assert
          expect(validation.isValid, isTrue);
          expect(validation.hasDcimFolder, isTrue);
          expect(validation.hasDcfFolder, isTrue);
          expect(validation.hasClipFolder, isTrue);
          expect(validation.errorMessage, isNull);
          expect(validation.dcfFolders, isNotEmpty);
        } finally {
          await cleanup();
        }
      });

      test('DCIM フォルダがない場合は失敗する', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          // DCIM なしで作成
          await createMockSdCardStructure(tempDir, createDcim: false);
          final service = SonyFilesystemService(tempDir);

          final validation = await service.validate();

          expect(validation.isValid, isFalse);
          expect(validation.hasDcimFolder, isFalse);
          expect(validation.errorMessage, contains('DCIM'));
        } finally {
          await cleanup();
        }
      });

      test('DCF フォルダがない場合は失敗する', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          // DCF フォルダなしで作成
          await createMockSdCardStructure(tempDir, createMsdcfFolder: false);
          final service = SonyFilesystemService(tempDir);

          final validation = await service.validate();

          expect(validation.isValid, isFalse);
          expect(validation.hasDcimFolder, isTrue);
          expect(validation.hasDcfFolder, isFalse);
          expect(validation.errorMessage, contains('DCF'));
        } finally {
          await cleanup();
        }
      });

      test('M4ROOT/CLIP フォルダがない場合は失敗する', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          // CLIP なしで作成
          await createMockSdCardStructure(
            tempDir,
            createM4root: true,
            createClip: false,
          );
          final service = SonyFilesystemService(tempDir);

          final validation = await service.validate();

          expect(validation.isValid, isFalse);
          expect(validation.hasDcimFolder, isTrue);
          expect(validation.hasDcfFolder, isTrue);
          expect(validation.hasClipFolder, isFalse);
          expect(validation.errorMessage, contains('CLIP'));
        } finally {
          await cleanup();
        }
      });

      test('M4ROOT フォルダがない場合は失敗する', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          // M4ROOT なしで作成（PRIVATE フォルダも作成されない）
          await createMockSdCardStructure(tempDir, createM4root: false);
          final service = SonyFilesystemService(tempDir);

          final validation = await service.validate();

          expect(validation.isValid, isFalse);
          expect(validation.hasDcimFolder, isTrue);
          expect(validation.hasDcfFolder, isTrue);
          expect(validation.hasClipFolder, isFalse);
          // M4ROOT がない設定では PRIVATE フォルダも作成されないため、
          // PRIVATE または M4ROOT を含むエラーメッセージになる
          expect(
            validation.errorMessage!.contains('PRIVATE') || validation.errorMessage!.contains('M4ROOT'),
            isTrue,
          );
        } finally {
          await cleanup();
        }
      });

      test('存在しないパスでは失敗する', () async {
        final service = SonyFilesystemService('/non/existent/path');

        final validation = await service.validate();

        expect(validation.isValid, isFalse);
        expect(validation.errorMessage, contains('does not exist'));
      });
    });

    group('scanMediaFiles', () {
      test('JPEG ファイルをスキャンできる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.jpeg('DSC00001'),
              MockMediaFile.jpeg('DSC00002'),
            ],
          );
          final service = SonyFilesystemService(tempDir);
          final settings = ImportSettings.defaults();

          final scanResult = await service.scanMediaFiles(settings);
          final files = scanResult.mediaFiles;

          expect(files.length, equals(2));
          expect(files.every((file) => file.type == MediaType.JPEGPhoto), isTrue);
          expect(
            files.map((file) => file.fileName).toList(),
            containsAll(<String>[
              'DSC00001.JPG',
              'DSC00002.JPG',
            ]),
          );
        } finally {
          await cleanup();
        }
      });

      test('ARW ファイルをスキャンできる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.arw('DSC00001'),
              MockMediaFile.arw('DSC00002'),
            ],
          );
          final service = SonyFilesystemService(tempDir);
          final settings = ImportSettings.defaults();

          final scanResult = await service.scanMediaFiles(settings);
          final files = scanResult.mediaFiles;

          expect(files.length, equals(2));
          expect(files.every((file) => file.type == MediaType.RAWPhoto), isTrue);
          expect(
            files.map((file) => file.fileName).toList(),
            containsAll(<String>[
              'DSC00001.ARW',
              'DSC00002.ARW',
            ]),
          );
        } finally {
          await cleanup();
        }
      });

      test('動画ファイルをスキャンできる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.video('C0001'),
              MockMediaFile.video('C0002'),
            ],
          );
          final service = SonyFilesystemService(tempDir);
          final settings = ImportSettings.defaults();

          final scanResult = await service.scanMediaFiles(settings);
          final files = scanResult.mediaFiles;

          expect(files.length, equals(2));
          expect(files.every((file) => file.type == MediaType.Video), isTrue);
          expect(
            files.map((file) => file.fileName).toList(),
            containsAll(<String>[
              'C0001.MP4',
              'C0002.MP4',
            ]),
          );
        } finally {
          await cleanup();
        }
      });

      test('プロキシ動画のスキャンは設定で切り替えられる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(
            tempDir,
            createSub: true,
            mockFiles: [
              MockMediaFile.video('C0001'),
              MockMediaFile.proxyVideo('C0001S03'),
            ],
          );
          final service = SonyFilesystemService(tempDir);

          // プロキシ動画を取り込む設定
          final settingsWithProxy = ImportSettings(
            destinationFolder: '/tmp',
            isImportProxyVideos: true,
          );
          final scanResultWithProxy = await service.scanMediaFiles(settingsWithProxy);
          final filesWithProxy = scanResultWithProxy.mediaFiles;

          // プロキシ動画を取り込まない設定
          final settingsWithoutProxy = ImportSettings(
            destinationFolder: '/tmp',
            isImportProxyVideos: false,
          );
          final scanResultWithoutProxy = await service.scanMediaFiles(settingsWithoutProxy);
          final filesWithoutProxy = scanResultWithoutProxy.mediaFiles;

          expect(filesWithProxy.length, equals(2));
          expect(filesWithoutProxy.length, equals(1));

          // プロキシ動画は ProxyVideo タイプ
          final proxyFiles = filesWithProxy.where((f) => f.type == MediaType.ProxyVideo);
          expect(proxyFiles.length, equals(1));
        } finally {
          await cleanup();
        }
      });

      test('動画 XML のスキャンは設定で切り替えられる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.video('C0001'),
              MockMediaFile.videoMeta('C0001'),
            ],
          );
          final service = SonyFilesystemService(tempDir);

          // XML を取り込む設定
          final settingsWithXml = ImportSettings(
            destinationFolder: '/tmp',
            isImportVideoXML: true,
          );
          final scanResultWithXml = await service.scanMediaFiles(settingsWithXml);
          final filesWithXml = scanResultWithXml.mediaFiles;

          // XML を取り込まない設定
          final settingsWithoutXml = ImportSettings(
            destinationFolder: '/tmp',
            isImportVideoXML: false,
          );
          final scanResultWithoutXml = await service.scanMediaFiles(settingsWithoutXml);
          final filesWithoutXml = scanResultWithoutXml.mediaFiles;

          expect(filesWithXml.length, equals(2));
          expect(filesWithoutXml.length, equals(1));

          // XML ファイルは VideoMeta タイプ
          final xmlFiles = filesWithXml.where((f) => f.type == MediaType.VideoMeta);
          expect(xmlFiles.length, equals(1));
        } finally {
          await cleanup();
        }
      });

      test('ファイル名は順不同でも全件取得される', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          // 逆順で追加
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.jpeg('DSC00003'),
              MockMediaFile.jpeg('DSC00001'),
              MockMediaFile.jpeg('DSC00002'),
            ],
          );
          final service = SonyFilesystemService(tempDir);
          final settings = ImportSettings.defaults();

          final scanResult = await service.scanMediaFiles(settings);
          final files = scanResult.mediaFiles;

          final fileNames = files.map((file) => file.fileName).toList();
          expect(fileNames.length, equals(3));
          expect(
            fileNames,
            containsAll(<String>[
              'DSC00001.JPG',
              'DSC00002.JPG',
              'DSC00003.JPG',
            ]),
          );
        } finally {
          await cleanup();
        }
      });

      test('DCIM フォルダが先、CLIP フォルダが後にスキャンされる', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.jpeg('DSC00001'),
              MockMediaFile.video('C0001'),
            ],
          );
          final service = SonyFilesystemService(tempDir);
          final settings = ImportSettings.defaults();

          final scanResult = await service.scanMediaFiles(settings);
          final files = scanResult.mediaFiles;

          expect(files.length, equals(2));
          // 写真が先、動画が後
          expect(files[0].type, equals(MediaType.JPEGPhoto));
          expect(files[1].type, equals(MediaType.Video));
        } finally {
          await cleanup();
        }
      });

      test('OS 生成ファイルは除外される', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.jpeg('DSC00001'),
              // OS 生成ファイルを追加
              const MockMediaFile(
                relativePath: 'DCIM/100MSDCF/.DS_Store',
                size: 100,
              ),
              const MockMediaFile(
                relativePath: 'DCIM/100MSDCF/Thumbs.db',
                size: 100,
              ),
            ],
          );
          final service = SonyFilesystemService(tempDir);
          final settings = ImportSettings.defaults();

          final scanResult = await service.scanMediaFiles(settings);
          final files = scanResult.mediaFiles;

          // 有効なファイルのみ
          expect(files.length, equals(1));
          expect(files[0].fileName, equals('DSC00001.JPG'));
        } finally {
          await cleanup();
        }
      });

      test('未知の拡張子は警告として記録される', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.jpeg('DSC00001'),
              const MockMediaFile(
                relativePath: 'DCIM/100MSDCF/DSC00002.AAA',
                size: 1024,
              ),
            ],
          );
          final service = SonyFilesystemService(tempDir);
          final settings = ImportSettings.defaults();

          final scanResult = await service.scanMediaFiles(settings);

          expect(scanResult.mediaFiles.length, equals(1));
          expect(
            scanResult.warnings.where((w) => w.type == ImportWarningType.UnknownExtensionFound).length,
            equals(1),
          );
        } finally {
          await cleanup();
        }
      });

      test('未知の拡張子のローカル日時は cameraTimezone を使用する', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          final modifiedTime = DateTime.utc(2025, 1, 1, 0, 0, 0);
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.jpeg('DSC00001'),
              MockMediaFile(
                relativePath: 'DCIM/100MSDCF/DSC00002.AAA',
                size: 1024,
                modifiedTime: modifiedTime,
              ),
            ],
          );
          final service = SonyFilesystemService(tempDir);
          final settings = ImportSettings.defaults().copyWith(
            cameraTimezone: 'Asia/Tokyo',
          );

          final scanResult = await service.scanMediaFiles(settings);
          final warning = scanResult.warnings.firstWhere(
            (w) => w.type == ImportWarningType.UnknownExtensionFound,
          );

          final offset = getTimezoneOffsetDuration(settings.cameraTimezone);
          expect(offset, isNotNull);
          final expectedLocal = DateTime.fromMillisecondsSinceEpoch(
            modifiedTime.millisecondsSinceEpoch,
            isUtc: true,
          ).add(offset!);

          expect(warning.file.captureLocalDateTime, equals(expectedLocal));
        } finally {
          await cleanup();
        }
      });

      test(
        'RAW が EXIF を持たない場合は JPEG/HIF の EXIF をフォールバックする',
        () async {
          final sampleDir = Directory(p.join('test', 'fixtures', 'sample_media'));
          if (!sampleDir.existsSync()) {
            return;
          }

          final (tempDir, cleanup) = await createTempDirectory();

          try {
            await createMockSdCardStructure(tempDir);
            final targetDir = Directory(p.join(tempDir, 'DCIM', '100MSDCF'));

            final sampleFiles = sampleDir.listSync().whereType<File>().where((file) {
              final extension = p.extension(file.path).toLowerCase();
              return [
                '.jpg',
                '.jpeg',
                '.arw',
                '.hif',
                '.heif',
              ].contains(extension);
            }).toList();

            if (sampleFiles.isEmpty) {
              return;
            }

            for (final file in sampleFiles) {
              await file.copy(p.join(targetDir.path, p.basename(file.path)));
            }

            final rawExifByBaseName = <String, DateTime?>{};
            final fallbackExifByBaseName = <String, DateTime>{};

            for (final file in sampleFiles) {
              final extension = p.extension(file.path).toLowerCase();
              final baseName = p.basenameWithoutExtension(file.path);

              if (extension == '.arw') {
                final exif = await readExifDateTime(
                  file,
                  cameraTimezone: 'Asia/Tokyo',
                );
                rawExifByBaseName[baseName] = exif.bestLocalDateTime;
                continue;
              }

              if (extension == '.jpg' || extension == '.jpeg' || extension == '.hif' || extension == '.heif') {
                final exif = await readExifDateTime(
                  file,
                  cameraTimezone: 'Asia/Tokyo',
                );
                if (exif.bestLocalDateTime != null) {
                  fallbackExifByBaseName[baseName] = exif.bestLocalDateTime!;
                }
              }
            }

            final targetBaseNames = rawExifByBaseName.entries
                .where(
                  (entry) => entry.value == null && fallbackExifByBaseName.containsKey(entry.key),
                )
                .map((entry) => entry.key)
                .toList();

            if (targetBaseNames.isEmpty) {
              return;
            }

            final service = SonyFilesystemService(tempDir);
            final settings = ImportSettings.defaults();
            final scanResult = await service.scanMediaFiles(settings);

            for (final baseName in targetBaseNames) {
              final rawFile = scanResult.mediaFiles.firstWhere(
                (file) => file.type == MediaType.RAWPhoto && file.baseName == baseName,
              );
              final resolvedRawFile = await service.resolveMediaFileWithExif(
                rawFile,
                cameraTimezone: settings.cameraTimezone,
                restoreToleranceSeconds: settings.dateRestoreToleranceSeconds,
              );
              expect(resolvedRawFile.exifDateTimeLocal, equals(fallbackExifByBaseName[baseName]));
            }
          } finally {
            await cleanup();
          }
        },
        skip: !Directory(p.join('test', 'fixtures', 'sample_media')).existsSync(),
      );

      test('相対パスが正しく設定される', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(
            tempDir,
            mockFiles: [
              MockMediaFile.jpeg('DSC00001'),
              MockMediaFile.video('C0001'),
            ],
          );
          final service = SonyFilesystemService(tempDir);
          final settings = ImportSettings.defaults();

          final scanResult = await service.scanMediaFiles(settings);
          final files = scanResult.mediaFiles;

          expect(files[0].relativePath, equals('DCIM/100MSDCF/DSC00001.JPG'));
          expect(files[1].relativePath, equals('PRIVATE/M4ROOT/CLIP/C0001.MP4'));
        } finally {
          await cleanup();
        }
      });
    });

    group('isWritable', () {
      test('書き込み可能なディレクトリでは true を返す', () async {
        final (tempDir, cleanup) = await createTempDirectory();

        try {
          await createMockSdCardStructure(tempDir);
          final service = SonyFilesystemService(tempDir);

          final writable = await service.isWritable();

          expect(writable, isTrue);
        } finally {
          await cleanup();
        }
      });
    });
  });

  group('SonyFilesystemValidation', () {
    test('success factory は正しい値を設定する', () {
      final validation = SonyFilesystemValidation.success(
        dcfFolders: ['100MSDCF', '101MSDCF'],
      );

      expect(validation.isValid, isTrue);
      expect(validation.hasDcimFolder, isTrue);
      expect(validation.hasDcfFolder, isTrue);
      expect(validation.hasClipFolder, isTrue);
      expect(validation.errorMessage, isNull);
      expect(validation.dcfFolders.length, equals(2));
    });

    test('failure factory は正しい値を設定する', () {
      final validation = SonyFilesystemValidation.failure(
        errorMessage: 'Test error',
        hasDcimFolder: true,
        hasDcfFolder: true,
      );

      expect(validation.isValid, isFalse);
      expect(validation.hasDcimFolder, isTrue);
      expect(validation.hasDcfFolder, isTrue);
      expect(validation.hasClipFolder, isFalse);
      expect(validation.errorMessage, equals('Test error'));
    });
  });
}
