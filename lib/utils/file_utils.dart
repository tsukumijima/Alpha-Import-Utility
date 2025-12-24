/// ファイル操作ユーティリティ
///
/// ファイルパス処理、日時復元、フォルダ操作などを提供する。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

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
/// プラットフォームによっては作成日時の変更がサポートされない場合がある。
/// その場合は更新日時のみを変更する。
Future<void> restoreFileDateTime(File file, DateTime dateTime) async {
  try {
    // Dart の File API では作成日時の変更は直接サポートされていないが、
    // setLastModified で更新日時は変更可能
    await file.setLastModified(dateTime);

    // 作成日時の変更はプラットフォーム固有の実装が必要だが、
    // macOS/Windows ともに標準 API では困難なため、
    // 更新日時の復元のみを行う
  } catch (ex) {
    // 日時復元失敗（読み取り専用ファイルなど）
    rethrow;
  }
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
  // Dart 標準ライブラリでは直接取得できないため、
  // プラットフォーム固有のコマンドを使用
  try {
    if (Platform.isMacOS || Platform.isLinux) {
      final result = await Process.run('df', ['-k', path]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.length >= 2) {
          // 形式: Filesystem 1K-blocks Used Available Use% Mounted on
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            // Available は KB 単位なのでバイトに変換
            return int.tryParse(parts[3])?.let((kb) => kb * 1024);
          }
        }
      }
    } else if (Platform.isWindows) {
      // Windows では wmic コマンドを使用
      final driveLetter = path.substring(0, 2); // 例: 'C:'
      final result = await Process.run('wmic', [
        'logicaldisk',
        'where',
        'DeviceID="$driveLetter"',
        'get',
        'FreeSpace',
        '/value',
      ]);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final match = RegExp(r'FreeSpace=(\d+)').firstMatch(output);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }
    }
  } catch (_) {
    // コマンド実行失敗
  }

  return null;
}

/// int に対する拡張メソッド
extension IntExtension on int {
  /// 値を変換するヘルパー
  T let<T>(T Function(int) transform) => transform(this);
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
