/// ファイル操作ユーティリティ
///
/// ファイルパス処理、日時復元、フォルダ操作などを提供する。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';

import '../services/file_time_service.dart';

/// ファイル名から拡張子を除いたベース名を取得
///
/// 例: 'DSC00001.ARW' → 'DSC00001'
String getBaseName(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1) return fileName;
  return fileName.substring(0, dotIndex);
}

/// ファイル名から拡張子を取得（ドット含む）
///
/// 例: 'DSC00001.ARW' → '.ARW'
String getExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1) return '';
  return fileName.substring(dotIndex);
}

/// 重複しないファイル名を生成する
///
/// [directory] に [fileName] が既に存在する場合、
/// ' (1)', ' (2)', ... のサフィックスを付けた名前を返す。
/// Windows 形式の命名規則（スペース + 括弧 + 番号）を使用。
///
/// 例:
/// ```dart
/// // DSC00001.ARW が存在する場合
/// final newName = await generateUniqueFileName(dir, 'DSC00001.ARW');
/// print(newName); // 'DSC00001 (1).ARW'
/// ```
Future<String> generateUniqueFileName(
  Directory directory,
  String fileName,
) async {
  final baseName = getBaseName(fileName);
  final extension = getExtension(fileName);

  var candidate = fileName;
  var counter = 1;

  while (await File(p.join(directory.path, candidate)).exists()) {
    candidate = '$baseName ($counter)$extension';
    counter++;

    // 無限ループ防止（通常は到達しない）
    if (counter > 10000) {
      throw Exception('Failed to generate unique file name for: $fileName');
    }
  }

  return candidate;
}

/// ファイルの日時属性を復元する
///
/// [file] の作成日時と更新日時を [dateTime] に設定する。
/// アクセス日時は変更しない。
///
/// 作成日時の復元ができない環境は仕様外のため例外を投げる。
/// 取り込み処理側で fail-fast による中断を行う。
Future<void> restoreFileDateTime({
  required File file,
  required DateTime creationTimeUtc,
  required DateTime modifiedTimeUtc,
}) async {
  try {
    await FileTimeService.instance.setFileTimes(
      path: file.path,
      creationTimeUtc: creationTimeUtc,
      modifiedTimeUtc: modifiedTimeUtc,
    );
  } on MissingPluginException {
    throw UnsupportedError('File time API is not available.');
  } on PlatformException catch (ex) {
    if (ex.code == 'NOT_IMPLEMENTED') {
      throw UnsupportedError('File time API is not available.');
    }
    rethrow;
  } catch (ex) {
    // 日時復元失敗（読み取り専用ファイルなど）
    rethrow;
  }
}

/// ファイルの作成日時と更新日時を取得する
Future<({int creationTimeUtcMs, int modifiedTimeUtcMs})> getFileTimes(
  String path,
) async {
  return FileTimeService.instance.getFileTimes(path);
}

/// ファイルが書き込み中かどうかを判定する
///
/// ファイルの更新日時が現在から [thresholdSeconds] 秒以内の場合、
/// 書き込み中と判定する。
///
/// カメラが SD カードに書き込み中のファイルをスキップするために使用。
Future<bool> isFileBeingWritten(
  File file, {
  int thresholdSeconds = 30,
}) async {
  try {
    final stat = await file.stat();
    final now = DateTime.now();
    final diff = now.difference(stat.modified);

    return diff.inSeconds.abs() < thresholdSeconds;
  } catch (_) {
    // ファイル情報取得失敗時は安全側に倒して書き込み中とみなす
    return true;
  }
}

/// ディレクトリを再帰的に作成する
///
/// 既に存在する場合は何もしない。
Future<void> ensureDirectoryExists(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
}

/// パスを正規化する（OS に応じた区切り文字に統一）
String normalizePath(String path) {
  return p.normalize(path);
}

/// 2 つのパスを結合する
String joinPath(String path1, String path2) {
  return p.join(path1, path2);
}

/// パスからファイル名部分を取得
String getFileName(String path) {
  return p.basename(path);
}

/// パスからディレクトリ部分を取得
String getDirectoryPath(String path) {
  return p.dirname(path);
}

/// 相対パスを計算する
///
/// [from] から [to] への相対パスを返す。
String getRelativePath(String from, String to) {
  return p.relative(to, from: from);
}

/// OS 生成ファイルを判定する
///
/// .DS_Store, ._*, Thumbs.db, .fseventsd などの
/// OS が自動生成するファイルかどうかを判定する。
bool isOsGeneratedFile(String fileName) {
  final lowerName = fileName.toLowerCase();

  // macOS
  if (lowerName == '.ds_store') return true;
  if (lowerName.startsWith('._')) return true;
  if (lowerName == '.fseventsd') return true;
  if (lowerName == '.spotlight-v100') return true;
  if (lowerName == '.trashes') return true;

  // Windows
  if (lowerName == 'thumbs.db') return true;
  if (lowerName == 'desktop.ini') return true;
  if (lowerName == 'system volume information') return true;

  return false;
}

/// ディスク空き容量を取得する
///
/// [path] が存在するボリュームの空き容量をバイト単位で返す。
/// 取得できない場合は null を返す。
Future<int?> getAvailableDiskSpace(String path) async {
  try {
    return await FileTimeService.instance.getAvailableDiskSpace(path);
  } catch (_) {
    return null;
  }
}

/// ファイルサイズを人間が読みやすい形式でフォーマット
///
/// 例: 1073741824 → '1.00 GB'
String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
