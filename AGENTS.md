# AGENTS.md - Guide for AI coding assistants

> **Note**: This file (`AGENTS.md`) is the source of truth. `CLAUDE.md` is a symlink to it — always edit `AGENTS.md`.

## Overview

**YadoSearch（宿さがし）** — an app for finding Japanese inns and hotels on iPhone, iPad and Mac, backed by the [yadosearch-api](https://github.com/ngs/yadosearch-api) proxy, which merges じゃらん and 楽天トラベル into one JSON API.

It is the successor to the app that shipped on the App Store in 2010 as 宿さがし 2.0.4 (App Store ID 347959354). The bundle identifier is that release's — `org.ngsdev.iphone.Yado` — so this ships as an update to the existing record, not as a new app. **Do not change it.** This repository's own history holds an abandoned 2014 UIKit rewrite (v3); the 2010 release, not that skeleton, is the behavioural reference.

Four search axes, carried over from that release: by inn name, near you, by area, and around a station.

### Stack

- **Language**: Swift 6 (`.swiftLanguageMode(.v6)`)
- **Frameworks**: SwiftUI, SwiftData, MapKit, Core Location
- **Deployment targets**: iOS/iPadOS 26.0, macOS 26.0 — high enough that no `@available` branching is needed for Liquid Glass
- **Architecture**: MVVM over local SPM libraries
- **Project generation**: Tuist (`Project.swift`) + SwiftPM (`Package.swift`)
- **Code quality**: SwiftLint / Periphery / RuboCop (for the Fastfile)
- **CI/CD**: GitHub Actions + fastlane
- **Localization**: English (source) and Japanese, through `Resources/Localizable.xcstrings`

### Modules

| Module | Path | Contents |
|---|---|---|
| `YadoSearchCore` | `Sources/Core/` | `Sources/Core/API/` — the proxy's contract as Codable types plus `YadoSearchAPIClient`; `SearchTarget`/`SearchScope`/`SearchFilters`/`GuestParty`/`SavedSearch`, `AreaTree`/`RakutenAreaTree`, `GeoCoordinate`. **Foundation only, no dependencies.** |
| `YadoSearchPlatform` | `Sources/Platform/` | SwiftData `StoredHotel` (favourites and visit history in one table) and `StoredSearch` (recent searches), area-tree disk cache, Core Location, MapKit station search and reverse geocoding |
| `YadoSearchUI` | `Sources/UI/` | SwiftUI views and view models |

| Tuist target | Product | Sources | Platforms |
|---|---|---|---|
| `YadoSearch` | app | `Sources/App/` | iPhone / iPad / Mac |
| `YadoSearchTests` | unitTests | `Tests/YadoSearchUITests/` | iPhone / iPad / Mac |

## The API

Everything goes through the proxy. **Neither じゃらん nor 楽天 is reached directly**, and the app holds no credentials of its own.

| Purpose | Path |
|---|---|
| Search, both providers merged | `GET /v1/hotels` |
| One inn, plus its match on the other provider | `GET /v1/hotels/{provider}/{id}` |
| Plans and vacancy for one inn | `GET /v1/hotels/{provider}/{id}/plans` |
| Jalan's area hierarchy | `GET /v1/areas/jalan` |
| Rakuten's area classification | `GET /v1/areas/rakuten` |

`openapi.json` in the proxy repository is the contract, and `Sources/Core/API/APIModels.swift` is that contract in Swift. The decoding tests read the proxy's own committed examples (`internal/httpapi/testdata/examples/`), so a change on that side shows up as a failure here.

**What the proxy takes care of, so this side does not have to:**

- **The datum.** じゃらん reports coordinates in the old Japanese datum, ~400 m from where WGS 84 puts them. The proxy converts both ways; everything the app sees is WGS 84. (Verified end to end: a search on Tokyo Station's position reports the Tokyo Station Hotel at 142 m.)
- **Affiliate links.** `detailUrl` on an offer or a plan arrives already wrapped for ValueCommerce. See "Affiliate links" below.
- **HTTPS.** じゃらん answers on port 80 only; the proxy terminates that, so the app declares no App Transport Security exception for a real host.
- **The credentials.** Both services' keys stay on the server.

**What is still worth knowing:**

- **`Provider` must be `CodingKeyRepresentable`.** `totals`, `errors` and `counterparts` are all `[Provider: …]`, and without that conformance a dictionary whose key is neither `String` nor `Int` decodes from a JSON *array* of alternating keys and values. It compiles either way and fails at runtime, so `Provider.swift` carries the reason.
- **One provider failing is not an error.** A response carries `results` and an `errors` map together — a side can rate-limit (楽天 429 is easy to hit) or refuse while the other answers. The results screen shows both.
- **Errors are the body, not the status.** A refused request is `{"error": "…"}`, often verbatim from the upstream service in Japanese, which is why `searchErrorMessage(for:)` passes service messages through.
- **`count` is per provider.** Asking for 30 can return fewer merged rows, because the same inn found on both sides is one row. Paging is decided from the per-provider totals, not from the row count.
- **Filters reach じゃらん only.** `amenities`, `hotelType`, `minRate`/`maxRate`, `order` have no 楽天 equivalent, so a filtered search returns a narrowed じゃらん half and an unnarrowed 楽天 half. The list says so.
- **Which sites answer is chosen, not assumed.** `SearchScope` (じゃらん / 楽天 / 両方) rides on `SavedSearch` and is sent as `providers`. **It only narrows** — the target still decides what is reachable at all, so `providers` alongside area codes of the other scheme searches nobody. `HotelSearchRequest` leaves the parameter off for an area target for exactly that reason: the codes already name the site, and two places to say it is two places to disagree.
- **Area search is single-provider by construction.** じゃらん's hierarchy and 楽天's classification share no codes, so an area target carries one or the other — `.area(AreaSelection)` or `.rakutenArea(RakutenAreaSelection)` — and `SearchTarget.requiredScope` is what forces the scope to match. The area picker is a different screen per site (`AreaPickerView` / `RakutenAreaPickerView`), and switching sites discards the area already picked.
- **楽天 cannot be searched above its small class.** A query stopping at the middle class is refused (`specify valid anyone set of parameters from classcodes[…]`), and a small class that has detail classes needs one (`specify valid detailClassCode`). So `RakutenAreaSelection` requires the top three levels, `RakutenAreaTree.SmallClass.isSearchable` is what the picker branches on, and **there is no 楽天 equivalent of "東京都全体"**. Only 5 of its 312 small classes have detail classes.
- **楽天 has no undated mode.** `checkIn` is required for its plans; じゃらん without one quotes guide prices. Selecting 楽天 with no date prompts for one instead of reporting a failure.
- **楽天 reports "nothing matched" as a failure.** A plan search it cannot fill answers `{"error":"Data Not Found"}` behind a 502, where じゃらん answers 200 and `"total": 0`. Shown verbatim it reads as a broken app, so `APIError.meansNoResults` turns it back into an empty result — which is why picking a date on 楽天 and getting nothing now says "該当するプランが見つかりませんでした" rather than "Data Not Found". `meansRateLimited` does the same for `rakuten:  (status 429)`, which is transient: the plan search retries once after ~1.2 s, and only says so — with a retry button — if the second attempt fails too. **Its limit is shared and easy to trip**: reading two inns in quick succession is enough, and sampling six inns in a row on the live proxy returned three 429s.
- **A check-in date starts at tomorrow.** 楽天 answers a same-day plan search with "Data Not Found" at most inns, so a toggle that defaulted to today made the vacancy search look broken whichever inn it was opened on. `StayConditions.nextAvailableCheckIn()` is that default; the picker still allows today.
- Name search still refuses above 200 matches, with じゃらん's own wording.
- **Radius is metres now.** `SearchRadius` still carries じゃらん's old opaque codes as raw values (so stored searches keep decoding), but what is sent is `approximateMetres`. **楽天 caps its own search at 3 km.**
- **`/v1/areas/rakuten` is 楽天's own response, passed through.** The proxy declares no schema for it — the only thing it can promise is what 楽天 said — so `RakutenAreaTreeResponse` decodes 楽天's shape: every level is an object behind a single-key wrapper (`{"largeClass": {…}}`), not the array-of-single-key-objects the rest of `formatVersion=1` uses. `Fixtures/api/areas_rakuten_full.json` is captured live, and it is what pins that.

## Affiliate links

Every outbound jalan.net and rakuten link is affiliate-wrapped **by the proxy**, and arrives ready to open: `Offer.detailURL`, `HotelProfile.detailURL`, `StayPlan.detailURL`. The app builds none of it — `JalanAffiliate` and its ValueCommerce URL construction are gone, and `docs/affiliate.md` in the proxy repository is where that logic now lives and is documented.

Two things still matter on this side:

- **Open these in a browser, never fetch them.** The redirect answers with a JavaScript tracking page.
- **Use `SafariLink`, not `Link`.** jalan.net publishes a universal link, so handing the redirect to the system opens the じゃらん app and the referral never completes — the click earns nothing. `SFSafariViewController` ignores universal links, so the redirect stays in the browser. `SafariLink` falls back to `Link` on macOS, where neither the app nor `SFSafariViewController` exists. Non-affiliate links (Maps, the App Store) stay plain `Link`s.

## The API host

There is no application key any more. What the app needs to know is *where the proxy is*, and it resolves that from two places, in order:

1. **A launch argument**, `-APIHost host:port`. Xcode puts `-key value` pairs into `UserDefaults`, so `APIHost.baseURL(bundle:defaults:)` needs no parsing of its own.
2. **`APIHost` in `Info.plist`**, written by Tuist from the `API_HOST` build setting in `Project.swift`.

The host is bare, without a scheme: `http` is chosen for `localhost`, `127.0.0.1` and `*.local`, `https` for everything else. `NSAllowsLocalNetworking` covers exactly the first case, and no other ATS exception exists.

**A build that cannot resolve a host traps at launch** (`YadoSearchEnvironment.init(bundle:)`). Every screen needs the API, so an unconfigured build is broken rather than degraded. Do not add a "not configured" state back.

The `YadoSearch (Local)` scheme passes `-APIHost localhost:8080`. **On a device that argument is the knob to turn** — `localhost` there means the phone, so testing against a proxy on the Mac means naming the Mac.

## Commands

```bash
tuist generate                      # generate and open
tuist generate --no-open            # what CI runs
swift test                          # SPM tests
xcodebuild test -workspace YadoSearch.xcworkspace -scheme YadoSearch \
  -destination "id=$(Scripts/latest-ios-simulator.sh)"
Scripts/lint.sh strict              # SwiftLint (CI runs --strict)
periphery scan --strict             # unused code
bundle exec rubocop                 # Ruby
open Resources/AppIcon.icon         # edit the app icon in Icon Composer
```

`Scripts/latest-ios-simulator.sh` exists because runner images keep iOS 18 runtimes around, and picking the first iPhone in the list yields a destination `xcodebuild` rejects against an iOS 26 deployment target.

## Testing

- `Tests/YadoSearchCoreTests/` — decoding against `Fixtures/api/*.json`, which are the proxy's own committed examples; request building and filter mapping
- `Tests/YadoSearchUITests/` — view-model paging and failure handling through `StubProxyServer` (a `URLProtocol` serving canned JSON keyed by `page`), favourites and history against an in-memory SwiftData container, and presentation formatting

`Fixtures/api/areas_jalan_full.json` is captured live rather than copied: the contract's own area example is trimmed to one region, which cannot answer whether all 47 prefectures are there.

Both run under `swift test`; `YadoSearchTests` (the Tuist target) runs `Tests/YadoSearchUITests/` under `xcodebuild test`.

Suites that assert on the last request a stub received are `.serialized` — Swift Testing runs tests in parallel by default and the stubs hold one script at a time.

## iCloud sync

Favourites, visit history and recent searches mirror through the CloudKit private database `iCloud.org.ngsdev.iphone.Yado`.

- **Mirroring constraints**: every persisted property must be optional or defaulted, and `@Attribute(.unique)` is forbidden. Both compile fine and then crash at container creation, so `CloudKitSchemaTests` pins them. Deduplication is done by an explicit fetch in `StoredHotelStore` / `SearchHistoryStore`, not by a constraint.
- `YadoSearchModelContainer.make(inMemory:)` walks a ladder: CloudKit → local → in-memory. A build without the entitlement (CI, and any simulator not signed into iCloud) simply lands on a lower rung, so nothing here may assume sync is on.
- `aps-environment` comes from `$(APS_ENVIRONMENT)`, set per configuration in `Project.swift` (Debug `development`, Release `production`). A Release build claiming `development` registers against the APNs sandbox, where CloudKit's pushes never arrive — the app would then only sync when opened.
- The portal side is already set up: `org.ngsdev.iphone.Yado` has the iCloud (CloudKit) and Push Notifications capabilities, with `iCloud.org.ngsdev.iphone.Yado` assigned. The identifier is pinned in `CloudKitSchemaTests`; if it ever moves, the entitlements file has to move with it or signing fails.
- The match profiles already carry the capabilities, so `provision.yml` does not need re-running. A profile is a snapshot of the entitlements at issue time, which is why this was once outstanding; the Release builds now on App Store Connect were signed with `MATCH_READONLY=true` and accepted as `VALID` with the iCloud and APNs entitlements, which they could not have been against a stale profile.
- Push is only ever the silent kind. The app has no notification code at all — `NSPersistentCloudKitContainer` uses the pushes to learn that another device changed something. Without them sync still works, but only when the app is opened.

## Search state

`SavedSearch` (Core) is the whole search — target, scope, filters, party, and the title. It is what the results screen is pushed with, what the recents list stores as JSON, and what re-running a recent search replays.

- The title is carried, not derived: "東京都千代田区から約2.5km" needs the reverse-geocoded name that existed at the time, and an area name cannot be recovered from its code.
- `SavedSearch.id` is a fingerprint of the *conditions* with the title excluded, so re-running a search moves one row rather than adding a twin. It is built from a flattened struct with the amenities sorted — encoding `SearchFilters` directly would fingerprint two equal filter sets differently, because a `Set` serialises in iteration order.
- The scope is part of that fingerprint, so the same name searched on じゃらん and on 楽天 are two rows. Everything recorded before there was a choice has no `scope` in its stored JSON; `SavedSearch.init(from:)` reads that as `.both` rather than letting the row fail to decode and vanish.
- Reverse geocoding uses `MKReverseGeocodingRequest` (`CLGeocoder` is deprecated as of iOS 26) and prefers `MKAddressRepresentations.cityWithContext(.short)`. It runs *after* the fix and never blocks it: the coordinate is what the search needs, the name is only read.

## Conventions

- SwiftLint's `attributes` rule is configured so SwiftUI property wrappers (`@Environment`, `@Query`, `@State`, `@Attribute`) stay on the same line as their property, and `@ViewBuilder` goes above the member.
- The SwiftLint build phase runs `--fix` before compiling, so number separators and similar get rewritten on build. Do not fight it.
- `swiftlint --strict` and `periphery scan --strict` both pass with zero findings; keep it that way. Periphery in particular means no speculative public API.

## Known gaps

Against the 2010 release specifically:

Rakuten Travel is back, by way of the proxy — the 2010 release switched between the two services, and the merged search restores that. The switch is back too, as `SearchScope`: the difference is that "両方" is now a third option rather than the only behaviour.

- **No line-by-line station picker, no sightseeing-spot search.** The 2010 app bundled `eki.sqlite` (stations, lines) and a spot database. Station search here resolves a coordinate through MapKit instead, which carries no data to maintain but loses the 路線→駅 drill-down.
- Sharing (ShareKit/Evernote), AdSense and Google Analytics are deliberately not carried over.

In general:

- **English is the source language, and the English string is the key.** `Text("Favourites")` is what the code says; `Resources/Localizable.xcstrings` maps that key to itself in `en` and to "お気に入り" in `ja`. It was the other way round until the base language was switched, and the switch was made by inverting the catalogue rather than by re-translating: every Japanese key became its own English translation, and the Japanese it used to be became the `ja` value.
  - **The catalogue lives in the app target, not in the UI package.** SwiftUI resolves a `LocalizedStringKey` against `Bundle.main` unless told otherwise, so a catalogue in the app bundle serves every module without `bundle: .module` at hundreds of call sites. The cost is that previews and `swift test` see no catalogue and fall back to the key — which is now the English text, and is what the tests assert.
  - **Anything typed `String` needs `String(localized:)`.** `Text` and friends take a `LocalizedStringKey` and look themselves up; a plain `String` does not. That is why `Amenity.title`, `Provider.title`, `SearchRadius.label`, the `SavedSearch` titles, `searchErrorMessage(for:)` and even the `" · "` that joins a summary all wrap their literals. Core can do this because `String(localized:)` is Foundation, and it reads `Bundle.main` too.
  - **Interpolation changes the key.** `Text("\(count) inns")` looks up `%lld inns`, not `\(count) inns`; a `String` interpolation is `%@`. When a translation reorders two arguments it has to use positional specifiers (`%1$@`).
  - **One key, one meaning.** Japanese drew distinctions English collapses: 検索条件 and こだわり were both "Conditions", さがす and 宿をさがす both "Search", エリア and 地域 both "Area". A shared key would have given each pair one Japanese translation, so they are "Conditions"/"Amenities", "Search"/"Find inns" and "Region"/"Area".
  - `Resources/InfoPlist.xcstrings` carries the display name and the location prompt. **`CFBundleDisplayName` is "YadoSearch" in the plist and 宿さがし in `ja`** — the Japanese name is the one the App Store record has carried since 2010, and it comes from the catalogue rather than from `Project.swift`.
  - Reverse-geocoded place names follow the device language on their own. **What the proxy returns — inn names, area names, service error messages — is Japanese whatever the device is set to**, because that is all the upstream services have.
- **The app icon is still being tuned.** `Resources/AppIcon.icon` is an Icon Composer package (`icon.json` plus `Assets/onsen.svg`) — edit it there, not by hand. There is no `AppIcon.appiconset` any more; the `.icon` supersedes it, and `actool` still emits the legacy PNGs from it.
  - The layer's `fill` in `icon.json` is what colours the glyph. `actool` treats the SVG as a monochrome vector and ignores fills inside it, so changing the SVG's own `fill` does nothing.
  - Rendering it without a full build: `xcrun actool Resources/AppIcon.icon --compile <dir> --platform iphoneos --minimum-deployment-target 26.0 --app-icon AppIcon --include-all-app-icons --output-partial-info-plist <dir>/partial.plist`. A plain `xcodebuild build` caches the compiled catalogue and will not pick up an icon change.
- **The screenshots upload themselves; nothing captures them yet.** `fastlane ios deliver_screenshots` (and `mac`) sends `fastlane/screenshots/<platform>/<locale>/` with `overwrite_screenshots: true`, and the Metadata workflow runs it as a **separate job** — a push to master that changed a PNG, or a dispatch that asked — because iTMSTransporter is slow and fails often enough that it must not be able to take the copy down with it. That is also why `deliver_metadata_for` keeps `skip_screenshots: true`. **The directory is empty: 3.0.0's set has not been shot.** What was there were the 2010 app's twenty PNGs at 640×960 and iPad 9.7 — sizes App Store Connect no longer accepts, of a UI that no longer exists — and they are in the history rather than the tree. `ngs/tides-swift`'s `Scripts/screenshots.sh` is the model if capture is ever automated here.
- **A merge to master applies the listing.** A push touching `fastlane/metadata/**` (or the Fastfile, the validator or the workflow) uploads both listings; a pull request runs the same validation and uploads nothing. A dispatch can still pick one platform, or validate only.
- **A pull request checks the metadata with `Scripts/validate-metadata.rb`, not with `deliver`.** `deliver`'s `verify_only` sounds like a metadata check and is not one — it verifies a *binary* package, and a metadata-only lane passes no ipa or pkg, so it dies in `IpaUploadPackageBuilder` with `no implicit conversion of nil into String` before reading a single field. The script reads the files offline instead (character limits, required and unrecognised fields, https URLs, category keys, locales that do not match each other), so it needs no App Store Connect credentials, and the Metadata workflow gates every upload on it.
- **`fastlane/metadata/review_information/` is filled in, and half-filling it breaks the upload.** deliver sends the review detail whenever that directory holds files at all, so the seven blank placeholders `deliver init` writes make App Store Connect refuse the whole request with "You must provide a value for the attribute 'contactFirstName'". The contact is the same one `ngs/tides-swift` ships. `demo_user`, `demo_password` and `notes` stay empty — the app needs no account to review. The validator's rule is all four contact fields or none.
- **`ITMS-90076` on every upload, and it is safe to ignore.** Apple's mail claims the application-identifier prefix moved from `24UH5JK9Q6` to `3Y8APYUG2G` and that keychain access will be lost. **It is a false positive of long standing** — the same mail arrived for uploads years before this rewrite, no team transfer or re-enrolment ever happened, and the app uses the keychain for nothing at all. Do not try to "fix" it by adding a `keychain-access-groups` entitlement.
- **The App Store record is `CANNOT_SELL`.** Apple removed 宿さがし in January 2020 under the App Store Improvements programme (outdated app). **TestFlight installs fail with a 404 while that holds** — the build is fine; the store simply cannot vend the app. Reinstating it means shipping 3.0.0 through review.
