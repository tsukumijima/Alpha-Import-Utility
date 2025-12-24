/// EXIF ユーティリティのテスト
///
/// EXIF 読み取りと動画 XML パース機能をテストする。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:alpha_import_utility/utils/exif_utils.dart';
import '../fixtures/test_helper.dart';

void main() {
  group('ExifDateTime', () {
    test('bestDateTime は優先順位に従って日時を返す', () {
      // DateTimeOriginal が最優先
      final exif1 = ExifDateTime(
        dateTimeOriginal: DateTime(2025, 12, 24, 10, 0),
        dateTimeDigitized: DateTime(2025, 12, 24, 11, 0),
        dateTime: DateTime(2025, 12, 24, 12, 0),
      );
      expect(exif1.bestDateTime, equals(DateTime(2025, 12, 24, 10, 0)));

      // DateTimeOriginal がない場合は DateTimeDigitized
      final exif2 = ExifDateTime(
        dateTimeDigitized: DateTime(2025, 12, 24, 11, 0),
        dateTime: DateTime(2025, 12, 24, 12, 0),
      );
      expect(exif2.bestDateTime, equals(DateTime(2025, 12, 24, 11, 0)));

      // 両方ない場合は DateTime
      final exif3 = ExifDateTime(
        dateTime: DateTime(2025, 12, 24, 12, 0),
      );
      expect(exif3.bestDateTime, equals(DateTime(2025, 12, 24, 12, 0)));

      // 全てない場合は null
      final exif4 = ExifDateTime();
      expect(exif4.bestDateTime, isNull);
    });

    test('hasAnyDateTime は日時があれば true を返す', () {
      expect(
        ExifDateTime(dateTimeOriginal: DateTime(2025, 12, 24)).hasAnyDateTime,
        isTrue,
      );
      expect(
        ExifDateTime(dateTimeDigitized: DateTime(2025, 12, 24)).hasAnyDateTime,
        isTrue,
      );
      expect(
        ExifDateTime(dateTime: DateTime(2025, 12, 24)).hasAnyDateTime,
        isTrue,
      );
      expect(ExifDateTime().hasAnyDateTime, isFalse);
    });
  });

  group('readExifDateTime', () {
    test('非画像ファイルでは空の ExifDateTime を返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        // テキストファイルを作成
        final testFile = File(p.join(tempDir, 'test.txt'));
        await testFile.writeAsString('Hello, World!');

        final exif = await readExifDateTime(
          testFile,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(exif.hasAnyDateTime, isFalse);
      } finally {
        await cleanup();
      }
    });

    test('存在しないファイルでは空の ExifDateTime を返す', () async {
      final testFile = File('/non/existent/file.jpg');

      final exif = await readExifDateTime(
        testFile,
        cameraTimezone: 'Asia/Tokyo',
      );

      expect(exif.hasAnyDateTime, isFalse);
    });

    test('空のファイルでは空の ExifDateTime を返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final testFile = File(p.join(tempDir, 'empty.jpg'));
        await testFile.writeAsBytes([]);

        final exif = await readExifDateTime(
          testFile,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(exif.hasAnyDateTime, isFalse);
      } finally {
        await cleanup();
      }
    });

    test('sample_media の EXIF はタイムゾーンを優先して解釈する', () async {
      final sampleDir = Directory(p.join('test', 'fixtures', 'sample_media'));
      if (!sampleDir.existsSync()) {
        return;
      }

      final files = sampleDir
          .listSync()
          .whereType<File>()
          .where(
            (file) => [
              '.jpg',
              '.jpeg',
              '.arw',
              '.hif',
              '.heif',
            ].contains(p.extension(file.path).toLowerCase()),
          )
          .toList();

      if (files.isEmpty) {
        return;
      }

      for (final file in files) {
        final exifWithUtc = await readExifDateTime(
          file,
          cameraTimezone: 'UTC',
        );
        final exifWithTokyo = await readExifDateTime(
          file,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(exifWithUtc.bestDateTime, isNotNull);
        expect(exifWithTokyo.bestDateTime, isNotNull);

        final diffSeconds = exifWithUtc.bestDateTime!.difference(exifWithTokyo.bestDateTime!).inSeconds.abs();
        expect(diffSeconds, lessThan(1));
      }
    }, skip: !Directory(p.join('test', 'fixtures', 'sample_media')).existsSync());
  });

  group('readVideoXmlDateTime', () {
    test('正しい XML から日時を読み取れる', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final xmlFile = File(p.join(tempDir, 'C0001M01.XML'));
        await xmlFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<NonRealTimeMeta xmlns="urn:schemas-professionalDisc:nonRealTimeMeta:ver.2.00">
  <CreationDate value="2025-12-24T15:30:00+09:00"/>
</NonRealTimeMeta>
''');

        final dateTime = await readVideoXmlDateTime(
          xmlFile,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(dateTime, isNotNull);
        // タイムゾーン変換後の UTC 時刻を確認
        expect(dateTime!.toUtc(), equals(DateTime.utc(2025, 12, 24, 6, 30)));
      } finally {
        await cleanup();
      }
    });

    test('CreationDate がない XML では null を返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final xmlFile = File(p.join(tempDir, 'C0001M01.XML'));
        await xmlFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<NonRealTimeMeta xmlns="urn:schemas-professionalDisc:nonRealTimeMeta:ver.2.00">
  <Device>Sony ILCE-6700</Device>
</NonRealTimeMeta>
''');

        final dateTime = await readVideoXmlDateTime(
          xmlFile,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(dateTime, isNull);
      } finally {
        await cleanup();
      }
    });

    test('不正な XML では null を返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final xmlFile = File(p.join(tempDir, 'C0001M01.XML'));
        await xmlFile.writeAsString('not valid xml');

        final dateTime = await readVideoXmlDateTime(
          xmlFile,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(dateTime, isNull);
      } finally {
        await cleanup();
      }
    });

    test('空の value 属性では null を返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final xmlFile = File(p.join(tempDir, 'C0001M01.XML'));
        await xmlFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<NonRealTimeMeta xmlns="urn:schemas-professionalDisc:nonRealTimeMeta:ver.2.00">
  <CreationDate value=""/>
</NonRealTimeMeta>
''');

        final dateTime = await readVideoXmlDateTime(
          xmlFile,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(dateTime, isNull);
      } finally {
        await cleanup();
      }
    });

    test('存在しないファイルでは null を返す', () async {
      final xmlFile = File('/non/existent/C0001M01.XML');

      final dateTime = await readVideoXmlDateTime(
        xmlFile,
        cameraTimezone: 'Asia/Tokyo',
      );

      expect(dateTime, isNull);
    });

    test('UTC タイムゾーンの日時を正しく読み取れる', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final xmlFile = File(p.join(tempDir, 'C0001M01.XML'));
        await xmlFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<NonRealTimeMeta>
  <CreationDate value="2025-12-24T15:30:00Z"/>
</NonRealTimeMeta>
''');

        final dateTime = await readVideoXmlDateTime(
          xmlFile,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(dateTime, isNotNull);
        expect(dateTime!.toUtc(), equals(DateTime.utc(2025, 12, 24, 15, 30)));
      } finally {
        await cleanup();
      }
    });
  });

  group('findVideoXmlFile', () {
    test('対応する XML ファイルを見つける', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        // 動画ファイルと XML ファイルを作成
        final clipDir = Directory(p.join(tempDir, 'CLIP'));
        await clipDir.create();

        final videoFile = File(p.join(clipDir.path, 'C0001.MP4'));
        await videoFile.writeAsBytes([]);

        final xmlFile = File(p.join(clipDir.path, 'C0001M01.XML'));
        await xmlFile.writeAsString('<xml/>');

        final foundXml = await findVideoXmlFile(videoFile);

        expect(foundXml, isNotNull);
        expect(p.basename(foundXml!.path), equals('C0001M01.XML'));
      } finally {
        await cleanup();
      }
    });

    test('異なるサフィックスの XML ファイルも見つける', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final clipDir = Directory(p.join(tempDir, 'CLIP'));
        await clipDir.create();

        final videoFile = File(p.join(clipDir.path, 'C0001.MP4'));
        await videoFile.writeAsBytes([]);

        // M02 サフィックスの XML
        final xmlFile = File(p.join(clipDir.path, 'C0001M02.XML'));
        await xmlFile.writeAsString('<xml/>');

        final foundXml = await findVideoXmlFile(videoFile);

        expect(foundXml, isNotNull);
      } finally {
        await cleanup();
      }
    });

    test('XML がない場合は null を返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final clipDir = Directory(p.join(tempDir, 'CLIP'));
        await clipDir.create();

        final videoFile = File(p.join(clipDir.path, 'C0001.MP4'));
        await videoFile.writeAsBytes([]);

        final foundXml = await findVideoXmlFile(videoFile);

        expect(foundXml, isNull);
      } finally {
        await cleanup();
      }
    });

    test('無関係な XML ファイルは返さない', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final clipDir = Directory(p.join(tempDir, 'CLIP'));
        await clipDir.create();

        final videoFile = File(p.join(clipDir.path, 'C0001.MP4'));
        await videoFile.writeAsBytes([]);

        // 別の動画の XML
        final xmlFile = File(p.join(clipDir.path, 'C0002M01.XML'));
        await xmlFile.writeAsString('<xml/>');

        final foundXml = await findVideoXmlFile(videoFile);

        expect(foundXml, isNull);
      } finally {
        await cleanup();
      }
    });
  });

  group('readVideoDateTime', () {
    test('XML から動画の撮影日時を読み取る', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final clipDir = Directory(p.join(tempDir, 'CLIP'));
        await clipDir.create();

        final videoFile = File(p.join(clipDir.path, 'C0001.MP4'));
        await videoFile.writeAsBytes([]);

        final xmlFile = File(p.join(clipDir.path, 'C0001M01.XML'));
        await xmlFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<NonRealTimeMeta>
  <CreationDate value="2025-12-24T15:30:00+09:00"/>
</NonRealTimeMeta>
''');

        final dateTime = await readVideoDateTime(
          videoFile,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(dateTime, isNotNull);
      } finally {
        await cleanup();
      }
    });

    test('XML がない場合は null を返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final clipDir = Directory(p.join(tempDir, 'CLIP'));
        await clipDir.create();

        final videoFile = File(p.join(clipDir.path, 'C0001.MP4'));
        await videoFile.writeAsBytes([]);

        final dateTime = await readVideoDateTime(
          videoFile,
          cameraTimezone: 'Asia/Tokyo',
        );

        expect(dateTime, isNull);
      } finally {
        await cleanup();
      }
    });
  });
}
