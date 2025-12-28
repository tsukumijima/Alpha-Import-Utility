/// アップデートチェックサービス
///
/// GitHub Releases API を使用して新しいバージョンの有無を確認する。
/// アプリ起動時に一度だけチェックを行い、結果をキャッシュする。
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/github_release.dart';
import '../utils/version_utils.dart';
import 'logging_service.dart';

/// アップデートチェック結果
class UpdateCheckResult {
  /// 新しいバージョンが利用可能かどうか
  final bool isUpdateAvailable;

  /// 現在のバージョン
  final String currentVersion;

  /// 最新バージョン（チェック成功時のみ）
  final String? latestVersion;

  /// 最新リリース情報（チェック成功時のみ）
  final GitHubRelease? latestRelease;

  /// エラーメッセージ（チェック失敗時のみ）
  final String? errorMessage;

  UpdateCheckResult({
    required this.isUpdateAvailable,
    required this.currentVersion,
    this.latestVersion,
    this.latestRelease,
    this.errorMessage,
  });

  /// チェックが成功したかどうか
  bool get isSuccess => errorMessage == null;
}

/// アップデートチェックサービス
///
/// シングルトンパターンで実装し、アプリ全体で共有する。
/// 起動時に一度だけチェックを行い、結果をキャッシュする。
class UpdateCheckService {
  /// シングルトンインスタンス
  static UpdateCheckService? _instance;

  /// GitHub リポジトリのオーナー
  static const String _repoOwner = 'tsukumijima';

  /// GitHub リポジトリ名
  static const String _repoName = 'Alpha-Import-Utility';

  /// GitHub API エンドポイント
  static const String _apiEndpoint = 'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  /// API リクエストのタイムアウト（秒）
  static const int _timeoutSeconds = 10;

  /// キャッシュされたチェック結果
  UpdateCheckResult? _cachedResult;

  /// チェック中の場合の Completer（待機用）
  Completer<UpdateCheckResult>? _checkCompleter;

  /// ロガー
  final _log = LoggingService.instance;

  /// プライベートコンストラクタ
  UpdateCheckService._();

  /// シングルトンインスタンスを取得
  static UpdateCheckService get instance {
    _instance ??= UpdateCheckService._();
    return _instance!;
  }

  /// キャッシュされた結果を取得（チェック未実行の場合は null）
  UpdateCheckResult? get cachedResult => _cachedResult;

  /// アップデートをチェックする
  ///
  /// 既にチェック済みの場合はキャッシュを返す。
  /// チェック中の場合は完了を待機する。
  /// ネットワークエラーや API エラーは握りつぶし、
  /// エラー情報を含む結果を返す（アプリの動作を妨げない）。
  Future<UpdateCheckResult> checkForUpdates({bool isForceCheck = false}) async {
    // 強制チェックでない場合、キャッシュがあればそれを返す
    if (!isForceCheck && _cachedResult != null) {
      _log.debug('Returning cached update check result.', tag: 'UpdateCheck');
      return _cachedResult!;
    }

    // チェック中の場合は Completer の完了を待機（多重実行防止）
    if (_checkCompleter != null) {
      _log.debug('Update check already in progress, waiting.', tag: 'UpdateCheck');
      return _checkCompleter!.future;
    }

    // 新しいチェックを開始
    _checkCompleter = Completer<UpdateCheckResult>();
    _log.info('Checking for updates.', tag: 'UpdateCheck');

    try {
      final result = await _performUpdateCheck();
      _cachedResult = result;
      _checkCompleter!.complete(result);
      return result;
    } catch (ex, stackTrace) {
      // ネットワークエラーなど
      _log.warning(
        'Update check failed.',
        tag: 'UpdateCheck',
        error: ex,
        stackTrace: stackTrace,
      );

      // 現在のバージョンを取得（エラー時も表示用に）
      String currentVersion = 'unknown';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = packageInfo.version;
      } catch (_) {
        // 無視
      }

      final errorResult = UpdateCheckResult(
        isUpdateAvailable: false,
        currentVersion: currentVersion,
        errorMessage: 'アップデートの確認に失敗しました。',
      );
      _cachedResult = errorResult;
      _checkCompleter!.complete(errorResult);
      return errorResult;
    } finally {
      _checkCompleter = null;
    }
  }

  /// 実際のアップデートチェック処理を行う
  Future<UpdateCheckResult> _performUpdateCheck() async {
    // 現在のバージョンを取得
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    _log.debug('Current version: $currentVersion.', tag: 'UpdateCheck');

    // GitHub API にリクエスト
    final response = await http
        .get(
          Uri.parse(_apiEndpoint),
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(Duration(seconds: _timeoutSeconds));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final release = GitHubRelease.fromJson(json);

      _log.debug('Latest release: ${release.tagName}.', tag: 'UpdateCheck');

      // プレリリースとドラフトはスキップ
      if (release.isPrerelease || release.isDraft) {
        _log.info(
          'Latest release is prerelease or draft, skipping.',
          tag: 'UpdateCheck',
        );
        return UpdateCheckResult(
          isUpdateAvailable: false,
          currentVersion: currentVersion,
          latestVersion: release.version,
          latestRelease: release,
        );
      }

      // バージョン比較
      final isUpdateAvailable = isNewerVersionAvailable(
        currentVersion,
        release.version,
      );

      if (isUpdateAvailable) {
        _log.info(
          'New version available: ${release.version} (current: $currentVersion).',
          tag: 'UpdateCheck',
        );
      } else {
        _log.info('No update available.', tag: 'UpdateCheck');
      }

      return UpdateCheckResult(
        isUpdateAvailable: isUpdateAvailable,
        currentVersion: currentVersion,
        latestVersion: release.version,
        latestRelease: release,
      );
    } else if (response.statusCode == 404) {
      // リリースが存在しない場合
      _log.warning('No releases found on GitHub.', tag: 'UpdateCheck');
      return UpdateCheckResult(
        isUpdateAvailable: false,
        currentVersion: currentVersion,
        errorMessage: 'リリースが見つかりませんでした。',
      );
    } else {
      // その他の API エラー
      _log.warning(
        'GitHub API returned status ${response.statusCode}.',
        tag: 'UpdateCheck',
      );
      return UpdateCheckResult(
        isUpdateAvailable: false,
        currentVersion: currentVersion,
        errorMessage: 'GitHub API エラー (${response.statusCode})',
      );
    }
  }

  /// キャッシュをクリア
  void clearCache() {
    _cachedResult = null;
  }
}
