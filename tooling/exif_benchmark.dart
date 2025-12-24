/// EXIF parsing benchmark utility.
///
/// Measures EXIF parsing time with different options for a set of files.
library;

import 'dart:io';

import 'package:exif_reader/exif_reader.dart';
import 'package:random_access_source/random_access_source.dart';

import 'package:alpha_import_utility/utils/exif_utils.dart';

Future<void> main(List<String> args) async {
  final filePaths = args.isNotEmpty
      ? args
      : <String>[
          'test/fixtures/sample_media/DSC02053.JPG',
          'test/fixtures/sample_media/DSC02054.ARW',
          'test/fixtures/sample_media/DSC02054.HIF',
        ];

  for (final path in filePaths) {
    final file = File(path);
    if (!await file.exists()) {
      stdout.writeln('File not found: $path.');
      continue;
    }

    stdout.writeln('---');
    stdout.writeln('Benchmarking: $path.');
    await _benchmarkReadExifDateTime(file);
    await _benchmarkReadExifFromSource(
      file,
      label: 'readExifFromSource(details=true)',
      details: true,
      stopTag: null,
    );
    await _benchmarkReadExifFromSource(
      file,
      label: 'readExifFromSource(details=false)',
      details: false,
      stopTag: null,
    );
    await _benchmarkReadExifFromSource(
      file,
      label: 'readExifFromSource(details=false, stopTag=EXIF DateTimeOriginal)',
      details: false,
      stopTag: 'EXIF DateTimeOriginal',
    );
  }
}

Future<void> _benchmarkReadExifDateTime(File file) async {
  final stopwatch = Stopwatch()..start();
  final exif = await readExifDateTime(
    file,
    cameraTimezone: 'Asia/Tokyo',
  );
  stopwatch.stop();

  stdout.writeln(
    'readExifDateTime: ${stopwatch.elapsedMilliseconds}ms '
    '(hasAnyDateTime=${exif.hasAnyDateTime}).',
  );
}

Future<void> _benchmarkReadExifFromSource(
  File file, {
  required String label,
  required bool details,
  required String? stopTag,
}) async {
  final source = await FileRASource.openPath(file.path);
  try {
    final stopwatch = Stopwatch()..start();
    final exif = await readExifFromSource(
      source,
      details: details,
      truncateTags: true,
      stopTag: stopTag,
    );
    stopwatch.stop();

    stdout.writeln(
      '$label: ${stopwatch.elapsedMilliseconds}ms '
      '(tags=${exif.tags.length}).',
    );
  } finally {
    await source.close();
  }
}
