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
import 'package:alpha_import_utility/main.dart' as app;
import '../test/fixtures/test_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  tearDownAll(() {});

  group('ImportEngine integration', () {
    testWidgets('sample_media を取り込み、メタデータと日時を検証する', (tester) async {
      app.main();
      await tester.pump(const Duration(milliseconds: 500));

      final (smallSdRoot, cleanupSmallSd) = await createTempDirectory();
      final (smallDestRoot, cleanupSmallDest) = await createTempDirectory();
      final (largeSdRoot, cleanupLargeSd) = await createTempDirectory();
      final (largeDestRoot, cleanupLargeDest) = await createTempDirectory();

      try {
        await tester.runAsync(() async {
          await createSdCardFromSampleMedia(
            smallSdRoot,
            includeProxy: true,
            copiesPerFile: 1,
          );

          final settings = ImportSettings(
            destinationFolder: smallDestRoot,
            cameraTimezone: 'Asia/Tokyo',
            isRestoreDateTimeFromExif: true,
            isImportVideoXML: true,
            isImportProxyVideos: true,
          );

          final engine = ImportEngine(
            sdCardRoot: smallSdRoot,
            settings: settings,
          );

          final result = await engine.execute();
          expect(result.errorCount, equals(0));
          expect(result.successCount, greaterThan(0));

          final metadataManager = MetadataManager(smallSdRoot);
          final metadata = await metadataManager.load();
          expect(metadata.files.length, equals(result.successCount));

          final sonyFs = SonyFilesystemService(smallSdRoot);
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

          await createSdCardFromSampleMedia(
            largeSdRoot,
            includeProxy: true,
            photoCopiesPerFile: 50,
            videoCopiesPerFile: 10,
            proxyCopiesPerFile: 10,
            xmlCopiesPerFile: 10,
          );

          final largeSettings = ImportSettings(
            destinationFolder: largeDestRoot,
            cameraTimezone: 'Asia/Tokyo',
            isRestoreDateTimeFromExif: true,
            isImportVideoXML: true,
            isImportProxyVideos: true,
          );

          final largeEngine = ImportEngine(
            sdCardRoot: largeSdRoot,
            settings: largeSettings,
          );

          final largeResult = await largeEngine.execute();
          expect(largeResult.errorCount, equals(0));
          expect(largeResult.successCount, greaterThan(0));

          final largeMetadataManager = MetadataManager(largeSdRoot);
          final largeMetadata = await largeMetadataManager.load();
          expect(largeMetadata.files.length, equals(largeResult.successCount));
        });
      } finally {
        await cleanupSmallSd();
        await cleanupSmallDest();
        await cleanupLargeSd();
        await cleanupLargeDest();
      }
    }, timeout: const Timeout(Duration(minutes: 30)));
  });
}
