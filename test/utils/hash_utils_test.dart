/// ハッシュユーティリティのテスト
///
/// xxHash3 を使用したファイルハッシュ計算機能をテストする。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:alpha_import_utility/utils/hash_utils.dart';
import '../fixtures/test_helper.dart';

void main() {
  group('computeFileHash', () {
    test('ファイルのハッシュを計算できる', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        // テストファイルを作成
        final testFile = File(p.join(tempDir, 'test.bin'));
        final testData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        await testFile.writeAsBytes(testData);

        final hash = await computeFileHash(testFile);

        // ハッシュ値は 16 桁の 16 進数文字列
        expect(hash.length, equals(16));
        expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(hash), isTrue);
      } finally {
        await cleanup();
      }
    });

    test('同じ内容のファイルは同じハッシュを返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        final file1 = File(p.join(tempDir, 'test1.bin'));
        await file1.writeAsBytes(testData);

        final file2 = File(p.join(tempDir, 'test2.bin'));
        await file2.writeAsBytes(testData);

        final hash1 = await computeFileHash(file1);
        final hash2 = await computeFileHash(file2);

        expect(hash1, equals(hash2));
      } finally {
        await cleanup();
      }
    });

    test('異なる内容のファイルは異なるハッシュを返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final file1 = File(p.join(tempDir, 'test1.bin'));
        await file1.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        final file2 = File(p.join(tempDir, 'test2.bin'));
        await file2.writeAsBytes(Uint8List.fromList([5, 6, 7, 8]));

        final hash1 = await computeFileHash(file1);
        final hash2 = await computeFileHash(file2);

        expect(hash1, isNot(equals(hash2)));
      } finally {
        await cleanup();
      }
    });

    test('進捗コールバックが呼び出される', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final testFile = File(p.join(tempDir, 'test.bin'));
        final testData = Uint8List(10000); // 10KB
        await testFile.writeAsBytes(testData);

        int lastBytesRead = 0;
        int callCount = 0;

        await computeFileHash(
          testFile,
          onProgress: (bytesRead) {
            expect(bytesRead, greaterThanOrEqualTo(lastBytesRead));
            lastBytesRead = bytesRead;
            callCount++;
          },
        );

        // 進捗コールバックが少なくとも 1 回呼び出されることを確認
        expect(callCount, greaterThan(0));
        expect(lastBytesRead, equals(10000));
      } finally {
        await cleanup();
      }
    });

    test('空のファイルも処理できる', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final testFile = File(p.join(tempDir, 'empty.bin'));
        await testFile.writeAsBytes(Uint8List(0));

        final hash = await computeFileHash(testFile);

        // 空ファイルでも有効なハッシュを返す
        expect(hash.length, equals(16));
      } finally {
        await cleanup();
      }
    });
  });

  group('computeDataHash', () {
    test('データのハッシュを計算できる', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      final hash = computeDataHash(data);

      expect(hash.length, equals(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(hash), isTrue);
    });

    test('同じデータは同じハッシュを返す', () {
      final data1 = Uint8List.fromList([1, 2, 3, 4]);
      final data2 = Uint8List.fromList([1, 2, 3, 4]);

      final hash1 = computeDataHash(data1);
      final hash2 = computeDataHash(data2);

      expect(hash1, equals(hash2));
    });

    test('異なるデータは異なるハッシュを返す', () {
      final data1 = Uint8List.fromList([1, 2, 3, 4]);
      final data2 = Uint8List.fromList([5, 6, 7, 8]);

      final hash1 = computeDataHash(data1);
      final hash2 = computeDataHash(data2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('空のデータも処理できる', () {
      final data = Uint8List(0);

      final hash = computeDataHash(data);

      expect(hash.length, equals(16));
    });
  });

  group('StreamingCopyWithHash', () {
    test('ファイルをコピーしながらハッシュを計算できる', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        // ソースファイルを作成
        final sourceFile = File(p.join(tempDir, 'source.bin'));
        final testData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        await sourceFile.writeAsBytes(testData);

        // コピー先
        final destFile = File(p.join(tempDir, 'dest.bin'));

        final copier = StreamingCopyWithHash(
          source: sourceFile,
          destination: destFile,
        );

        final hash = await copier.execute();

        // ハッシュが返される
        expect(hash.length, equals(16));

        // ファイルがコピーされている
        expect(await destFile.exists(), isTrue);

        // コピー先の内容が一致
        final copiedData = await destFile.readAsBytes();
        expect(copiedData, equals(testData));
      } finally {
        await cleanup();
      }
    });

    test('コピー中に進捗コールバックが呼び出される', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final sourceFile = File(p.join(tempDir, 'source.bin'));
        final testData = Uint8List(10000); // 10KB
        await sourceFile.writeAsBytes(testData);

        final destFile = File(p.join(tempDir, 'dest.bin'));

        int lastBytesCopied = 0;
        int callCount = 0;

        final copier = StreamingCopyWithHash(
          source: sourceFile,
          destination: destFile,
          onProgress: (bytesCopied) {
            expect(bytesCopied, greaterThanOrEqualTo(lastBytesCopied));
            lastBytesCopied = bytesCopied;
            callCount++;
          },
        );

        await copier.execute();

        expect(callCount, greaterThan(0));
        expect(lastBytesCopied, equals(10000));
      } finally {
        await cleanup();
      }
    });

    test('コピー先ディレクトリが存在しない場合は作成される', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final sourceFile = File(p.join(tempDir, 'source.bin'));
        await sourceFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        // 存在しないディレクトリにコピー
        final destFile = File(p.join(tempDir, 'subdir', 'nested', 'dest.bin'));

        final copier = StreamingCopyWithHash(
          source: sourceFile,
          destination: destFile,
        );

        await copier.execute();

        expect(await destFile.exists(), isTrue);
      } finally {
        await cleanup();
      }
    });

    test('computeFileHash と同じハッシュを返す', () async {
      final (tempDir, cleanup) = await createTempDirectory();

      try {
        final sourceFile = File(p.join(tempDir, 'source.bin'));
        final testData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        await sourceFile.writeAsBytes(testData);

        final destFile = File(p.join(tempDir, 'dest.bin'));

        // StreamingCopyWithHash でコピー
        final copier = StreamingCopyWithHash(
          source: sourceFile,
          destination: destFile,
        );
        final copyHash = await copier.execute();

        // computeFileHash で計算
        final directHash = await computeFileHash(sourceFile);

        expect(copyHash, equals(directHash));
      } finally {
        await cleanup();
      }
    });
  });

  group('hashesMatch', () {
    test('同じハッシュ値は true を返す', () {
      expect(hashesMatch('a1b2c3d4e5f67890', 'a1b2c3d4e5f67890'), isTrue);
    });

    test('大文字小文字は区別しない', () {
      expect(hashesMatch('a1b2c3d4e5f67890', 'A1B2C3D4E5F67890'), isTrue);
      expect(hashesMatch('A1B2C3D4E5F67890', 'a1b2c3d4e5f67890'), isTrue);
    });

    test('異なるハッシュ値は false を返す', () {
      expect(hashesMatch('a1b2c3d4e5f67890', '0987654321abcdef'), isFalse);
    });
  });
}
