# YadoSearch（宿さがし）

日本の宿・ホテルを探す iOS / iPadOS / macOS アプリです。[じゃらん Web サービス](https://www.jalan.net/jw/jwp0000/jww0001.do)を使い、**キーワード（宿名）・現在地・地域・駅**の4つの軸で宿を検索します。

2010 年に App Store でリリースした「宿さがし」（[App Store ID 347959354](https://apps.apple.com/jp/app/id347959354)、最終 2.0.4）の後継です。2014 年に UIKit で書きかけだった v3 を捨て、リリース版の機能を引き継ぐ形で SwiftUI で作り直しました。Bundle ID は当時の `org.ngsdev.iphone.Yado` のままで、既存レコードへのアップデートとして出せます。

## できること

- **キーワード検索** — 宿名の一部で探す
- **現在地検索** — Core Location で現在地を取り、まわり約1km〜約10kmの宿を探す。座標は逆ジオコーディングして「東京都千代田区」のように表示
- **地域検索** — 広域 → 都道府県 → 大エリア → 小エリアのドリルダウン。どの階層でも検索できる
- **駅検索** — MapKit で駅の位置を調べ、そのまわりの宿を探す
- **絞り込み** — 並び順（50音／料金順／じゃらんnet人気順）、宿の種類、予算、人数構成（大人・小学生・幼児4区分）、設備・立地・食事・部屋タイプ・クレジットカードなど約70条件
- **宿詳細** — 写真・地図・アクセス・チェックイン/アウト・宿泊プランと料金。じゃらん net の予約ページを開ける
- **宿泊プラン検索** — 日付・泊数・人数・部屋数を指定して空室プランと料金を見る
- **お気に入り／閲覧履歴／検索条件の履歴** — SwiftData に保存。オフラインでも一覧が出る（閲覧履歴100件、検索条件20件で打ち止め）。検索条件は1タップで再実行
- **iCloud 同期** — 上記3つは CloudKit のプライベートデータベース経由で端末間同期
- **アフィリエイト** — じゃらん net への外部リンクは ValueCommerce のリファラル経由

| プラットフォーム | 最低バージョン |
|---|---|
| iOS / iPadOS | 26.0+ |
| macOS | 26.0+ |

## セットアップ

### 必要なもの

- Xcode 26.0 以降
- [Tuist](https://tuist.io)（`mise install` で `mise.toml` のバージョンが入ります）
- [direnv](https://direnv.net)
- SwiftLint（`brew install swiftlint`）、Periphery（`brew install periphery`）
- じゃらん Web サービスのアプリケーションキー

### 手順

```bash
echo 'export TUIST_JALAN_API_KEY=…' > .envrc   # 発行されたキーを書く
direnv allow                                   # 初回のみ
tuist generate                                 # Xcode プロジェクトを生成して開く
```

Tuist が `TUIST_JALAN_API_KEY` を `Info.plist` の `JalanAPIKey` に埋め込みます。`.envrc` は gitignore されているのでキーはリポジトリに入りません。

**キーがないビルドは起動時に `fatalError` で落ちます。** 全画面が API に依存するため、動かないビルドを黙って動かすより、出荷前に気づけるようにしています。ビルド自体は通るので、CI（キーなし）のビルドとテストには影響しません。

## 開発コマンド

```bash
tuist generate --no-open        # プロジェクト生成のみ（CI と同じ）
swift test                      # SPM のテスト（Core と ViewModel）
xcodebuild test -workspace YadoSearch.xcworkspace -scheme YadoSearch \
  -destination "id=$(Scripts/latest-ios-simulator.sh)"
Scripts/lint.sh strict          # SwiftLint（CI は --strict）
periphery scan --strict         # 未使用コード検出
bundle exec rubocop             # Ruby（Fastfile など）
open Resources/AppIcon.icon        # アプリアイコンを Icon Composer で編集
```

## 構成

ロジックはローカル SPM パッケージ（`Package.swift`）の3ライブラリにあり、Tuist が管理するアプリターゲットがそれに依存します。

```
YadoSearch/
├── Sources/
│   ├── App/        # アプリのエントリポイント
│   ├── Core/       # YadoSearchCore: じゃらん API クライアントとモデル（Foundation のみ）
│   ├── Platform/   # YadoSearchPlatform: SwiftData / Core Location / MapKit
│   └── UI/         # YadoSearchUI: SwiftUI の画面とビューモデル
├── Resources/      # AppIcon.icon、Assets.xcassets、entitlements
├── Tests/
│   ├── YadoSearchCoreTests/  # 実レスポンスのフィクスチャによるパーサテスト
│   └── YadoSearchUITests/    # ビューモデルと永続化のテスト
├── Scripts/        # lint とシミュレータ選択
├── fastlane/       # match / TestFlight / App Store
└── .github/        # CI・リリース・provision ワークフロー
```

- **YadoSearchCore** — `JalanAPIClient`、`XMLTree`（XMLParser ベースの軽量 DOM）、`Hotel` / `Plan` / `AreaTree`、`SearchFilters` / `GuestParty` / `SavedSearch`、`JalanAffiliate`、測地系変換
- **YadoSearchPlatform** — `StoredHotel`（お気に入りと閲覧履歴を1テーブルで）、`StoredSearch`（検索条件の履歴）、`AreaCatalog`（地域ツリーのディスクキャッシュ）、`CurrentLocationProvider`、`ReverseGeocoder`、`StationSearchService`
- **YadoSearchUI** — 検索画面、絞り込みシート、結果一覧、宿詳細、お気に入り、履歴、設定

## iCloud 同期

お気に入り・閲覧履歴・検索条件の履歴は、SwiftData の CloudKit ミラーリングでプライベートデータベース（`iCloud.org.ngsdev.iphone.Yado`）を経由して同期します。

**CloudKit ミラーリングの制約**（`Tests/YadoSearchUITests/CloudKitSchemaTests.swift` で固定）:

- 永続化するプロパティはすべて optional か既定値つきであること
- `@Attribute(.unique)` は使えない（重複排除は `StoredHotelStore` / `SearchHistoryStore` 側の検索で行っています）
- 破ってもコンパイルは通り、**起動時のコンテナ生成でクラッシュ**します

`YadoSearchModelContainer.make(inMemory:)` は CloudKit → ローカル → メモリの順にフォールバックします。iCloud entitlement のないビルド（CI・シミュレータ）やサインインしていない端末でも起動します。

`aps-environment` は構成ごとに切り替わります（Debug=development / Release=production）。Release で development のまま出すと APNs サンドボックスに登録され、CloudKit のプッシュが届かず「アプリを開いたときしか同期しない」状態になります。

Developer Portal 側の設定は済んでいます。App ID `org.ngsdev.iphone.Yado` は iCloud（CloudKit）と Push Notifications が有効で、コンテナ `iCloud.org.ngsdev.iphone.Yado` が割り当てられています。

プロビジョニングプロファイルにも capability が反映済みなので、`provision.yml` の再実行は不要です。プロファイルは発行時点の entitlements のスナップショットなのでかつては課題でしたが、`MATCH_READONLY=true` のまま署名した Release ビルドが iCloud・APNs の entitlements 込みで App Store Connect に受理されており、古いプロファイルではそうなりません。

## じゃらん Web サービスについて

現在も応答するエンドポイントは3つで、アプリはその3つだけを使っています。

| 用途 | パス |
|---|---|
| 宿検索 | `APIAdvance/HotelSearch/V1/` |
| 空室・プラン検索 | `APIAdvance/StockSearch/V1/` |
| 地域ツリー | `APICommon/AreaSearch/V1/` |

実装するうえで効いてくる、ドキュメントに書かれていない挙動が3つあります。

### 1. 座標は日本測地系（Tokyo Datum）

レスポンスの `<X>` / `<Y>` はミリ秒（1/1000 秒）単位で、**日本測地系**です。帝国ホテル東京は API 上 35.669046N, 139.761581E ですが、実際の WGS 84 の位置は 35.67225N, 139.75892E ——約400m ずれています。そのまま MapKit に渡すとピンが1ブロック外れます。

`TokyoDatum.toWorld(_:)` / `.fromWorld(_:)` が変換します。検索の中心座標も変換して送ります（`datum` パラメータは送っても受けても観測できる差がありません）。

### 2. `range` は距離ではなくコード

`range` は 1〜8 のコードで、意味は公開されていません。東京駅を中心にした検索の全結果を各コードで取得し、最も遠い宿までの距離を測った結果がこれです。

| code | 実測半径 |
|---|---|
| 1 | 約 1.1 km |
| 2 | 約 2.5 km |
| 4 | 約 5.1 km |
| 6 | 約 7.3 km |
| 8 | 約 10.0 km |

`SearchRadius` はこの5つを公開しています。UI が「約」と書いているのはこのためです。

### 3. HTTP のみ

`jws.jalan.net` は 80 番しか開いておらず、443 は閉じています。TLS の代替エンドポイントは存在しないため、そのホストに限定した App Transport Security 例外を `Info.plist` に入れています。写真（`www.jalan.net`）や予約ページは HTTPS のままです。

このため **App Store 審査で `NSExceptionAllowsInsecureHTTPLoads` の説明を求められる可能性があります**。API キーが平文で流れる点も含め、提出前に把握しておいてください。

そのほか:

- 宿名検索は該当が200件を超えるとサーバが結果ではなくエラーを返します。エラー本文は日本語の説明文なので、アプリはそのまま表示します。
- 駅を指定する API パラメータはありません。駅検索は MapKit で座標を引いてから座標検索に流しています。
- `order`（並び順）のコードの意味は公開されていませんが、2010 年版が `FilterConditions_jalan.plist` に持っていた対応表（0 指定なし / 1 50音順 / 2 参考料金の安い順 / 3 参考料金の高い順 / 4 じゃらんnet人気順）が今も有効なことをライブで確認しています。「指定なし」のときは `order` 自体を送らず、座標検索の既定＝近い順を活かします。
- `stay_date` は宿名・広域・都道府県検索では拒否されます。日付指定は空室検索（StockSearch）側だけで使っています。
- 温泉地検索（`o_area_id` / `o_id`）は、温泉地コードを引く API が消えているため実装していません。

## アフィリエイト

じゃらん net への外部リンクは ValueCommerce のリファラルを通します（`JalanAffiliate`）。

```
https://www.jalan.net/yad384352/?dateUndecided=1&adultNum=2&roomCount=1
↓
https://ck.jp.ap.valuecommerce.com/servlet/referral?sid=2462325&pid=892671706
  &vc_url=https%3A%2F%2Fwww.jalan.net%2Fyad384352%2F%3FdateUndecided%3D1%26adultNum%3D2%26roomCount%3D1
```

- `vc_url` は URL 全体を percent-encode したものです。`:` と `/` も含めて予約文字をすべて encode し、残るのは非予約文字（英数字と `-._~`）だけです。
- 宿ページは API の `HotelDetailURL`（`JwsRedirect.do` 経由で API キーを含む）ではなく、`HotelID` から組み立てた canonical な `https://www.jalan.net/yad{HotelID}/` を使います。プランは `PlanCommonDetailURL`（素の jalan.net URL）側を包みます。
- jalan.net 以外のホストは変換せずそのまま返します。
- リファラルの応答は JavaScript でリダイレクトする計測ページなので、`URLSession` ではなくブラウザ（`Link`）で開く必要があります。

## CI / CD

GitHub Actions（`.github/workflows/`）:

- **ci.yml** — iOS / macOS の `xcodebuild test`、`swift test`、SwiftLint、Periphery、RuboCop、両プラットフォームのビルド
- **release.yml** — CI 成功後（または手動実行で）fastlane match で署名し、TestFlight / App Store Connect にアップロード
- **provision.yml** — 署名プロファイルの再発行（手動）
- **ci-actions-versions.yml** — Actions のバージョン追随チェック（Dependabot が PR を出す）

必要な Secrets: `JALAN_API_KEY`、`APP_STORE_CONNECT_API_KEY_*`、`MATCH_GIT_URL`、`MATCH_PASSWORD`、`MATCH_DEPLOY_KEY`。

## 2010 年リリース版からの差分

引き継いだもの: 4タブ構成（さがす／お気に入り／履歴／設定）、地域ドリルダウン、現在地検索、フリーワード（宿名）検索、駅まわりの検索、絞り込み条件一式、ValueCommerce アフィリエイト。

引き継いでいないもの:

- **楽天トラベル** — 当時は じゃらん／楽天トラベル の2サービスを切り替えられました。今回はじゃらんのみです（楽天ウェブサービスのアプリ ID が別途必要）。
- **路線からの駅選択・観光地検索** — 当時は駅と観光地の SQLite を同梱していました。今回は MapKit の検索で駅の座標を引く方式にして、同梱データを持たないようにしています。路線から辿る UX は失われています。
- **共有（ShareKit / Evernote）・広告（AdSense）・Google Analytics** — いずれも現在は使えないか、入れるべきでないものです。

## 現状わかっている制限

- **ローカライズは日本語のみ。** じゃらんが日本国内専用のサービスであるため、開発言語を `ja` にして日本語リテラルで書いています。英語化する場合は String Catalog の導入が必要です。なお逆ジオコーディングだけは端末の言語に追随するので、英語環境では "Chiyoda, Tokyo" と出ます。
- **アプリアイコンは調整中。** `Resources/AppIcon.icon` は Icon Composer で開いて編集できる形式（`icon.json` ＋ `Assets/onsen.svg`）です。温泉マークを白、背景をアクセントカラーのベタ、レイヤーは Liquid Glass 有効にした状態から始めています。
