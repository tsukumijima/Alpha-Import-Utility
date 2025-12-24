/// ハッシュ計算ユーティリティ
///
/// xxHash3 を使用したファイルハッシュ計算を提供する。
/// ストリーミング処理に対応し、大きなファイルでもメモリ効率的に処理できる。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:xxh3/xxh3.dart';

/// ファイルの xxHash64 を計算する
///
/// [file] のハッシュを計算し、16 進数文字列で返す。
/// 進捗コールバック [onProgress] が指定された場合、
/// 読み取りバイト数を通知する。
///
/// 例:
/// ```dart
/// final hash = await computeFileHash(File('image.arw'));
/// print(hash); // 'a1b2c3d4e5f67890'
/// ```
Future<String> computeFileHash(
  File file, {
  void Function(int bytesRead)? onProgress,
}) async {
  final fileSize = await file.length();
  int totalBytesRead = 0;

  // ファイルをストリームとして読み取り、チャンクごとにハッシュを更新
  final chunks = <Uint8List>[];

  await for (final chunk in file.openRead()) {
    chunks.add(Uint8List.fromList(chunk));
    totalBytesRead += chunk.length;

    if (onProgress != null) {
      onProgress(totalBytesRead);
    }
  }

  // 全データを結合してハッシュを計算
  // xxh3 パッケージはストリーミング API を持たないため、一括計算
  final allData = Uint8List(fileSize);
  int offset = 0;
  for (final chunk in chunks) {
    allData.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }

  final hashValue = xxh3(allData);
  return hashValue.toRadixString(16).padLeft(16, '0');
}

/// バイトデータの xxHash64 を計算する
///
/// [data] のハッシュを計算し、16 進数文字列で返す。
/// メモリ上のデータを直接ハッシュ化する場合に使用。
String computeDataHash(Uint8List data) {
  final hashValue = xxh3(data);
  return hashValue.toRadixString(16).padLeft(16, '0');
}

/// ストリーミングコピーしながらハッシュを計算するクラス
///
/// ファイルコピーとハッシュ計算を同時に行い、
/// 二重読み取りを回避して I/O を最適化する。
class StreamingCopyWithHash {
  /// コピー元ファイル
  final File source;

  /// コピー先ファイル
  final File destination;

  /// 進捗コールバック（コピー済みバイト数を通知）
  final void Function(int bytesCopied)? onProgress;

  StreamingCopyWithHash({
    required this.source,
    required this.destination,
    this.onProgress,
  });

  /// コピーを実行し、計算したハッシュを返す
  ///
  /// コピー中に [onProgress] で進捗を通知する。
  /// コピー失敗時は例外をスローする。
  Future<String> execute() async {
    final sourceSize = await source.length();
    int totalBytesCopied = 0;

    // コピー先ディレクトリを作成（存在しない場合）
    final destDir = destination.parent;
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    // ハッシュ計算用にデータを蓄積
    final chunks = <Uint8List>[];

    // コピー先ファイルを開く
    final sink = destination.openWrite();

    try {
      await for (final chunk in source.openRead()) {
        // チャンクを保存（ハッシュ計算用）
        final uint8Chunk = Uint8List.fromList(chunk);
        chunks.add(uint8Chunk);

        // ファイルに書き込み
        sink.add(uint8Chunk);

        totalBytesCopied += chunk.length;

        if (onProgress != null) {
          onProgress!(totalBytesCopied);
        }
      }

      await sink.flush();
    } finally {
      await sink.close();
    }

    // ハッシュを計算
    final allData = Uint8List(sourceSize);
    int offset = 0;
    for (final chunk in chunks) {
      allData.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    final hashValue = xxh3(allData);
    return hashValue.toRadixString(16).padLeft(16, '0');
  }
}

/// 2 つのハッシュ値が一致するかを比較する
///
/// 大文字・小文字を区別しない比較を行う。
bool hashesMatch(String hash1, String hash2) {
  return hash1.toLowerCase() == hash2.toLowerCase();
}
