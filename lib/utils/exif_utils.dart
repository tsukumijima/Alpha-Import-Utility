/// EXIF 読み取りユーティリティ
///
/// JPEG、ARW（RAW）、HEIF ファイルから撮影日時を読み取る。
/// 動画 XML（NonRealTimeMeta）からの日時読み取りも提供する。
library;

import 'dart:io';

import 'package:exif_reader/exif_reader.dart';
import 'package:random_access_source/random_access_source.dart';
import 'package:xml/xml.dart';

import 'timezone_utils.dart';

/// 動画 XML のキャッシュ
///
/// 各ディレクトリパスをキーとして、動画ファイル名から XML ファイルへのマッピングを保持する。
/// このキャッシュはアプリのライフタイム全体で保持されるため、SD カードの切り替え時などに
/// [clearVideoXmlCache] を呼び出してクリアする必要がある。
final Map<String, Map<String, File?>> _videoXmlCacheByDirectory = {};

/// 動画 XML キャッシュをクリアする
///
/// SD カードの切り替え時や取り込み処理の完了時に呼び出すことで、
/// 古いキャッシュによるメモリリークを防止する。
void clearVideoXmlCache() {
  _videoXmlCacheByDirectory.clear();
}

/// EXIF から読み取った日時情報
class ExifDateTime {
  /// 撮影日時（EXIF DateTimeOriginal, カメラのローカル時刻）
  final DateTime? dateTimeOriginalLocal;

  /// 撮影日時（EXIF DateTimeOriginal, UTC）
  final DateTime? dateTimeOriginalUtc;

  /// デジタル化日時（EXIF DateTimeDigitized, カメラのローカル時刻）
  final DateTime? dateTimeDigitizedLocal;

  /// デジタル化日時（EXIF DateTimeDigitized, UTC）
  final DateTime? dateTimeDigitizedUtc;

  /// 変更日時（EXIF DateTime, カメラのローカル時刻）
  final DateTime? dateTimeLocal;

  /// 変更日時（EXIF DateTime, UTC）
  final DateTime? dateTimeUtc;

  /// EXIF にタイムゾーン情報が含まれていたか
  final bool hasTimezoneOffset;

  /// EXIF 日時情報を生成する
  ExifDateTime({
    this.dateTimeOriginalLocal,
    this.dateTimeOriginalUtc,
    this.dateTimeDigitizedLocal,
    this.dateTimeDigitizedUtc,
    this.dateTimeLocal,
    this.dateTimeUtc,
    this.hasTimezoneOffset = false,
  });

  /// 最も信頼できる日時（カメラのローカル時刻）を取得
  ///
  /// 優先順位: DateTimeOriginal > DateTimeDigitized > DateTime
  DateTime? get bestLocalDateTime {
    return dateTimeOriginalLocal ?? dateTimeDigitizedLocal ?? dateTimeLocal;
  }

  /// 最も信頼できる日時（UTC）を取得
  ///
  /// 優先順位: DateTimeOriginal > DateTimeDigitized > DateTime
  DateTime? get bestUtcDateTime {
    return dateTimeOriginalUtc ?? dateTimeDigitizedUtc ?? dateTimeUtc;
  }

  /// いずれかの日時が取得できたか
  bool get hasAnyDateTime {
    return bestLocalDateTime != null || bestUtcDateTime != null;
  }
}

/// 画像ファイルから EXIF 日時を読み取る
///
/// [file] は JPEG、ARW、または HEIF ファイル。
/// EXIF のタイムゾーン情報があればそれを優先し、無い場合は
/// [cameraTimezone] をフォールバックとして使用する。
/// 読み取りに失敗した場合は全フィールドが null の ExifDateTime を返す。
///
/// 例:
/// ```dart
/// final exifDateTime = await readExifDateTime(
///   File('DSC00001.ARW'),
///   cameraTimezone: 'Asia/Tokyo',
/// );
/// if (exifDateTime.bestLocalDateTime != null) {
///   print('撮影日時: ${exifDateTime.bestLocalDateTime}');
/// }
/// ```
Future<ExifDateTime> readExifDateTime(
  File file, {
  required String cameraTimezone,
}) async {
  try {
    final source = await FileRASource.openPath(file.path);
    try {
      final exif = await readExifFromSource(
        source,
        details: false,
        truncateTags: true,
      );
      if (exif.tags.isEmpty) {
        return ExifDateTime();
      }

      final dateTimeOriginal = _parseExifDateTag(exif.tags['EXIF DateTimeOriginal']);
      final dateTimeDigitized = _parseExifDateTag(exif.tags['EXIF DateTimeDigitized']);
      final dateTime = _parseExifDateTag(exif.tags['Image DateTime']);

      final offsetOriginal = _parseExifOffsetTag(exif.tags['EXIF OffsetTimeOriginal']);
      final offsetDigitized = _parseExifOffsetTag(exif.tags['EXIF OffsetTimeDigitized']);
      final offsetDefault =
          _parseExifOffsetTag(exif.tags['EXIF OffsetTime']) ?? _parseExifOffsetTag(exif.tags['Image OffsetTime']);

      final hasTimezoneOffset = offsetOriginal != null || offsetDigitized != null || offsetDefault != null;

      return ExifDateTime(
        dateTimeOriginalLocal: dateTimeOriginal,
        dateTimeOriginalUtc: _applyTimezoneOffset(
          dateTimeOriginal,
          offsetOriginal ?? offsetDefault,
          cameraTimezone,
        ),
        dateTimeDigitizedLocal: dateTimeDigitized,
        dateTimeDigitizedUtc: _applyTimezoneOffset(
          dateTimeDigitized,
          offsetDigitized ?? offsetDefault,
          cameraTimezone,
        ),
        dateTimeLocal: dateTime,
        dateTimeUtc: _applyTimezoneOffset(
          dateTime,
          offsetDefault,
          cameraTimezone,
        ),
        hasTimezoneOffset: hasTimezoneOffset,
      );
    } finally {
      await source.close();
    }
  } catch (ex) {
    // EXIF 読み取りエラー（対応していないフォーマット、ファイル破損など）
    return ExifDateTime();
  }
}

/// EXIF 日付タグをパースして DateTime に変換
///
/// EXIF 形式: 'YYYY:MM:DD HH:MM:SS'
DateTime? _parseExifDateTag(IfdTag? tag) {
  if (tag == null) return null;

  final value = tag.printable.trim();
  if (value.isEmpty) return null;

  try {
    // 形式: 'YYYY:MM:DD HH:MM:SS'
    final parts = value.split(' ');
    if (parts.length != 2) return null;

    final dateParts = parts[0].split(':');
    final timeParts = parts[1].split(':');

    if (dateParts.length != 3 || timeParts.length != 3) return null;

    return DateTime(
      int.parse(dateParts[0]), // year
      int.parse(dateParts[1]), // month
      int.parse(dateParts[2]), // day
      int.parse(timeParts[0]), // hour
      int.parse(timeParts[1]), // minute
      int.parse(timeParts[2]), // second
    );
  } catch (_) {
    return null;
  }
}

/// EXIF の OffsetTime 系タグをパースして Duration に変換
Duration? _parseExifOffsetTag(IfdTag? tag) {
  if (tag == null) return null;

  final value = tag.printable.trim();
  if (value.isEmpty) return null;

  return parseUtcOffset(value);
}

/// EXIF のローカル時刻にタイムゾーンオフセットを適用
///
/// オフセットが null の場合は cameraTimezone から取得する。
DateTime? _applyTimezoneOffset(
  DateTime? localDateTime,
  Duration? exifOffset,
  String cameraTimezone,
) {
  if (localDateTime == null) return null;

  final offset = exifOffset ?? getTimezoneOffsetDuration(cameraTimezone);
  if (offset == null) {
    return null;
  }

  return _toUtcDateTime(localDateTime, offset);
}

/// ローカル時刻とオフセットから UTC を算出する
DateTime _toUtcDateTime(DateTime localDateTime, Duration offset) {
  return DateTime.utc(
    localDateTime.year,
    localDateTime.month,
    localDateTime.day,
    localDateTime.hour,
    localDateTime.minute,
    localDateTime.second,
    localDateTime.millisecond,
    localDateTime.microsecond,
  ).subtract(offset);
}

/// 動画 XML ファイル（NonRealTimeMeta）から撮影日時を読み取る
///
/// Sony カメラが生成する XML ファイルの CreationDate 要素から
/// 撮影日時を取得する。タイムゾーン情報が含まれる場合は
/// ローカル時刻に変換して返す。
/// タイムゾーン情報が無い場合は [cameraTimezone] をフォールバックとして使用する。
///
/// 例:
/// ```dart
/// final dateTime = await readVideoXmlDateTime(File('C0079M01.XML'));
/// if (dateTime != null) {
///   print('撮影日時: $dateTime');
/// }
/// ```
/// 動画 XML から読み取った日時情報
class VideoDateTime {
  /// 撮影日時（カメラのローカル時刻）
  final DateTime? localDateTime;

  /// 撮影日時（UTC）
  final DateTime? utcDateTime;

  /// 収録フレーム数
  final int? durationFrames;

  /// フレームレート
  final double? frameRate;

  /// XML にタイムゾーン情報が含まれていたか
  final bool hasTimezoneOffset;

  /// 動画 XML から読み取った日時情報を生成する
  const VideoDateTime({
    required this.localDateTime,
    required this.utcDateTime,
    required this.durationFrames,
    required this.frameRate,
    required this.hasTimezoneOffset,
  });
}

/// 動画 XML ファイルから撮影日時を読み取る
///
/// CreationDate と動画フレーム情報（Duration, VideoFrame）を解析し、
/// UTC とローカル時刻を返す。
Future<VideoDateTime?> readVideoXmlDateTime(
  File xmlFile, {
  required String cameraTimezone,
}) async {
  try {
    final content = await xmlFile.readAsString();
    final document = XmlDocument.parse(content);

    // CreationDate 要素を探す
    // 形式: <CreationDate value="2025-12-24T15:30:00+09:00"/>
    final creationDateElements = document.findAllElements('CreationDate');

    if (creationDateElements.isEmpty) {
      return null;
    }

    final valueAttr = creationDateElements.first.getAttribute('value');
    if (valueAttr == null || valueAttr.isEmpty) {
      return null;
    }

    // ISO 8601 形式でパース
    final hasOffset = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(valueAttr);
    final local = _parseIsoLocalDateTime(valueAttr);

    final durationFrames = _parseXmlIntAttribute(
      document,
      'Duration',
      'value',
    );
    final frameRate = _parseFrameRate(document);

    if (hasOffset) {
      final utc = DateTime.parse(valueAttr).toUtc();
      return VideoDateTime(
        localDateTime: local,
        utcDateTime: utc,
        durationFrames: durationFrames,
        frameRate: frameRate,
        hasTimezoneOffset: true,
      );
    }

    final cameraOffset = getTimezoneOffsetDuration(cameraTimezone);
    if (cameraOffset == null || local == null) {
      return VideoDateTime(
        localDateTime: local,
        utcDateTime: null,
        durationFrames: durationFrames,
        frameRate: frameRate,
        hasTimezoneOffset: false,
      );
    }

    final utc = _toUtcDateTime(local, cameraOffset);

    return VideoDateTime(
      localDateTime: local,
      utcDateTime: utc,
      durationFrames: durationFrames,
      frameRate: frameRate,
      hasTimezoneOffset: false,
    );
  } catch (ex) {
    // XML パースエラーまたは日付パースエラー
    return null;
  }
}

/// 動画 XML のキャッシュを取得する
Map<String, File?> _getVideoXmlCacheForDirectory(Directory directory) {
  return _videoXmlCacheByDirectory.putIfAbsent(
    directory.path,
    () => <String, File?>{},
  );
}

/// ディレクトリ内の動画 XML をスキャンしてキャッシュを更新する
Future<void> _populateVideoXmlCache(
  Directory directory,
  Map<String, File?> cache,
) async {
  await for (final entity in directory.list()) {
    if (entity is! File) {
      continue;
    }
    final fileNameUpper = entity.uri.pathSegments.last.toUpperCase();
    if (!fileNameUpper.endsWith('.XML')) {
      continue;
    }
    final fileStemUpper = fileNameUpper.substring(0, fileNameUpper.length - 4);
    final match = RegExp(r'^([A-Z0-9]+)M\d{2}$').firstMatch(fileStemUpper);
    if (match == null) {
      continue;
    }
    final baseName = match.group(1)!;
    cache[baseName] = entity;
  }
}

/// 動画ファイルに対応する XML ファイルのパスを取得
///
/// [videoFile] から対応する XML ファイルのパスを推測する。
/// 例: C0079.MP4 → C0079M01.XML
///
/// 対応する XML が存在しない場合は null を返す。
Future<File?> findVideoXmlFile(File videoFile) async {
  final videoName = videoFile.uri.pathSegments.last;
  final baseName = videoName.substring(0, videoName.lastIndexOf('.'));
  final baseNameKey = baseName.toUpperCase();

  // Sony 動画の XML ファイル名パターン: {baseName}M01.XML
  // M01 は固定ではない可能性があるため、パターンマッチで探す
  final directory = videoFile.parent;

  try {
    final cache = _getVideoXmlCacheForDirectory(directory);
    if (!cache.containsKey(baseNameKey)) {
      await _populateVideoXmlCache(directory, cache);
      cache.putIfAbsent(baseNameKey, () => null);
    }
    return cache[baseNameKey];
  } catch (_) {
    // ディレクトリ読み取りエラー
  }

  return null;
}

/// 動画ファイルから撮影日時を読み取る
///
/// まず対応する XML ファイルを探し、見つかればそこから日時を取得する。
/// XML が見つからない場合や読み取りに失敗した場合は null を返す。
///
/// 例:
/// ```dart
/// final dateTime = await readVideoDateTime(File('C0079.MP4'));
/// ```
Future<VideoDateTime?> readVideoDateTime(
  File videoFile, {
  required String cameraTimezone,
}) async {
  final xmlFile = await findVideoXmlFile(videoFile);
  if (xmlFile == null) {
    return null;
  }

  return readVideoXmlDateTime(
    xmlFile,
    cameraTimezone: cameraTimezone,
  );
}

/// ISO 8601 文字列からローカル時刻（タイムゾーン無し）を取得する
DateTime? _parseIsoLocalDateTime(String isoString) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(isoString);
  if (match == null) {
    return null;
  }

  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}

/// XML 要素の整数属性をパースする
int? _parseXmlIntAttribute(
  XmlDocument document,
  String elementName,
  String attributeName,
) {
  final elements = document.findAllElements(elementName);
  if (elements.isEmpty) {
    return null;
  }
  final value = elements.first.getAttribute(attributeName);
  if (value == null || value.isEmpty) {
    return null;
  }
  return int.tryParse(value);
}

/// XML からフレームレートをパースする
double? _parseFrameRate(XmlDocument document) {
  final elements = document.findAllElements('VideoFrame');
  if (elements.isEmpty) {
    return null;
  }
  final value = elements.first.getAttribute('captureFps') ?? elements.first.getAttribute('formatFps');
  if (value == null || value.isEmpty) {
    return null;
  }
  final normalized = value.replaceAll('p', '').replaceAll('i', '');
  return double.tryParse(normalized);
}
