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
- プロキシー動画: `.MP4` (`PRIVATE/M4ROOT/SUB/`)
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

撮影日時の内部表現は UTC ミリ秒（絶対時刻）で保持し、サブフォルダ命名や UI 表示にはカメラのローカル時刻を使います。

### 撮影日時の解決ロジック（実装済み）

写真は EXIF にタイムゾーンがある場合はそれを最優先で採用し、無い場合は `cameraTimezone` をフォールバックとして解釈して UTC を導出します。EXIF が取れない場合は、同一フォルダ内の同名 JPEG/HIF の EXIF を RAW にフォールバック適用し、それでも取れない場合は作成日時・更新日時のうち古い方を参照時刻として採用します。

動画は XML（NonRealTimeMeta）から録画開始時刻とフレーム情報を読み取り、開始時刻と終了時刻を算出します。XML がない場合はファイル時刻にフォールバックします。

### 日時復元の判定基準（実装済み）

写真は作成/更新のうち古い方を参照時刻とし、撮影日時との差が `dateRestoreToleranceSeconds` 秒以内なら元の時刻を維持します。差が許容範囲外なら撮影日時に統一して復元します。

動画は録画開始・終了時刻がそれぞれ作成・更新時刻と許容誤差内なら元の時刻を維持し、ズレている場合は開始・終了時刻に置き換えます。

### EXIF パースの性能（重要）

`exif_reader` のデフォルト設定は詳細解析（MakerNote やサムネイル抽出）まで行うため、1 ファイル数十秒かかることがありました。現在は `readExifFromSource` を **details=false / truncateTags=true** で呼び出すように変更し、実測で 10〜50ms 程度まで改善しています。この設定は実運用性能に直結するため、理由なく元に戻さないでください。

性能検証には `tooling/exif_benchmark.dart` を使います。`test/fixtures/sample_media` の実データを用いて EXIF パース時間を測定できるので、変更時は必ずベンチマークを確認してください。

### 日時復元

コピー後のファイルに EXIF/XML 由来の撮影日時を反映します。

- **Windows**: MethodChannel 経由で Win32 API（`SetFileTime`）を使用
- **macOS**: MethodChannel 経由で `URLResourceValues` を使用

ネイティブ実装が利用できない場合は異常とみなし、fail-fast で中断します。

### ファイル名規則

- **基本**: 取り込み元のファイル名を維持する
- **重複時**: `{ベース名} (1).{拡張子}`, `{ベース名} (2).{拡張子}`, ...

### 取り込み判定の優先順位（実装済み）

メタデータに記録がある場合は、記録先パスにファイルが存在すればスキップします。記録先が存在しない場合は PC 側で消されたとみなし再取り込みします。メタデータに記録が無い場合は、コピー先に同名ファイルがあるかをチェックし、同一ハッシュならスキップ、異なる場合は重複サフィックスで別名保存します。

### 取り込み中ファイルの扱い

更新日時が現在から 30 秒以内のファイルは書き込み中とみなしスキップします。安全側に倒すため、判定に失敗した場合も書き込み中扱いにします。

### 進捗とログ

スキャン中の進捗は 50 ファイルごとにログ出力されます。ファイル単位の進捗は ImportEngine から通知され、UI 側のプログレス表示に使われます。ログは英語でピリオド終端を厳守します。

### フェイルファスト方針（実装済み）

メタデータ保存の失敗や SD カードの書き込み不可は即中断します。ファイルコピー中の I/O エラーや日時復元の致命的失敗も中断対象です。警告扱いで継続するのは、ファイル単位の軽微な問題（EXIF 読み取り失敗など）に限ります。

中断時は UI の取り込みダイアログに **中断理由** を表示し、ユーザーが離席していても原因が分かるようにします。I/O 例外は握りつぶさずに伝播させ、ImportEngine が中断理由を生成して表示します。

### テスト戦略（実装済み）

ユニットテストは `test/` 配下で実施し、`test/fixtures/sample_media` の実データを使います。`sample_media` は Git 管理対象外なので、ローカルに配置されていることが前提です。

E2E では `integration_test/import_flow_test.dart` を実行し、実際のファイルコピー・メタデータ更新・日時復元まで通るかを検証します。MethodChannel を使うため、**macOS / Windows 実機でのみ**成立します。コマンドは `flutter test integration_test` です。

### EXIF ベンチマーク手順（重要）

`tooling/exif_benchmark.dart` を実行すると、実ファイルで EXIF 解析時間を測定できます。

```
dart run tooling/exif_benchmark.dart
```

EXIF 周りのコードを変更した場合は必ずベンチを取り、パースが数十 ms 程度であることを確認してください。

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

```
integration_test/
└── import_flow_test.dart  # MethodChannel を含む統合テスト
```

### MethodChannel の扱い

Unit テストでは MethodChannel をモックしているため、ネイティブ実装の検証は integration_test で行う。integration_test は Windows/macOS の実環境で実行すること。

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
# JSON シリアライズコードの再生成（.g.dart ファイル）
dart run build_runner build --delete-conflicting-outputs

# 静的解析
flutter analyze

# フォーマット (g.dart 生成後は必ず実行すること)
dart format .
```

### テスト実行

```bash
# 全テスト
flutter test

# 特定ファイル
flutter test test/services/sony_filesystem_test.dart

# 特定テスト
flutter test --name "should validate valid Sony SD card structure"

# integration_test（ネイティブ MethodChannel を含む）
flutter test integration_test
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
│   │   └── SUB/        # プロキシー動画
│   └── AIU/            # このアプリのメタデータ
│       └── METADATA.JSON
└── (その他 Sony 固有フォルダ)
```

### PMHOME ボリューム

Sony カメラの一部機種では、SD カードに PMHOME というライセンス情報用の小さなパーティションが存在します。これは取り込み対象外としてスキップします。

### 書き込み中ファイル

ファイルの更新日時が現在から 30 秒以内の場合、カメラが書き込み中の可能性があるとみなしてスキップします。
