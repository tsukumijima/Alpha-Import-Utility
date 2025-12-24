/// 取り込みエンジンのテスト
///
/// 最小限の SD カード構造を使い、取り込み処理の動作を検証する。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:alpha_import_utility/models/settings.dart';
import 'package:alpha_import_utility/services/import_engine.dart';
import 'package:alpha_import_utility/services/metadata_manager.dart';
import '../fixtures/test_helper.dart';

void main() {
  setUpAll(() {
    setUpFileTimeServiceMocks();
  });

  group('ImportEngine', () {
    test('単一ファイルを取り込み、メタデータを記録する', () async {
      final (sdRoot, cleanupSd) = await createTempDirectory();
      final (destRoot, cleanupDest) = await createTempDirectory();

      try {
        await createMockSdCardStructure(
          sdRoot,
          mockFiles: [
            MockMediaFile.jpeg('DSC00001', size: 1024 * 10),
          ],
        );

        final settings = ImportSettings(
          destinationFolder: destRoot,
          cameraTimezone: 'UTC',
          isRestoreDateTimeFromExif: false,
          isImportVideoXML: false,
          isImportProxyVideos: false,
        );

        final engine = ImportEngine(
          sdCardRoot: sdRoot,
          settings: settings,
        );

        final result = await engine.execute();

        expect(result.successCount, equals(1));
        expect(result.errorCount, equals(0));

        final sourceFile = File(p.join(sdRoot, 'DCIM', '100MSDCF', 'DSC00001.JPG'));
        final fileStat = await sourceFile.stat();
        final subfolder = settings.generateSubfolderPath(fileStat.modified.toUtc());
        final importedFile = File(p.join(settings.destinationFolder, subfolder, 'DSC00001.JPG'));
        expect(await importedFile.exists(), isTrue);

        final metadataManager = MetadataManager(sdRoot);
        final metadata = await metadataManager.load();
        expect(metadata.files.length, equals(1));
      } finally {
        await cleanupSd();
        await cleanupDest();
      }
    });
  });
}
