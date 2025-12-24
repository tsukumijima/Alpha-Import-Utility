# Alpha Import Utility - AGENTS

## プロジェクト概要

Sony α カメラの SD カードから未取り込みの写真・動画を PC に安全に取り込む Flutter Desktop アプリです。対応プラットフォームは Windows と macOS で、「上書きしない」「削除しない」を最優先とし、データ破壊を絶対に避ける設計になっています。

### 技術スタック

- **フレームワーク**: Flutter 3.x Desktop (Dart 3.10+)
- **ターゲット**: Windows / macOS（モバイルは対象外）
- **ハッシュ**: xxHash3 (xxh3 パッケージ)
- **EXIF**: exif_reader (ARW/HEIF/JPEG 対応)
- **デバイス検出**: disks_desktop
- **JSON**: json_annotation + json_serializable

---

## アーキテクチャ

### ディレクトリ構成

```
lib/
├── main.dart            # エントリポイント（ウィンドウ初期化）
├── app.dart             # ルートウィジェット（MaterialApp）
├── models/              # データモデル
│   ├── models.dart      # バレルファイル
│   ├── media_file.dart  # MediaFile, MediaType
│   ├── settings.dart    # ImportSettings, WindowSettings, enum 群
│   └── import_result.dart  # ImportResult, ImportMetadata, ImportWarning 等
├── services/            # ビジネスロジック
│   ├── services.dart    # バレルファイル
│   ├── sony_filesystem.dart   # SD カード構造検証・スキャン
│   ├── import_engine.dart     # 取り込み処理の中核
│   ├── metadata_manager.dart  # PRIVATE/AIU/METADATA.JSON 管理
│   ├── device_detector.dart   # リムーバブルドライブ検出
│   ├── settings_service.dart  # 設定の永続化
│   └── logging_service.dart   # ログ出力（シングルトン）
├── utils/               # ユーティリティ関数
│   ├── utils.dart       # バレルファイル
│   ├── exif_utils.dart  # EXIF / 動画 XML 日時読み取り
│   ├── file_utils.dart  # ファイル操作（日時復元、重複名生成等）
│   ├── hash_utils.dart  # xxHash64 計算
│   └── timezone_utils.dart  # タイムゾーン変換
└── ui/                  # UI 層
    ├── home_screen.dart     # メイン画面
    ├── import_dialog.dart   # 取り込みダイアログ
    ├── settings_dialog.dart # 設定ダイアログ
    ├── theme.dart           # テーマ定義
    └── widgets/             # 再利用ウィジェット
        ├── device_card.dart
        └── progress_indicator.dart
test/
├── fixtures/
│   └── test_helper.dart  # モック SD カード構造生成
├── services/             # サービス層テスト
└── utils/                # ユーティリティ層テスト
```

### レイヤー間の依存関係

```
ui/ → services/ → models/
          ↓
       utils/
```

- `models/` は純粋なデータクラス（他に依存しない）
- `utils/` はステートレスな関数群
- `services/` はビジネスロジック（モデルとユーティリティを使用）
- `ui/` はサービスを呼び出して画面を構築

---

## 主要コンポーネント

### SonyFilesystemService (`services/sony_filesystem.dart`)

Sony α カメラの SD カード構造を検証し、取り込み対象ファイルをスキャンするサービスです。

**検証条件**:
1. `DCIM/` フォルダが存在する
2. `DCIM/` 内に DCF フォルダ（`100MSDCF` 形式）が存在する
3. `PRIVATE/M4ROOT/CLIP/` フォルダが存在する

**スキャン対象**:
- 静止画: `.JPG`, `.JPEG`, `.ARW`, `.HIF`, `.HEIF`
- 動画: `.MP4` (`PRIVATE/M4ROOT/CLIP/`)
- プロキシ動画: `.MP4` (`PRIVATE/M4ROOT/SUB/`)
- メタデータ: `.XML` (NonRealTimeMeta)

### ImportEngine (`services/import_engine.dart`)

取り込み処理の中核となるエンジンです。

**処理フロー**:
1. SD カード構造の検証
2. 書き込み可能性の確認（メタデータ更新のため）
3. 対象ファイルのスキャン
4. 保存先容量チェック
5. ファイルごとの取り込み処理
   - ストリーミングコピー + ハッシュ計算
   - ハッシュ検証（失敗時は最大 3 回リトライ）
   - 日時復元（EXIF → ファイル作成日時/更新日時）
   - メタデータ更新

### MetadataManager (`services/metadata_manager.dart`)

`PRIVATE/AIU/METADATA.JSON` ファイルを管理し、取り込み済みファイルの記録を行います。

**主な機能**:
- 取り込み済みファイルの記録・検索
- 一時ファイル + リネームによる安全な書き込み
- ロックファイルによる排他制御
- キャッシュによる読み取り最適化

### DeviceDetector (`services/device_detector.dart`)

リムーバブルドライブを検出し、Sony SD カードを識別します。

**機能**:
- 5 秒間隔のポーリングによるデバイス監視
- macOS システムボリュームの自動除外
- 手動フォルダ追加のサポート
- 取り込み中のポーリング一時停止

---

## 重要な設計ルール

### データ安全性（最重要）

1. **取り込み元のファイルは絶対に削除しない**
2. **上書きしない** - 同名ファイルは ` (1)`, ` (2)` ... のサフィックスで保存
3. **メタデータ更新失敗は即中断** - 環境異常とみなして fail-fast

### タイムゾーン処理

EXIF にタイムゾーン情報（`OffsetTimeOriginal` など）がある場合はそれを優先し、ない場合のみ `cameraTimezone` 設定をフォールバックとして使用します。動画の XML メタデータも同様です。

```
EXIF OffsetTimeOriginal → EXIF OffsetTime → cameraTimezone 設定
```

### 日時復元

コピー後のファイルに EXIF の撮影日時を反映します。

- **Windows**: PowerShell で `CreationTime`, `LastWriteTime` を設定
- **macOS**: `SetFile` コマンドで作成日時を設定

`SetFile` が利用できない環境（Xcode Command Line Tools 未インストール）では `UnsupportedError` をスローして中断します。

### ファイル名規則

- プロキシ動画: `{ベース名}_proxy.MP4`
- 重複時: `{ベース名} (1).{拡張子}`, `{ベース名} (2).{拡張子}`, ...

---

## コーディング規約

### 言語

- **コメント**: 日本語
- **ログ本文**: 英語、ピリオドで終わる（例: `'Import completed.'`）
- **ユーザー向けメッセージ**: 日本語、句点で終わる

### スタイル

```dart
// シングルクォートを使用
final message = 'Hello';

// 末尾カンマを付ける（複数行の引数・配列・マップ）
final settings = ImportSettings(
  destinationFolder: '/path/to/dest',
  subfolderPattern: SubfolderPattern.DateOnly,
);

// 英単語と日本語の間にスペース
// 例: 'Sony α カメラの SD カード構造を検証する'
```

### 命名規則

- **bool 値**: `is`, `has`, `can`, `should` 接頭辞を使用
  - ✓ `isImported`, `hasDestinationFolder`, `canEdit`
  - ✗ `imported`, `edit`
- **enum 値**: UpperCamelCase（Dart 標準の lowerCamelCase を無効化）
  - ✓ `MediaType.JPEGPhoto`
  - ✗ `MediaType.jpegPhoto`
- **関数・メソッド**: 必ず `///` ドキュメントコメントを付ける（private 含む）

### フォーマット

```yaml
# analysis_options.yaml
formatter:
  page_width: 120
  trailing_commas: preserve
linter:
  rules:
    constant_identifier_names: false  # enum の UpperCamelCase を許可
```

---

## テスト

### テスト構成

```
test/
├── fixtures/test_helper.dart  # モック SD カード構造生成ヘルパー
├── services/
│   ├── sony_filesystem_test.dart
│   ├── metadata_manager_test.dart
│   └── import_engine_test.dart
└── utils/
    ├── exif_utils_test.dart
    └── hash_utils_test.dart
```

### テストヘルパーの使い方

```dart
// 一時ディレクトリを作成
final (tempPath, cleanup) = await createTempDirectory();

try {
  // モック SD カード構造を作成
  await createMockSdCardStructure(
    tempPath,
    mockFiles: [
      MockMediaFile.jpeg('DSC00001'),
      MockMediaFile.arw('DSC00001'),
      MockMediaFile.video('C0001'),
    ],
  );

  // テスト実行
  // ...
} finally {
  await cleanup();
}
```

---

## 作業手順

### 編集後の必須コマンド

```bash
# フォーマット
dart format .

# 静的解析
flutter analyze

# JSON シリアライズコードの再生成（.g.dart ファイル）
dart run build_runner build --delete-conflicting-outputs
```

### テスト実行

```bash
# 全テスト
flutter test

# 特定ファイル
flutter test test/services/sony_filesystem_test.dart

# 特定テスト
flutter test --name "should validate valid Sony SD card structure"
```

---

## 禁止事項

1. **UI/UX の無断変更禁止** - レイアウト、色、フォント、余白などの変更は事前承認必須
2. **依存関係バージョンの無断変更禁止** - 変更が必要な場合は理由を明示して承認を得る
3. **既存コメントの削除禁止** - 設計意図が含まれているため保持する
4. **取り込み元ファイルの削除処理の実装禁止** - データ安全性の原則に反する

---

## 注意点

### Sony SD カード構造

```
SD_CARD_ROOT/
├── DCIM/
│   ├── 100MSDCF/       # 静止画（JPEG, ARW, HEIF）
│   └── 101MSDCF/       # 番号は増加していく
├── PRIVATE/
│   ├── M4ROOT/
│   │   ├── CLIP/       # 本編動画（MP4, XML）
│   │   └── SUB/        # プロキシ動画
│   └── AIU/            # このアプリのメタデータ
│       └── METADATA.JSON
└── (その他 Sony 固有フォルダ)
```

### PMHOME ボリューム

Sony カメラの一部機種では、SD カードに PMHOME というライセンス情報用の小さなパーティションが存在します。これは取り込み対象外としてスキップします。

### 書き込み中ファイル

ファイルの更新日時が現在から 30 秒以内の場合、カメラが書き込み中の可能性があるとみなしてスキップします。
