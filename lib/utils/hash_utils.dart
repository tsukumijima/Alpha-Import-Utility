/// ハッシュ計算ユーティリティ
///
/// xxHash3 を使用したファイルハッシュ計算を提供する。
/// ストリーミング処理に対応し、大きなファイルでもメモリ効率的に処理できる。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:xxh3/xxh3.dart';

import '../models/import_result.dart';

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

/// ファイルの軽量シグネチャを計算する
///
/// ファイルの先頭・中間・末尾のチャンクをハッシュ化し、
/// 差分判定を高速化するためのシグネチャを生成する。
Future<FileLightweightSignature> computeFileLightweightSignature(
  File file, {
  int chunkSize = 64 * 1024,
}) async {
  final fileLength = await file.length();
  final safeChunkSize = chunkSize <= 0 ? 64 * 1024 : chunkSize;

  final headSize = fileLength < safeChunkSize ? fileLength : safeChunkSize;
  final middleSize = headSize;
  final tailSize = headSize;

  final headOffset = 0;
  final middleOffset = fileLength <= middleSize
      ? 0
      : ((fileLength - middleSize) ~/ 2).clamp(0, fileLength - middleSize);
  final tailOffset = fileLength <= tailSize ? 0 : fileLength - tailSize;

  final raf = await file.open();
  try {
    final chunkCache = <String, Uint8List>{};
    final headData = await _readFileChunkWithCache(
      raf,
      headOffset,
      headSize,
      chunkCache,
    );
    final middleData = await _readFileChunkWithCache(
      raf,
      middleOffset,
      middleSize,
      chunkCache,
    );
    final tailData = await _readFileChunkWithCache(
      raf,
      tailOffset,
      tailSize,
      chunkCache,
    );

    return FileLightweightSignature(
      chunkSize: safeChunkSize,
      headHash: computeDataHash(headData),
      middleHash: computeDataHash(middleData),
      tailHash: computeDataHash(tailData),
    );
  } finally {
    await raf.close();
  }
}

/// ファイルの指定位置からチャンクを読み取る
Future<Uint8List> _readFileChunk(
  RandomAccessFile raf,
  int offset,
  int size,
) async {
  if (size <= 0) {
    return Uint8List(0);
  }

  await raf.setPosition(offset);
  final data = await raf.read(size);
  return data;
}

/// キャッシュを利用してファイルチャンクを読み取る
///
/// 同一オフセットの読み取りを再利用し、I/O 回数を減らす。
Future<Uint8List> _readFileChunkWithCache(
  RandomAccessFile raf,
  int offset,
  int size,
  Map<String, Uint8List> cache,
) async {
  if (size <= 0) {
    return Uint8List(0);
  }

  final cacheKey = _buildChunkCacheKey(offset, size);
  final cached = cache[cacheKey];
  if (cached != null) {
    return cached;
  }

  final data = await _readFileChunk(raf, offset, size);
  cache[cacheKey] = data;
  return data;
}

/// チャンクキャッシュのキーを生成する
String _buildChunkCacheKey(int offset, int size) {
  return '$offset:$size';
}

/// ストリーミングコピーしながらハッシュを計算するクラス
///
/// RandomAccessFile を使用してファイルコピーとハッシュ計算を同時に行う。
/// 累計バイト数に基づいて定期的に fsync を呼び、OS キャッシュのバースト書き込みを軽減する。
/// これにより HDD への書き込み時の I/O パターンが安定し、進捗表示と実際の書き込みが同期しやすくなる。
///
/// ## 累計バイト数の管理
///
/// このクラスは [_pendingBytes] という静的フィールドで、複数ファイル間の累計書き込みバイト数を管理する。
/// 累計が [_fsyncThresholdBytes]（64MB）を超えると fsync を呼び、カウンタをリセットする。
/// 各ファイルのコピー完了時には fsync を呼ぶが、累計カウンタはリセットしない（次のファイルで合算される）。
///
/// **重要**: 呼び出し元は取り込みセッション終了時に [resetPendingBytes] を呼び出す必要がある。
/// これを忘れると、次回の取り込みで累計が引き継がれてしまう。
/// 典型的な呼び出し元である `ImportEngine` では、`execute()` の完了時とエラー発生時の両方で
/// `resetPendingBytes()` を呼び出している。
///
/// ## Isolate に関する注意
///
/// [_pendingBytes] は静的フィールドであり、Isolate 間で共有されない（各 Isolate が独自のコピーを持つ）。
/// このアプリは単一 Isolate で動作するため問題ないが、複数 Isolate で並列コピーを行う場合は
/// インスタンスレベルのカウンタか、明示的な同期機構が必要になる。
class StreamingCopyWithHash {
  /// コピー元ファイル
  final File source;

  /// コピー先ファイル
  final File destination;

  /// 進捗コールバック（コピー済みバイト数を通知）
  final void Function(int bytesCopied)? onProgress;

  /// 読み込みバッファサイズ（256KB）
  ///
  /// 大きいファイル（RAW: 50-60MB、動画: 100MB+）に適したサイズ。
  static const int _readBufferSize = 256 * 1024;

  /// fsync を呼ぶ累計バイト数のしきい値（64MB）
  ///
  /// RAW 1-2 枚、JPEG 10 枚程度で fsync が呼ばれる頻度。
  /// HDD のシーケンシャル書き込みを維持しつつ、OS キャッシュの溢れを防ぐバランス。
  static const int _fsyncThresholdBytes = 64 * 1024 * 1024;

  /// 現在の累計書き込みバイト数
  ///
  /// 複数ファイル間で共有される静的カウンタ。
  /// [_fsyncThresholdBytes] を超えると fsync が呼ばれ、0 にリセットされる。
  /// 取り込みセッション終了時に [resetPendingBytes] で明示的にリセットする必要がある。
  static int _pendingBytes = 0;

  StreamingCopyWithHash({
    required this.source,
    required this.destination,
    this.onProgress,
  });

  /// コピーを実行し、計算したハッシュを返す
  ///
  /// RandomAccessFile を使用して明示的に書き込みを待機し、
  /// 累計バイト数がしきい値を超えたら fsync を呼んでディスクに書き出す。
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

    // RandomAccessFile でコピー元・コピー先を開く
    final sourceRaf = await source.open(mode: FileMode.read);
    final destRaf = await destination.open(mode: FileMode.write);

    try {
      final buffer = Uint8List(_readBufferSize);

      while (true) {
        // チャンクを読み込み
        final bytesRead = await sourceRaf.readInto(buffer);
        if (bytesRead == 0) {
          break;
        }

        // 実際に読み込んだ分だけのビューを作成
        final chunk = bytesRead == buffer.length ? buffer : Uint8List.sublistView(buffer, 0, bytesRead);

        // ファイルに書き込み（await で完了を待機）
        await destRaf.writeFrom(chunk);
        hashState.update(chunk);

        totalBytesCopied += bytesRead;
        _pendingBytes += bytesRead;

        // 進捗通知
        if (onProgress != null) {
          onProgress!(totalBytesCopied);
        }

        // 累計バイト数がしきい値を超えたら fsync を呼ぶ
        if (_pendingBytes >= _fsyncThresholdBytes) {
          await destRaf.flush();
          _pendingBytes = 0;
        }
      }

      // ファイル末尾で最終フラッシュ（ただし累計リセットはしない、次のファイルで合算）
      await destRaf.flush();
    } finally {
      await sourceRaf.close();
      await destRaf.close();
    }

    return hashState.digestString().padLeft(16, '0');
  }

  /// 取り込み完了時に累計をリセットする
  ///
  /// 取り込みセッションの終了時に呼び出し、次回の取り込みに備える。
  static void resetPendingBytes() {
    _pendingBytes = 0;
  }
}

/// 2 つのハッシュ値が一致するかを比較する
///
/// 大文字・小文字を区別しない比較を行う。
bool hashesMatch(String hash1, String hash2) {
  return hash1.toLowerCase() == hash2.toLowerCase();
}
