import ProjectDescription

/// The last release on the App Store was 2.0.4, in 2010. The 2014 rewrite that
/// never shipped called itself 3.0 in its Info.plist; this one takes that
/// version number for real.
let version = "3.0.0"
let copyright = "© 2010-2026 LittleApps Inc. All rights reserved."

let buildNumber = Environment.buildNumber.getString(default: "0")

/// Where the app looks for the yadosearch-api proxy. A bare host: the app
/// chooses `https`, or `http` for a local address.
///
/// The `YadoSearch (Local)` scheme overrides this with a launch argument, which
/// is also how a build on a real device is pointed at a Mac on the same
/// network — `localhost` there means the device itself.
let apiHost = "yadosearch-api-679155343431.asia-northeast1.run.app"

let project = Project(
    name: "YadoSearch",
    organizationName: "LittleApps Inc.",
    options: .options(
        defaultKnownRegions: ["ja", "en"],
        developmentRegion: "ja"
    ),
    packages: [
        .package(path: ".")
    ],
    settings: .settings(
        base: [
            "CURRENT_PROJECT_VERSION": .string(buildNumber),
            "MARKETING_VERSION": .string(version),
            "API_HOST": .string(apiHost),
            "DEVELOPMENT_TEAM": .string("3Y8APYUG2G"),
            // Development builds provision themselves; the release lanes switch
            // the Release configuration to the match profiles.
            "CODE_SIGN_STYLE": .string("Automatic"),
            "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO"
        ],
        // The APNs environment is baked into the entitlements, and shipping a
        // Release build that says "development" registers it against the APNs
        // sandbox — where CloudKit's push notifications never arrive, so
        // SwiftData would only sync when the app is opened.
        configurations: [
            .debug(name: .debug, settings: ["APS_ENVIRONMENT": "development"]),
            .release(name: .release, settings: ["APS_ENVIRONMENT": "production"])
        ]
    ),
    targets: [
        .target(
            name: "YadoSearch",
            destinations: [.iPhone, .iPad, .mac],
            product: .app,
            bundleId: "org.ngsdev.iphone.Yado",
            deploymentTargets: .multiplatform(
                iOS: "26.0",
                macOS: "26.0"
            ),
            infoPlist: .extendingDefault(with: [
                "ITSAppUsesNonExemptEncryption": .boolean(false),
                "CFBundleName": .string("YadoSearch"),
                // Localised in Resources/InfoPlist.xcstrings, along with the
                // location permission prompt.
                "CFBundleDisplayName": .string("宿さがし"),
                "CFBundleVersion": .string("$(CURRENT_PROJECT_VERSION)"),
                "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
                "NSHumanReadableCopyright": .string(copyright),
                "LSApplicationCategoryType": .string("public.app-category.travel"),
                "UILaunchScreen": [
                    "UIColorName": "AccentColor",
                    "UIImageRespectsSafeAreaInsets": true
                ],
                "APIHost": .string("$(API_HOST)"),
                "NSLocationWhenInUseUsageDescription": .string(
                    "現在地のまわりの宿を探すために位置情報を使います。"),
                // SwiftData + CloudKit receives changes pushed from the user's
                // other devices as silent remote notifications.
                "UIBackgroundModes": .array([.string("remote-notification")]),
                // The proxy is reached over TLS. This exception exists so a
                // development build can talk to one running on the same
                // machine or network over plain HTTP, and it covers nothing
                // beyond local addresses.
                "NSAppTransportSecurity": .dictionary([
                    "NSAllowsLocalNetworking": .boolean(true)
                ])
            ]),
            sources: ["Sources/App/**"],
            // Entitlements files are code-signing inputs, never bundle resources.
            resources: [
                .glob(pattern: "Resources/**", excluding: ["Resources/YadoSearch.entitlements"])
            ],
            entitlements: .file(path: "Resources/YadoSearch.entitlements"),
            scripts: [
                .pre(
                    script: "${SRCROOT}/Scripts/swiftlint-fix-build-phase.sh",
                    name: "SwiftLint Auto-Fix",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .package(product: "YadoSearchCore"),
                .package(product: "YadoSearchPlatform"),
                .package(product: "YadoSearchUI")
            ]
        ),
        .target(
            name: "YadoSearchTests",
            destinations: [.iPhone, .iPad, .mac],
            product: .unitTests,
            bundleId: "org.ngsdev.iphone.YadoTests",
            deploymentTargets: .multiplatform(
                iOS: "26.0",
                macOS: "26.0"
            ),
            sources: ["Tests/YadoSearchUITests/**"],
            dependencies: [
                .package(product: "YadoSearchCore"),
                .package(product: "YadoSearchPlatform"),
                .package(product: "YadoSearchUI")
            ]
        )
    ],
    schemes: [
        // Points the app at a proxy running on this machine. `localhost` is the
        // device itself, so testing on a phone means changing this argument to
        // the Mac's name or address — that is what it is here for.
        .scheme(
            name: "YadoSearch (Local)",
            buildAction: .buildAction(targets: ["YadoSearch"]),
            testAction: .targets(
                ["YadoSearchTests"],
                configuration: .debug,
                options: .options(coverage: true)
            ),
            runAction: .runAction(
                configuration: .debug,
                arguments: .arguments(launchArguments: [
                    .launchArgument(name: "-APIHost localhost:8080", isEnabled: true)
                ])
            )
        ),
        .scheme(
            name: "YadoSearch",
            buildAction: .buildAction(targets: ["YadoSearch"]),
            testAction: .targets(
                ["YadoSearchTests"],
                configuration: .debug,
                options: .options(coverage: true)
            ),
            runAction: .runAction(configuration: .debug)
        )
    ]
)
