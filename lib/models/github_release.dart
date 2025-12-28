/// GitHub Release API のレスポンスを表すモデル
///
/// GitHub の /repos/{owner}/{repo}/releases/latest エンドポイントから
/// 取得したリリース情報を保持する。
library;

import 'package:json_annotation/json_annotation.dart';

part 'github_release.g.dart';

/// GitHub Release 情報
///
/// アップデートチェックに必要な最小限のフィールドのみを定義。
@JsonSerializable()
class GitHubRelease {
  /// リリースのタグ名（例: 'v1.0.0'）
  @JsonKey(name: 'tag_name')
  final String tagName;

  /// リリースページの URL
  @JsonKey(name: 'html_url')
  final String htmlUrl;

  /// リリース名（タグ名と異なる場合がある、null の可能性あり）
  final String? name;

  /// リリースノート（Markdown 形式、null の可能性あり）
  final String? body;

  /// ドラフトリリースかどうか
  @JsonKey(name: 'draft', defaultValue: false)
  final bool isDraft;

  /// プレリリースかどうか
  @JsonKey(name: 'prerelease', defaultValue: false)
  final bool isPrerelease;

  /// 公開日時
  @JsonKey(name: 'published_at')
  final String? publishedAt;

  GitHubRelease({
    required this.tagName,
    required this.htmlUrl,
    this.name,
    this.body,
    this.isDraft = false,
    this.isPrerelease = false,
    this.publishedAt,
  });

  /// JSON からデシリアライズ
  factory GitHubRelease.fromJson(Map<String, dynamic> json) => _$GitHubReleaseFromJson(json);

  /// JSON にシリアライズ
  Map<String, dynamic> toJson() => _$GitHubReleaseToJson(this);

  /// タグ名からバージョン文字列を抽出
  ///
  /// 'v1.0.0' -> '1.0.0'
  /// '1.0.0' -> '1.0.0'
  String get version {
    final tag = tagName.trim();
    if (tag.toLowerCase().startsWith('v')) {
      return tag.substring(1);
    }
    return tag;
  }

  /// 表示用のリリース名を取得
  ///
  /// name が null の場合は tagName を使用
  String get displayName => name ?? tagName;
}
