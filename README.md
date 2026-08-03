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

**API キーは不要です。** 上流の資格情報は [yadosearch-api](https://github.com/ngs/yadosearch-api) プロキシが持っています。

### 手順

```bash
tuist generate                                 # Xcode プロジェクトを生成して開く
```

接続先は既定で Cloud Run のホストです。ローカルのプロキシに向けるには **`YadoSearch (Local)` スキーム**を選びます。起動引数 `-APIHost localhost:8080` が渡ります。

```bash
cd ../yadosearch-api && make run               # プロキシを :8080 で起動
```

**実機で試すときはこの起動引数を Mac の名前か IP に変えてください。** 端末上の `localhost` は端末自身を指します。

接続先が解決できないビルドは起動時に `fatalError` で落ちます。全画面が API に依存するため、動かないビルドを黙って動かすより、出荷前に気づけるようにしています。

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

- **YadoSearchCore** — `Sources/Core/API/`（契約の Codable モデルと `YadoSearchAPIClient`）、`SearchTarget` / `SearchFilters` / `GuestParty` / `SavedSearch`、`AreaTree`、`GeoCoordinate`。Foundation のみ・依存なし
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

## API について

すべて [yadosearch-api](https://github.com/ngs/yadosearch-api) プロキシ経由です。**じゃらん・楽天のどちらにもアプリから直接アクセスしません。**

| 用途 | パス |
|---|---|
| 検索（両サービス統合） | `GET /v1/hotels` |
| 宿1件＋もう一方の同じ宿 | `GET /v1/hotels/{provider}/{id}` |
| 1宿のプラン・空室 | `GET /v1/hotels/{provider}/{id}/plans` |
| じゃらんのエリア階層 | `GET /v1/areas/jalan` |

契約はプロキシ側の `openapi.json` で、`Sources/Core/API/APIModels.swift` がその写しです。デコードのテストはプロキシにコミットされている実レスポンス例を読むので、契約が動けばこちら側も落ちます。

### プロキシ側で解決していること

- **測地系** — じゃらんの座標は日本測地系で、WGS 84 とは約400m ずれます。変換はサーバ側で完結し、アプリに届くのは常に WGS 84 です（東京駅の座標で検索して東京ステーションホテルが 142m、という実測で確認しています）
- **アフィリエイト** — `detailUrl` は ValueCommerce のリファラルに包まれた状態で返ります
- **HTTPS** — じゃらんは 80 番しか開いていませんが、そこはプロキシが終端します。アプリの ATS 例外はローカル開発用の `NSAllowsLocalNetworking` だけです
- **資格情報** — 両サービスのキーはサーバに閉じています

### アプリ側で効いてくること

- **片方のサービスの失敗はエラーではありません。** レスポンスは `results` と `errors` を同時に返します（楽天の 429 は普通に踏みます）。結果は残したまま、下に注記を出します
- **エラーはステータスではなく本文** — `{"error": "…"}` で、多くは上流の日本語メッセージそのままです。だから `searchErrorMessage(for:)` はサービスのメッセージを加工せず表示します
- **`count` はサービスごとの件数** — 同じ宿が両方にあると1行に統合されるので、30 件要求しても行数はそれより少なくなります。ページングは行数ではなくサービス別の総数で判断します
- **絞り込みはじゃらんにしか渡りません** — `amenities` / `hotelType` / `minRate` / `maxRate` / `order` に楽天の対応物がないためです。一覧にその旨を表示します
- **エリア検索は構造上どちらか一方** — じゃらんの階層と楽天の区分はコード体系が別物です
- **楽天には日付なしモードがありません** — プランには `checkIn` が必須です。じゃらんは省略すると参考料金を返します。日付未指定で楽天を選んだ場合は、エラーではなく日付入力を促します
- **検索半径はメートル** — `SearchRadius` は保存済み検索のデコード互換のためにじゃらんの旧コードを rawValue に残していますが、送るのは `approximateMetres` です。**楽天は 3km が上限**です

## アフィリエイト

じゃらん net・楽天トラベルへの外部リンクは、**プロキシ側で** ValueCommerce のリファラルに包まれて返ってきます。アプリは組み立てません。

```
https://www.jalan.net/yad384352/?dateUndecided=1&adultNum=2&roomCount=1
↓
https://ck.jp.ap.valuecommerce.com/servlet/referral?sid=2462325&pid=892671706
  &vc_url=https%3A%2F%2Fwww.jalan.net%2Fyad384352%2F%3FdateUndecided%3D1%26adultNum%3D2%26roomCount%3D1
```

URL の組み立て規則はプロキシ側の `docs/affiliate.md` にあります。アプリ側で守るべきことは2つだけです。

- **リファラルの応答は JavaScript の計測ページ**なので、`URLSession` で取得せずブラウザで開きます。
- **`Link` ではなく `SafariLink` を使います。** jalan.net は universal link を公開しているため、システムに渡すとリダイレクトが じゃらんアプリに奪われ、リファラルが完了せず報酬対象になりません。`SFSafariViewController` は universal link を尊重しないので、ブラウザ内で完結します。macOS には じゃらんアプリも `SFSafariViewController` も無いので `Link` にフォールバックします。アフィリエイト以外のリンク（マップ、App Store）は素の `Link` のままです。

## CI / CD

GitHub Actions（`.github/workflows/`）:

- **ci.yml** — iOS / macOS の `xcodebuild test`、`swift test`、SwiftLint、Periphery、RuboCop、両プラットフォームのビルド
- **release.yml** — CI 成功後（または手動実行で）fastlane match で署名し、TestFlight / App Store Connect にアップロード
- **provision.yml** — 署名プロファイルの再発行（手動）
- **metadata.yml** — App Store の説明文などを `fastlane/metadata/` から反映（手動実行）。Pull Request では検証のみ
- **ci-actions-versions.yml** — Actions のバージョン追随チェック（Dependabot が PR を出す）

必要な Secrets: `APP_STORE_CONNECT_API_KEY_*`、`MATCH_GIT_URL`、`MATCH_PASSWORD`、`MATCH_DEPLOY_KEY`。じゃらんのキーは不要になりました（`JALAN_API_KEY` は削除して構いません）。

## 2010 年リリース版からの差分

引き継いだもの: 4タブ構成（さがす／お気に入り／履歴／設定）、地域ドリルダウン、現在地検索、フリーワード（宿名）検索、駅まわりの検索、絞り込み条件一式、ValueCommerce アフィリエイト。

**楽天トラベル**も、プロキシ経由で復活しています。当時は2サービスを切り替える形でしたが、今回は検索結果で同じ宿を名寄せして並べ、予約先は詳細画面のセグメントで選ぶ形にしています。

引き継いでいないもの:

- **路線からの駅選択・観光地検索** — 当時は駅と観光地の SQLite を同梱していました。今回は MapKit の検索で駅の座標を引く方式にして、同梱データを持たないようにしています。路線から辿る UX は失われています。
- **共有（ShareKit / Evernote）・広告（AdSense）・Google Analytics** — いずれも現在は使えないか、入れるべきでないものです。

## 現状わかっている制限

- **ローカライズは日本語のみ。** じゃらんが日本国内専用のサービスであるため、開発言語を `ja` にして日本語リテラルで書いています。英語化する場合は String Catalog の導入が必要です。なお逆ジオコーディングだけは端末の言語に追随するので、英語環境では "Chiyoda, Tokyo" と出ます。
- **App Store 上のレコードは販売停止（`CANNOT_SELL`）です。** 2020年1月に Apple の App Store Improvements（更新されていないアプリの削除）で削除されました。**この状態では TestFlight のインストールも 404 で失敗します** — ビルドの問題ではなく、ストアがアプリを配信できないためです。復帰には 3.0.0 を審査に通す必要があります。
- **アップロードのたびに `ITMS-90076` が出ますが無視して構いません。** application-identifier の prefix が `24UH5JK9Q6` から `3Y8APYUG2G` に変わりキーチェーンにアクセスできなくなる、という内容ですが、**以前から届いている誤検知**です。チームの移管も再登録も行っていませんし、このアプリはキーチェーンを一切使っていません。`keychain-access-groups` を足して直そうとしないでください。
- **スクリーンショットは手動アップロードです。** `metadata.yml` は `skip_screenshots: true` で説明文などのテキストだけを反映します。スクリーンショットの経路は iTMSTransporter を通るため失敗が多く、動く部分まで信用できなくなるので分離しています。
- **アプリアイコンは調整中。** `Resources/AppIcon.icon` は Icon Composer で開いて編集できる形式（`icon.json` ＋ `Assets/onsen.svg`）です。温泉マークを白、背景をアクセントカラーのベタ、レイヤーは Liquid Glass 有効にした状態から始めています。
