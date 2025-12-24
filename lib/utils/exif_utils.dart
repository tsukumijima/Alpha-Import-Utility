/// EXIF 読み取りユーティリティ
///
/// JPEG、ARW（RAW）、HEIF ファイルから撮影日時を読み取る。
/// 動画 XML（NonRealTimeMeta）からの日時読み取りも提供する。
library;

import 'dart:io';

import 'package:exif/exif.dart';
import 'package:xml/xml.dart';

/// EXIF から読み取った日時情報
class ExifDateTime {
  /// 撮影日時（EXIF DateTimeOriginal）
  final DateTime? dateTimeOriginal;

  /// デジタル化日時（EXIF DateTimeDigitized）
  final DateTime? dateTimeDigitized;

  /// 変更日時（EXIF DateTime）
  final DateTime? dateTime;

  ExifDateTime({
    this.dateTimeOriginal,
    this.dateTimeDigitized,
    this.dateTime,
  });

  /// 最も信頼できる日時を取得
  ///
  /// 優先順位: DateTimeOriginal > DateTimeDigitized > DateTime
  DateTime? get bestDateTime {
    return dateTimeOriginal ?? dateTimeDigitized ?? dateTime;
  }

  /// いずれかの日時が取得できたか
  bool get hasAnyDateTime {
    return dateTimeOriginal != null ||
        dateTimeDigitized != null ||
        dateTime != null;
  }
}

/// 画像ファイルから EXIF 日時を読み取る
///
/// [file] は JPEG、ARW、または HEIF ファイル。
/// 読み取りに失敗した場合は全フィールドが null の ExifDateTime を返す。
///
/// 例:
/// ```dart
/// final exifDateTime = await readExifDateTime(File('DSC00001.ARW'));
/// if (exifDateTime.bestDateTime != null) {
///   print('撮影日時: ${exifDateTime.bestDateTime}');
/// }
/// ```
Future<ExifDateTime> readExifDateTime(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final tags = await readExifFromBytes(bytes);

    if (tags.isEmpty) {
      return ExifDateTime();
    }

    return ExifDateTime(
      dateTimeOriginal: _parseExifDateTag(tags['EXIF DateTimeOriginal']),
      dateTimeDigitized: _parseExifDateTag(tags['EXIF DateTimeDigitized']),
      dateTime: _parseExifDateTag(tags['Image DateTime']),
    );
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

  final value = tag.printable;
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

/// 動画 XML ファイル（NonRealTimeMeta）から撮影日時を読み取る
///
/// Sony カメラが生成する XML ファイルの CreationDate 要素から
/// 撮影日時を取得する。タイムゾーン情報が含まれる場合は
/// ローカル時刻に変換して返す。
///
/// 例:
/// ```dart
/// final dateTime = await readVideoXmlDateTime(File('C0079M01.XML'));
/// if (dateTime != null) {
///   print('撮影日時: $dateTime');
/// }
/// ```
Future<DateTime?> readVideoXmlDateTime(File xmlFile) async {
  try {
    final content = await xmlFile.readAsString();
    final document = XmlDocument.parse(content);

    // CreationDate 要素を探す
    // 形式: <CreationDate value="2025-12-24T15:30:00+09:00"/>
    final creationDateElements =
        document.findAllElements('CreationDate');

    if (creationDateElements.isEmpty) {
      return null;
    }

    final valueAttr = creationDateElements.first.getAttribute('value');
    if (valueAttr == null || valueAttr.isEmpty) {
      return null;
    }

    // ISO 8601 形式でパース
    return DateTime.parse(valueAttr).toLocal();
  } catch (ex) {
    // XML パースエラーまたは日付パースエラー
    return null;
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

  // Sony 動画の XML ファイル名パターン: {baseName}M01.XML
  // M01 は固定ではない可能性があるため、パターンマッチで探す
  final directory = videoFile.parent;

  try {
    await for (final entity in directory.list()) {
      if (entity is File) {
        final fileName = entity.uri.pathSegments.last.toUpperCase();

        // パターン: {baseName}M{数字2桁}.XML
        if (fileName.startsWith(baseName.toUpperCase()) &&
            fileName.endsWith('.XML') &&
            fileName.contains('M')) {
          return entity;
        }
      }
    }
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
Future<DateTime?> readVideoDateTime(File videoFile) async {
  final xmlFile = await findVideoXmlFile(videoFile);
  if (xmlFile == null) {
    return null;
  }

  return readVideoXmlDateTime(xmlFile);
}
