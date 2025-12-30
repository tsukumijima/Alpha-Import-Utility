/// メディアファイル関連のモデル定義
///
/// Sony α カメラの SD カードから取り込むメディアファイルの情報を保持する。
library;

import 'package:path/path.dart' as p;

/// メディアファイルの種類
///
/// Sony α カメラで撮影・生成されるファイルの種類を表す。
/// 取り込み処理やサブフォルダ分類に使用される。
enum MediaType {
  /// JPEG 静止画（.JPG, .JPEG）
  JPEGPhoto,

  /// RAW 静止画（.ARW）- Sony 独自の RAW フォーマット
  RAWPhoto,

  /// HEIF 静止画（.HIF, .HEIF）
  HEIFPhoto,

  /// 本編動画（.MP4）- PRIVATE/M4ROOT/CLIP/ に格納
  Video,

  /// プロキシー動画（.MP4）- PRIVATE/M4ROOT/SUB/ に格納
  /// 編集用の低解像度版動画
  ProxyVideo,

  /// 動画メタデータ（.XML）- NonRealTimeMeta 形式
  /// 撮影日時やカメラ情報などを含む
  VideoMeta,

  /// 未知のファイル（取り込み対象外）
  Unknown,
}

/// MediaType の拡張メソッド
extension MediaTypeExtension on MediaType {
  /// ファイル拡張子からメディアタイプを判定する
  ///
  /// [extension] はドットを含む拡張子（例: '.ARW', '.jpg'）
  /// [isProxyFolder] が true の場合、MP4 は ProxyVideo として扱う
  /// 該当しない場合は null を返す
  static MediaType? fromExtension(
    String extension, {
    bool isProxyFolder = false,
  }) {
    final lowerExt = extension.toLowerCase();

    switch (lowerExt) {
      case '.jpg':
      case '.jpeg':
        return MediaType.JPEGPhoto;
      case '.arw':
        return MediaType.RAWPhoto;
      case '.hif':
      case '.heif':
        return MediaType.HEIFPhoto;
      case '.mp4':
        return isProxyFolder ? MediaType.ProxyVideo : MediaType.Video;
      case '.xml':
        return MediaType.VideoMeta;
      default:
        return null;
    }
  }

  /// 静止画かどうか
  bool get isPhoto {
    return this == MediaType.JPEGPhoto || this == MediaType.RAWPhoto || this == MediaType.HEIFPhoto;
  }

  /// 動画かどうか（プロキシー含む）
  bool get isVideo {
    return this == MediaType.Video || this == MediaType.ProxyVideo;
  }
}

/// メディアファイルの情報を保持するクラス
///
/// SD カード上の写真・動画ファイルの情報を表す。
/// 取り込み判定やコピー処理に必要な情報を含む。
class MediaFile {
  /// SD カードルートからの相対パス（例: 'DCIM/100MSDCF/DSC00001.ARW'）
  final String relativePath;

  /// ファイル名のみ（例: 'DSC00001.ARW'）
  final String fileName;

  /// 拡張子を除いたベース名（例: 'DSC00001'）
  final String baseName;

  /// 拡張子（ドット含む、例: '.ARW'）
  final String extension;

  /// メディアの種別
  final MediaType type;

  /// ファイルサイズ（バイト）
  final int fileSize;

  /// EXIF またはメタデータから取得した撮影日時（カメラのローカル時刻）
  ///
  /// 取得できなかった場合は null
  final DateTime? exifDateTimeLocal;

  /// EXIF またはメタデータから取得した撮影日時（UTC ミリ秒）
  ///
  /// 取得できなかった場合は null
  final int? exifDateTimeUtcMs;

  /// EXIF にタイムゾーン情報が含まれていたか
  final bool hasExifTimezone;

  /// 取り込み元ファイルの作成日時（UTC ミリ秒）
  final int sourceCreatedTimeUtcMs;

  /// 取り込み元ファイルの更新日時（UTC ミリ秒）
  final int sourceModifiedTimeUtcMs;

  /// 絶対的な撮影開始日時（UTC ミリ秒）
  ///
  /// 取得順序に従って必ず決定される。
  final int capturedStartTimeUtcMs;

  /// 絶対的な撮影終了日時（UTC ミリ秒）
  ///
  /// 写真の場合は開始日時と同じになる。
  final int capturedEndTimeUtcMs;

  /// サブフォルダ命名に使用する撮影日時（カメラのローカル時刻）
  final DateTime captureLocalDateTime;

  /// xxHash64 ハッシュ値（16 進数文字列）
  ///
  /// 遅延計算されるため、初期値は null
  /// ハッシュ計算後に設定される
  String? xxHash;

  /// SD カードルートへの絶対パス
  ///
  /// 相対パスと組み合わせて完全なパスを生成するために使用
  final String sdCardRoot;

  /// MediaFile を生成する
  MediaFile({
    required this.relativePath,
    required this.fileName,
    required this.baseName,
    required this.extension,
    required this.type,
    required this.fileSize,
    required this.exifDateTimeLocal,
    required this.exifDateTimeUtcMs,
    required this.hasExifTimezone,
    required this.sourceCreatedTimeUtcMs,
    required this.sourceModifiedTimeUtcMs,
    required this.capturedStartTimeUtcMs,
    required this.capturedEndTimeUtcMs,
    required this.captureLocalDateTime,
    required this.sdCardRoot,
    this.xxHash,
  });

  /// 完全なファイルパスを取得
  String get absolutePath => p.join(sdCardRoot, relativePath);

  /// 取り込み時に使用する日時（カメラのローカル時刻）を取得
  DateTime get effectiveDateTimeLocal => captureLocalDateTime;

  /// 取り込み時に使用する日時（UTC）を取得
  DateTime get effectiveDateTimeUtc {
    return DateTime.fromMillisecondsSinceEpoch(
      capturedStartTimeUtcMs,
      isUtc: true,
    );
  }

  /// EXIF 日時が有効かどうかを判定
  ///
  /// 2010 年以前、または現在から 1 年以上先の日時は異常値として扱う
  bool _isValidExifDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final minValidDate = DateTime(2010, 1, 1);
    final maxValidDate = now.add(const Duration(days: 365));

    return dateTime.isAfter(minValidDate) && dateTime.isBefore(maxValidDate);
  }

  /// EXIF 日時が有効かどうかを取得
  bool get isExifDateTimeValid => exifDateTimeLocal != null && _isValidExifDateTime(exifDateTimeLocal!);

  /// 取り込み元ファイルの作成日時（UTC）を取得
  DateTime get sourceCreatedTimeUtc {
    return DateTime.fromMillisecondsSinceEpoch(
      sourceCreatedTimeUtcMs,
      isUtc: true,
    );
  }

  /// 取り込み元ファイルの更新日時（UTC）を取得
  DateTime get sourceModifiedTimeUtc {
    return DateTime.fromMillisecondsSinceEpoch(
      sourceModifiedTimeUtcMs,
      isUtc: true,
    );
  }

  /// 取り込み元ファイルの参照日時（UTC）
  ///
  /// 作成日時と更新日時のうち古い方を使用する。
  DateTime get sourceReferenceTimeUtc {
    final referenceMs = sourceCreatedTimeUtcMs <= sourceModifiedTimeUtcMs
        ? sourceCreatedTimeUtcMs
        : sourceModifiedTimeUtcMs;
    return DateTime.fromMillisecondsSinceEpoch(referenceMs, isUtc: true);
  }

  /// 絶対的な撮影終了日時（UTC）を取得
  DateTime get capturedEndTimeUtc {
    return DateTime.fromMillisecondsSinceEpoch(
      capturedEndTimeUtcMs,
      isUtc: true,
    );
  }

  /// ファイルサイズを人間が読みやすい形式で取得
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  @override
  String toString() {
    return 'MediaFile(relativePath: $relativePath, type: $type, size: $formattedFileSize)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaFile && other.relativePath == relativePath && other.sdCardRoot == sdCardRoot;
  }

  @override
  int get hashCode => relativePath.hashCode ^ sdCardRoot.hashCode;
}
