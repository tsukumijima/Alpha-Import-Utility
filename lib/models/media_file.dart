/// メディアファイル関連のモデル定義
///
/// Sony α カメラの SD カードから取り込むメディアファイルの情報を保持する。
library;

/// メディアファイルの種類
///
/// Sony α カメラで撮影・生成されるファイルの種類を表す。
/// 取り込み処理やサブフォルダ分類に使用される。
enum MediaType {
  /// JPEG 静止画（.JPG, .JPEG）
  JpegPhoto,

  /// RAW 静止画（.ARW）- Sony 独自の RAW フォーマット
  RawPhoto,

  /// HEIF 静止画（.HIF, .HEIF）
  HeifPhoto,

  /// 本編動画（.MP4）- PRIVATE/M4ROOT/CLIP/ に格納
  Video,

  /// プロキシ動画（.MP4）- PRIVATE/M4ROOT/SUB/ に格納
  /// 編集用の低解像度版動画
  ProxyVideo,

  /// 動画メタデータ（.XML）- NonRealTimeMeta 形式
  /// 撮影日時やカメラ情報などを含む
  VideoMeta,
}

/// MediaType の拡張メソッド
extension MediaTypeExtension on MediaType {
  /// ファイル拡張子からメディアタイプを判定する
  ///
  /// [extension] はドットを含む拡張子（例: '.ARW', '.jpg'）
  /// [isProxyFolder] が true の場合、MP4 は ProxyVideo として扱う
  /// 該当しない場合は null を返す
  static MediaType? fromExtension(String extension, {bool isProxyFolder = false}) {
    final lowerExt = extension.toLowerCase();

    switch (lowerExt) {
      case '.jpg':
      case '.jpeg':
        return MediaType.JpegPhoto;
      case '.arw':
        return MediaType.RawPhoto;
      case '.hif':
      case '.heif':
        return MediaType.HeifPhoto;
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
    return this == MediaType.JpegPhoto ||
        this == MediaType.RawPhoto ||
        this == MediaType.HeifPhoto;
  }

  /// 動画かどうか（プロキシ含む）
  bool get isVideo {
    return this == MediaType.Video || this == MediaType.ProxyVideo;
  }

  /// 日本語での表示名
  String get displayName {
    switch (this) {
      case MediaType.JpegPhoto:
        return 'JPEG 写真';
      case MediaType.RawPhoto:
        return 'RAW 写真';
      case MediaType.HeifPhoto:
        return 'HEIF 写真';
      case MediaType.Video:
        return '動画';
      case MediaType.ProxyVideo:
        return 'プロキシ動画';
      case MediaType.VideoMeta:
        return '動画メタデータ';
    }
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

  /// EXIF またはメタデータから取得した撮影日時
  ///
  /// 取得できなかった場合は null
  final DateTime? exifDateTime;

  /// ファイルシステム上の更新日時
  ///
  /// EXIF が取得できない場合のフォールバックとして使用
  final DateTime fileModifiedTime;

  /// xxHash64 ハッシュ値（16 進数文字列）
  ///
  /// 遅延計算されるため、初期値は null
  /// ハッシュ計算後に設定される
  String? xxHash;

  /// SD カードルートへの絶対パス
  ///
  /// 相対パスと組み合わせて完全なパスを生成するために使用
  final String sdCardRoot;

  MediaFile({
    required this.relativePath,
    required this.fileName,
    required this.baseName,
    required this.extension,
    required this.type,
    required this.fileSize,
    required this.exifDateTime,
    required this.fileModifiedTime,
    required this.sdCardRoot,
    this.xxHash,
  });

  /// 完全なファイルパスを取得
  String get absolutePath => '$sdCardRoot/$relativePath';

  /// 取り込み時に使用する日時を取得
  ///
  /// EXIF 日時が有効な場合はそれを使用し、
  /// 無効または取得できなかった場合はファイル更新日時を使用する。
  /// EXIF 日時の有効性は _isValidExifDateTime で判定する。
  DateTime get effectiveDateTime {
    if (exifDateTime != null && _isValidExifDateTime(exifDateTime!)) {
      return exifDateTime!;
    }
    return fileModifiedTime;
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
    return other is MediaFile &&
        other.relativePath == relativePath &&
        other.sdCardRoot == sdCardRoot;
  }

  @override
  int get hashCode => relativePath.hashCode ^ sdCardRoot.hashCode;
}
