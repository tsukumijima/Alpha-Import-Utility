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
/// 作成日時の復元ができない環境は仕様外のため例外を投げる。
/// 取り込み処理側で fail-fast による中断を行う。
Future<void> restoreFileDateTime(File file, DateTime dateTime) async {
  try {
    // Dart の File API では作成日時の変更は直接サポートされていないが、
    // setLastModified で更新日時は変更可能
    await file.setLastModified(dateTime);

    await _restoreCreationTime(file, dateTime);
  } catch (ex) {
    // 日時復元失敗（読み取り専用ファイルなど）
    rethrow;
  }
}

/// 作成日時を復元する
///
/// Windows は PowerShell、macOS は SetFile コマンドを使用する。
/// 非対応環境では例外を投げる。
Future<void> _restoreCreationTime(File file, DateTime dateTime) async {
  if (Platform.isWindows) {
    final isoTime = dateTime.toIso8601String();
    final escapedPath = _escapePowerShellString(file.path);
    final script =
        r"$item = Get-Item -LiteralPath '" +
        escapedPath +
        r"'; $item.CreationTime = Get-Date '" +
        isoTime +
        r"'; $item.LastWriteTime = Get-Date '" +
        isoTime +
        r"';";

    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-Command', script],
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to restore file creation time: ${result.stderr}');
    }
    return;
  }

  if (Platform.isMacOS) {
    final setFileCommand = await _resolveSetFileCommand();
    final formatted = _formatSetFileDateTime(dateTime.toLocal());
    final result = await Process.run(
      setFileCommand,
      ['-d', formatted, file.path],
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to restore file creation time: ${result.stderr}');
    }
    return;
  }

  throw UnsupportedError(
    'Creation time restore is not supported on this platform.',
  );
}

/// PowerShell 用に文字列をエスケープする
String _escapePowerShellString(String value) {
  return value.replaceAll("'", "''");
}

/// SetFile 用に日時文字列を整形する
///
/// 形式: MM/DD/YYYY HH:MM:SS
String _formatSetFileDateTime(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final year = dateTime.year.toString();
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final second = dateTime.second.toString().padLeft(2, '0');
  return '$month/$day/$year $hour:$minute:$second';
}

/// SetFile コマンドの存在を確認してコマンド名を返す
///
/// 利用不可の場合は例外を投げる。
Future<String> _resolveSetFileCommand() async {
  if (_cachedSetFileCommand != null) {
    return _cachedSetFileCommand!;
  }

  final candidates = ['SetFile', 'setfile'];
  for (final candidate in candidates) {
    try {
      final result = await Process.run('which', [candidate]);
      final isCommandAvailable = result.exitCode == 0;
      if (isCommandAvailable) {
        _cachedSetFileCommand = candidate;
        return candidate;
      }
    } catch (_) {
      // which 実行失敗時は次の候補を試す
    }
  }

  throw UnsupportedError(
    'SetFile command is not available. '
    'Install Xcode Command Line Tools.',
  );
}

String? _cachedSetFileCommand;

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
      // Windows では fsutil コマンドを使用（wmic は廃止）
      final driveLetter = path.substring(0, 2); // 例: 'C:'
      final result = await Process.run('fsutil', [
        'volume',
        'diskfree',
        driveLetter,
      ]);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        return _parseFsutilFreeBytes(output);
      }
    }
  } catch (_) {
    // コマンド実行失敗
  }

  return null;
}

/// fsutil の出力から空き容量（バイト）を取得する
int? _parseFsutilFreeBytes(String output) {
  final freeMatch = RegExp(r'Total # of free bytes\\s*:\\s*(\\d+)').firstMatch(output);
  if (freeMatch != null) {
    return int.tryParse(freeMatch.group(1)!);
  }

  final availableMatch = RegExp(r'Total # of avail free bytes\\s*:\\s*(\\d+)').firstMatch(output);
  if (availableMatch != null) {
    return int.tryParse(availableMatch.group(1)!);
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
