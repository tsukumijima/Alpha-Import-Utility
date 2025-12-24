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
  int totalBytesRead = 0;
  final hashState = xxh3Stream();

  // ファイルをストリームとして読み取り、チャンクごとにハッシュを更新
  await for (final chunk in file.openRead()) {
    final uint8Chunk = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    hashState.update(uint8Chunk);
    totalBytesRead += uint8Chunk.length;

    if (onProgress != null) {
      onProgress(totalBytesRead);
    }
  }

  return hashState.digestString().padLeft(16, '0');
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
    int totalBytesCopied = 0;
    final hashState = xxh3Stream();

    // コピー先ディレクトリを作成（存在しない場合）
    final destDir = destination.parent;
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    // コピー先ファイルを開く
    final sink = destination.openWrite();

    try {
      await for (final chunk in source.openRead()) {
        final uint8Chunk = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);

        // ファイルに書き込み
        sink.add(uint8Chunk);
        hashState.update(uint8Chunk);

        totalBytesCopied += uint8Chunk.length;

        if (onProgress != null) {
          onProgress!(totalBytesCopied);
        }
      }

      await sink.flush();
    } finally {
      await sink.close();
    }

    return hashState.digestString().padLeft(16, '0');
  }
}

/// 2 つのハッシュ値が一致するかを比較する
///
/// 大文字・小文字を区別しない比較を行う。
bool hashesMatch(String hash1, String hash2) {
  return hash1.toLowerCase() == hash2.toLowerCase();
}
