/// ファイル日時を更新するためのプラットフォームサービス
///
/// 作成日時と更新日時の両方をネイティブ実装で設定する。
library;

import 'package:flutter/services.dart';

/// ファイル日時更新サービス
class FileTimeService {
  /// MethodChannel 名
  static const MethodChannel _channel = MethodChannel(
    'alpha_import_utility/file_time',
  );

  /// シングルトンインスタンス
  static final FileTimeService instance = FileTimeService._();

  /// シングルトン用のプライベートコンストラクタ
  FileTimeService._();

  /// ファイルの作成日時と更新日時を設定する
  ///
  /// [creationTimeUtc] と [modifiedTimeUtc] は UTC の DateTime を指定する。
  Future<void> setFileTimes({
    required String path,
    required DateTime creationTimeUtc,
    required DateTime modifiedTimeUtc,
  }) async {
    final creationUtc = creationTimeUtc.toUtc();
    final modifiedUtc = modifiedTimeUtc.toUtc();

    await _channel.invokeMethod<void>('setFileTimes', {
      'path': path,
      'creationTimeUtcMs': creationUtc.millisecondsSinceEpoch,
      'modifiedTimeUtcMs': modifiedUtc.millisecondsSinceEpoch,
    });
  }

  /// ファイルの作成日時と更新日時を取得する
  ///
  /// 返り値は UTC ミリ秒で返す。
  Future<({int creationTimeUtcMs, int modifiedTimeUtcMs})> getFileTimes(
    String path,
  ) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getFileTimes',
      {'path': path},
    );
    if (result == null) {
      throw Exception('Failed to read file times for: $path');
    }

    return (
      creationTimeUtcMs: result['creationTimeUtcMs'] as int,
      modifiedTimeUtcMs: result['modifiedTimeUtcMs'] as int,
    );
  }

  /// ディスクの空き容量を取得する
  ///
  /// 取得に失敗した場合は null を返す。
  Future<int?> getAvailableDiskSpace(String path) async {
    final result = await _channel.invokeMethod<int?>(
      'getAvailableDiskSpace',
      {'path': path},
    );
    return result;
  }
}
