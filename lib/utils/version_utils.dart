/// バージョン比較ユーティリティ
///
/// セマンティックバージョニング（SemVer）に基づいた
/// バージョン文字列の比較機能を提供する。
library;

/// セマンティックバージョンを表すクラス
///
/// 'major.minor.patch' 形式のバージョン文字列をパースし、
/// 比較可能な形式で保持する。
/// プレリリースサフィックス（-alpha, -beta など）は現時点では未対応。
class SemanticVersion implements Comparable<SemanticVersion> {
  /// メジャーバージョン
  final int major;

  /// マイナーバージョン
  final int minor;

  /// パッチバージョン
  final int patch;

  /// 元のバージョン文字列
  final String raw;

  SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.raw,
  });

  /// バージョン文字列をパースして SemanticVersion を生成
  ///
  /// [versionString] は '1.0.0' または 'v1.0.0' 形式を受け付ける。
  /// パースに失敗した場合は null を返す。
  ///
  /// 例:
  /// ```dart
  /// final version = SemanticVersion.tryParse('1.2.3');
  /// print(version?.major); // 1
  /// print(version?.minor); // 2
  /// print(version?.patch); // 3
  /// ```
  static SemanticVersion? tryParse(String versionString) {
    // 'v' プレフィックスを除去
    var normalized = versionString.trim();
    if (normalized.toLowerCase().startsWith('v')) {
      normalized = normalized.substring(1);
    }

    // プレリリースサフィックス（-alpha など）を除去
    final hyphenIndex = normalized.indexOf('-');
    if (hyphenIndex != -1) {
      normalized = normalized.substring(0, hyphenIndex);
    }

    // ビルドメタデータ（+build など）を除去
    final plusIndex = normalized.indexOf('+');
    if (plusIndex != -1) {
      normalized = normalized.substring(0, plusIndex);
    }

    final parts = normalized.split('.');
    if (parts.length < 2 || parts.length > 3) {
      return null;
    }

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patchValue = parts.length >= 3 ? int.tryParse(parts[2]) : 0;

    if (major == null || minor == null || patchValue == null) {
      return null;
    }

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patchValue,
      raw: versionString,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    // メジャーバージョンを比較
    if (major != other.major) {
      return major.compareTo(other.major);
    }

    // マイナーバージョンを比較
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }

    // パッチバージョンを比較
    return patch.compareTo(other.patch);
  }

  /// 他のバージョンより新しいかどうか
  bool isNewerThan(SemanticVersion other) => compareTo(other) > 0;

  /// 他のバージョンより古いかどうか
  bool isOlderThan(SemanticVersion other) => compareTo(other) < 0;

  /// 他のバージョンと同じかどうか
  bool isSameAs(SemanticVersion other) => compareTo(other) == 0;

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SemanticVersion && other.major == major && other.minor == minor && other.patch == patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// 2 つのバージョン文字列を比較する
///
/// [version1] が [version2] より新しい場合は正の値、
/// 古い場合は負の値、同じ場合は 0 を返す。
/// パースに失敗した場合は null を返す。
///
/// 例:
/// ```dart
/// compareVersions('1.1.0', '1.0.0'); // 正の値（1.1.0 の方が新しい）
/// compareVersions('1.0.0', '1.1.0'); // 負の値（1.0.0 の方が古い）
/// compareVersions('1.0.0', '1.0.0'); // 0（同じ）
/// ```
int? compareVersions(String version1, String version2) {
  final v1 = SemanticVersion.tryParse(version1);
  final v2 = SemanticVersion.tryParse(version2);

  if (v1 == null || v2 == null) {
    return null;
  }

  return v1.compareTo(v2);
}

/// 新しいバージョンが利用可能かどうかを判定する
///
/// [currentVersion] より [latestVersion] が新しい場合に true を返す。
/// パースに失敗した場合は false を返す（安全側に倒す）。
bool isNewerVersionAvailable(String currentVersion, String latestVersion) {
  final current = SemanticVersion.tryParse(currentVersion);
  final latest = SemanticVersion.tryParse(latestVersion);

  if (current == null || latest == null) {
    return false;
  }

  return latest.isNewerThan(current);
}
