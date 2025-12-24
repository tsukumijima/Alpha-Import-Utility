/// タイムゾーン関連のユーティリティ
///
/// カメラタイムゾーンの選択肢と、UTC オフセットの解決機能を提供する。
library;

/// タイムゾーン表示用の情報
typedef CameraTimezoneInfo = ({String id, String offset, String name});

/// サポートするタイムゾーンのリスト
///
/// IANA 形式のタイムゾーン名と UTC オフセット、表示名のペア。
/// 主要なタイムゾーンのみを含む。
const List<CameraTimezoneInfo> supportedTimezones = [
  (id: 'Pacific/Honolulu', offset: 'UTC-10:00', name: 'ホノルル'),
  (id: 'America/Anchorage', offset: 'UTC-09:00', name: 'アンカレッジ'),
  (id: 'America/Los_Angeles', offset: 'UTC-08:00', name: 'ロサンゼルス'),
  (id: 'America/Denver', offset: 'UTC-07:00', name: 'デンバー'),
  (id: 'America/Chicago', offset: 'UTC-06:00', name: 'シカゴ'),
  (id: 'America/New_York', offset: 'UTC-05:00', name: 'ニューヨーク'),
  (id: 'America/Sao_Paulo', offset: 'UTC-03:00', name: 'サンパウロ'),
  (id: 'Atlantic/Azores', offset: 'UTC-01:00', name: 'アゾレス'),
  (id: 'UTC', offset: 'UTC+00:00', name: 'UTC'),
  (id: 'Europe/London', offset: 'UTC+00:00', name: 'ロンドン'),
  (id: 'Europe/Paris', offset: 'UTC+01:00', name: 'パリ'),
  (id: 'Europe/Berlin', offset: 'UTC+01:00', name: 'ベルリン'),
  (id: 'Europe/Athens', offset: 'UTC+02:00', name: 'アテネ'),
  (id: 'Europe/Moscow', offset: 'UTC+03:00', name: 'モスクワ'),
  (id: 'Asia/Dubai', offset: 'UTC+04:00', name: 'ドバイ'),
  (id: 'Asia/Karachi', offset: 'UTC+05:00', name: 'カラチ'),
  (id: 'Asia/Kolkata', offset: 'UTC+05:30', name: 'コルカタ'),
  (id: 'Asia/Dhaka', offset: 'UTC+06:00', name: 'ダッカ'),
  (id: 'Asia/Bangkok', offset: 'UTC+07:00', name: 'バンコク'),
  (id: 'Asia/Singapore', offset: 'UTC+08:00', name: 'シンガポール'),
  (id: 'Asia/Hong_Kong', offset: 'UTC+08:00', name: '香港'),
  (id: 'Asia/Shanghai', offset: 'UTC+08:00', name: '上海'),
  (id: 'Asia/Tokyo', offset: 'UTC+09:00', name: '東京'),
  (id: 'Asia/Seoul', offset: 'UTC+09:00', name: 'ソウル'),
  (id: 'Australia/Sydney', offset: 'UTC+10:00', name: 'シドニー'),
  (id: 'Pacific/Auckland', offset: 'UTC+12:00', name: 'オークランド'),
];

/// IANA タイムゾーン ID に対応する UTC オフセット文字列を取得
String? findTimezoneOffset(String timezoneId) {
  for (final timezone in supportedTimezones) {
    if (timezone.id == timezoneId) {
      return timezone.offset;
    }
  }
  return null;
}

/// UTC オフセット文字列を Duration に変換
///
/// 例: 'UTC+09:00' / '+09:00' / 'UTC-05:30'
Duration? parseUtcOffset(String offsetText) {
  final normalized = offsetText.trim().replaceFirst('UTC', '');
  final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(normalized);
  if (match == null) return null;

  final sign = match.group(1) == '-' ? -1 : 1;
  final hours = int.parse(match.group(2)!);
  final minutes = int.parse(match.group(3)!);

  return Duration(hours: hours * sign, minutes: minutes * sign);
}

/// IANA タイムゾーン ID から UTC オフセットを取得
Duration? getTimezoneOffsetDuration(String timezoneId) {
  final offsetText = findTimezoneOffset(timezoneId);
  if (offsetText == null) return null;
  return parseUtcOffset(offsetText);
}
