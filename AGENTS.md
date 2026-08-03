# AGENTS.md - Guide for AI coding assistants

> **Note**: This file (`AGENTS.md`) is the source of truth. `CLAUDE.md` is a symlink to it — always edit `AGENTS.md`.

## Overview

**YadoSearch（宿さがし）** — an app for finding Japanese inns and hotels on iPhone, iPad and Mac, backed by the Jalan Web Service.

It is the successor to the app that shipped on the App Store in 2010 as 宿さがし 2.0.4 ([ngs-archives/littleapps-yadosearch], App Store ID 347959354). The bundle identifier is that release's — `org.ngsdev.iphone.Yado` — so this ships as an update to the existing record, not as a new app. **Do not change it.** This repository's own history holds an abandoned 2014 UIKit rewrite (v3); the 2010 release, not that skeleton, is the behavioural reference.

Four search axes, carried over from that release: by inn name, near you, by area, and around a station.

[ngs-archives/littleapps-yadosearch]: https://github.com/ngs-archives/littleapps-yadosearch

### Stack

- **Language**: Swift 6 (`.swiftLanguageMode(.v6)`)
- **Frameworks**: SwiftUI, SwiftData, MapKit, Core Location
- **Deployment targets**: iOS/iPadOS 26.0, macOS 26.0 — high enough that no `@available` branching is needed for Liquid Glass
- **Architecture**: MVVM over local SPM libraries
- **Project generation**: Tuist (`Project.swift`) + SwiftPM (`Package.swift`)
- **Code quality**: SwiftLint / Periphery / RuboCop (for the Fastfile)
- **CI/CD**: GitHub Actions + fastlane
- **Localization**: Japanese only, written as literals (see "Known gaps")

### Modules

| Module | Path | Contents |
|---|---|---|
| `YadoSearchCore` | `Sources/Core/` | Jalan API client, XML tree, `Hotel`/`Plan`/`AreaTree`, `SearchFilters`/`GuestParty`, `JalanAffiliate`, datum conversion. **Foundation only.** |
| `YadoSearchPlatform` | `Sources/Platform/` | SwiftData `StoredHotel` (favourites and visit history in one table) and `StoredSearch` (recent searches), area-tree disk cache, Core Location, MapKit station search and reverse geocoding |
| `YadoSearchUI` | `Sources/UI/` | SwiftUI views and view models |

| Tuist target | Product | Sources | Platforms |
|---|---|---|---|
| `YadoSearch` | app | `Sources/App/` | iPhone / iPad / Mac |
| `YadoSearchTests` | unitTests | `Tests/YadoSearchUITests/` | iPhone / iPad / Mac |

## The API, and what is not obvious about it

Only three Jalan endpoints still answer, and those are the three in use:
`APIAdvance/HotelSearch/V1/`, `APIAdvance/StockSearch/V1/`, `APICommon/AreaSearch/V1/`.
Anything else under `/APIAdvance/` (`AreaCode`, `OnsenCode`, `HotelDetail`, …) returns Jalan's "page not found" HTML.

**Coordinates are in the Tokyo datum.** `<X>`/`<Y>` are thousandths of an arcsecond in the *old Japanese datum*, and nothing in the response says so. The Imperial Hotel Tokyo comes back at 35.669046 N, 139.761581 E; it stands at 35.67225 N, 139.75892 E on a WGS 84 map. `TokyoDatum` converts both ways, and `SearchTarget.queryItems` converts the search centre on the way out. Skipping this misplaces every pin by ~400 m — verified end to end: a proximity search on Tokyo Station's WGS 84 position returns the Tokyo Station Hotel at 142 m.

The `datum` request parameter makes no observable difference to either the request or the response. Sending Tokyo-datum coordinates is correct whether or not the server honours it.

**`range` is an opaque code, not a distance.** Codes 1–8, undocumented. The radii in `SearchRadius` were measured by fetching every result of a Tokyo Station search at each code and recording the farthest inn: 1.1 / 2.5 / 3.7 / 5.1 / 6.3 / 7.3 / 8.7 / 10.0 km. The enum exposes five of them, and the UI says "約" because they are approximations.

**HTTP only.** `jws.jalan.net` listens on port 80; 443 is closed. `Project.swift` declares an ATS exception scoped to that host. This is an App Store review exposure — see the README.

**Other behaviours worth knowing:**

- Name search (`h_name`) refuses outright above 200 matches. The error body is Japanese prose written for the caller, so `searchErrorMessage(for:)` passes service messages through verbatim rather than replacing them.
- Errors arrive as HTTP 400 with `<Error><Message>…</Message></Error>`. The client reads the body, not the status code.
- There is no station parameter. Station search resolves a coordinate with MapKit, then runs a proximity search.
- **`order`'s codes are undocumented but known.** The 2010 release shipped the mapping in `FilterConditions_jalan.plist` (0 指定なし / 1 50音順 / 2 参考料金の安い順 / 3 参考料金の高い順 / 4 じゃらんnet人気順) and all five still work — `HotelSortOrder` is that table. `.unspecified` sends no `order` at all, which is what leaves a proximity search sorted nearest-first.
- **The whole filter vocabulary still works too**: `h_type`, `min_rate`/`max_rate`, `sc_num`/`lc_num_*`, and ~60 flag parameters, all verified live against the list in the 2010 release's `Misc/docs/jws.txt`. `SearchFilters` and `GuestParty` carry them.
- `stay_date` is rejected on name, region and prefecture searches ("宿名検索、広域、都道府県検索時は宿泊開始日を指定することはできません"), so dates are only sent to `StockSearch`.
- 温泉地 search (`o_area_id`/`o_id`) is not implemented: the endpoint that listed 温泉地 codes is gone, and the parameter rejects anything else.
- `HotelSearch` and `StockSearch` return different subsets of the `<Hotel>` fields (access directions and check-in times vs rating and kana). Everything either one omits is optional on `Hotel`, and one decoder serves both.

## Affiliate links

Every outbound jalan.net link goes through ValueCommerce (`JalanAffiliate`, `sid=2462325` / `pid=892671706`). The 2010 release did the same — `kVCURLFormat` in its `AppConfig.h` — under an older program ID.

- `vc_url` is the destination percent-encoded **whole**, `:` and `/` included; only the unreserved set survives. It is built by string concatenation, not `URLComponents.queryItems`, which would re-encode the percent signs.
- The inn link is built from `HotelID` as `https://www.jalan.net/yad{HotelID}/`, not from the API's `HotelDetailURL` — that one goes through `JwsRedirect.do` and carries the API key in its query. For plans, `PlanCommonDetailURL` (a plain jalan.net address) is wrapped and `PlanDetailURL` is the unwrapped fallback.
- Non-jalan.net URLs are returned unchanged; the programme pays for one merchant.
- The redirect answers with a JavaScript tracking page, so these URLs must be opened in a browser (`Link`), never fetched with `URLSession`.

## The application key

Never in the repository. `.env` (gitignored) → `Scripts/generate.sh` → `TUIST_JALAN_API_KEY` → `Info.plist`'s `JalanAPIKey`, read by `JalanAPIClient.Configuration.fromBundle(_:)`.

A build without a key is a supported state, not a failure: `YadoSearchEnvironment.isConfigured` is false and the UI shows `NotConfiguredView`. Every CI build runs this way on pull requests from forks. Do not add code that assumes a key exists.

The committed test fixtures were captured live and had the key scrubbed to `TEST_KEY` — it appears inside every `HotelDetailURL` the service returns, so re-capturing fixtures means scrubbing again.

## Commands

```bash
Scripts/generate.sh                 # generate and open (reads .env)
Scripts/generate.sh --no-open       # what CI runs
swift test                          # SPM tests
xcodebuild test -workspace YadoSearch.xcworkspace -scheme YadoSearch \
  -destination "id=$(Scripts/latest-ios-simulator.sh)"
Scripts/lint.sh strict              # SwiftLint (CI runs --strict)
periphery scan --strict             # unused code
bundle exec rubocop                 # Ruby
swift Scripts/generate-icons.swift  # redraw the app icon
```

`Scripts/latest-ios-simulator.sh` exists because runner images keep iOS 18 runtimes around, and picking the first iPhone in the list yields a destination `xcodebuild` rejects against an iOS 26 deployment target.

## Testing

- `Tests/YadoSearchCoreTests/` — parsing against `Fixtures/*.xml`, real captured responses; request building, filter and affiliate URL construction, and error mapping through a `URLProtocol` stub
- `Tests/YadoSearchUITests/` — view-model paging and failure handling through `StubJalanServer`, favourites and history against an in-memory SwiftData container, and presentation formatting

Both run under `swift test`; `YadoSearchTests` (the Tuist target) runs `Tests/YadoSearchUITests/` under `xcodebuild test`.

Suites that assert on the last request a stub received are `.serialized` — Swift Testing runs tests in parallel by default and the stubs hold one script at a time.

## iCloud sync

Favourites, visit history and recent searches mirror through the CloudKit private database `iCloud.org.ngsdev.iphone.Yado`.

- **Mirroring constraints**: every persisted property must be optional or defaulted, and `@Attribute(.unique)` is forbidden. Both compile fine and then crash at container creation, so `CloudKitSchemaTests` pins them. Deduplication is done by an explicit fetch in `StoredHotelStore` / `SearchHistoryStore`, not by a constraint.
- `YadoSearchModelContainer.make(inMemory:)` walks a ladder: CloudKit → local → in-memory. A build without the entitlement (CI, and any simulator not signed into iCloud) simply lands on a lower rung, so nothing here may assume sync is on.
- `aps-environment` comes from `$(APS_ENVIRONMENT)`, set per configuration in `Project.swift` (Debug `development`, Release `production`). A Release build claiming `development` registers against the APNs sandbox, where CloudKit's pushes never arrive — the app would then only sync when opened.
- **First-time setup is manual**: the App ID needs the iCloud and Push Notifications capabilities and the container has to exist in the portal, then `provision.yml` must be run once with `MATCH_READONLY=false` to reissue the profiles.

## Search state

`SavedSearch` (Core) is the whole search — target, filters, party, and the title. It is what the results screen is pushed with, what the recents list stores as JSON, and what re-running a recent search replays.

- The title is carried, not derived: "東京都千代田区から約2.5km" needs the reverse-geocoded name that existed at the time, and an area name cannot be recovered from its code.
- `SavedSearch.id` is a fingerprint of the *conditions* with the title excluded, so re-running a search moves one row rather than adding a twin. It is built from a flattened struct with the amenities sorted — encoding `SearchFilters` directly would fingerprint two equal filter sets differently, because a `Set` serialises in iteration order.
- Reverse geocoding uses `MKReverseGeocodingRequest` (`CLGeocoder` is deprecated as of iOS 26) and prefers `MKAddressRepresentations.cityWithContext(.short)`. It runs *after* the fix and never blocks it: the coordinate is what the search needs, the name is only read.

## Conventions

- SwiftLint's `attributes` rule is configured so SwiftUI property wrappers (`@Environment`, `@Query`, `@State`, `@Attribute`) stay on the same line as their property, and `@ViewBuilder` goes above the member.
- The SwiftLint build phase runs `--fix` before compiling, so number separators and similar get rewritten on build. Do not fight it.
- `swiftlint --strict` and `periphery scan --strict` both pass with zero findings; keep it that way. Periphery in particular means no speculative public API.

## Known gaps

Against the 2010 release specifically:

- **Rakuten Travel is gone.** That version could switch between Jalan and 楽天トラベル (`RWSHotelRequestModel`). Adding it back needs a Rakuten Web Service application ID and a second client behind a provider abstraction.
- **No line-by-line station picker, no sightseeing-spot search.** The 2010 app bundled `eki.sqlite` (stations, lines) and a spot database. Station search here resolves a coordinate through MapKit instead, which carries no data to maintain but loses the 路線→駅 drill-down.
- Sharing (ShareKit/Evernote), AdSense and Google Analytics are deliberately not carried over.

In general:

- **Japanese only.** Development region is `ja` and UI strings are literals. Adding English means a String Catalog in the UI package plus `bundle: .module` at every call site. Reverse-geocoded place names are the exception — they follow the device language.
- **The app icon is provisional** — a CoreGraphics render in `Scripts/generate-icons.swift`.
- No App Store metadata (`fastlane/metadata/`) or screenshot automation yet.
