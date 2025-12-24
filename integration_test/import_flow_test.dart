/// 取り込みフローの統合テスト
///
/// MethodChannel を含む実環境で取り込み処理を検証する。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'package:alpha_import_utility/models/settings.dart';
import 'package:alpha_import_utility/services/import_engine.dart';
import 'package:alpha_import_utility/services/metadata_manager.dart';
import 'package:alpha_import_utility/services/sony_filesystem.dart';
import 'package:alpha_import_utility/services/file_time_service.dart';
import '../test/fixtures/test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ImportEngine integration', () {
    testWidgets('sample_media を取り込み、メタデータと日時を検証する', (tester) async {
      final (sdRoot, cleanupSd) = await createTempDirectory();
      final (destRoot, cleanupDest) = await createTempDirectory();

      try {
        await createSdCardFromSampleMedia(
          sdRoot,
          includeProxy: true,
          copiesPerFile: 1,
        );

        final settings = ImportSettings(
          destinationFolder: destRoot,
          cameraTimezone: 'Asia/Tokyo',
          isRestoreDateTimeFromExif: true,
          isImportVideoXML: true,
          isImportProxyVideos: true,
        );

        final engine = ImportEngine(
          sdCardRoot: sdRoot,
          settings: settings,
        );

        final result = await engine.execute();
        expect(result.errorCount, equals(0));
        expect(result.successCount, greaterThan(0));

        final metadataManager = MetadataManager(sdRoot);
        final metadata = await metadataManager.load();
        expect(metadata.files.length, equals(result.successCount));

        final sonyFs = SonyFilesystemService(sdRoot);
        final scanResult = await sonyFs.scanMediaFiles(settings);
        final mediaFiles = scanResult.mediaFiles;
        expect(mediaFiles, isNotEmpty);

        final firstFile = mediaFiles.first;
        final subfolder = settings.generateSubfolderPath(
          firstFile.effectiveDateTimeLocal,
        );
        final destPath = p.join(
          settings.destinationFolder,
          subfolder,
          firstFile.fileName,
        );
        final destFile = File(destPath);
        expect(await destFile.exists(), isTrue);

        if (settings.isRestoreDateTimeFromExif) {
          final times = await FileTimeService.instance.getFileTimes(destPath);
          final creationUtc = DateTime.fromMillisecondsSinceEpoch(
            times.creationTimeUtcMs,
            isUtc: true,
          );
          final expected = firstFile.effectiveDateTimeUtc;
          final diffSeconds = expected.difference(creationUtc).inSeconds.abs();
          expect(diffSeconds, lessThanOrEqualTo(settings.dateRestoreToleranceSeconds));
        }
      } finally {
        await cleanupSd();
        await cleanupDest();
      }
    });
  });
}
