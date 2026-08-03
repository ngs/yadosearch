import ProjectDescription

/// The last release on the App Store was 2.0.4, in 2010. The 2014 rewrite that
/// never shipped called itself 3.0 in its Info.plist; this one takes that
/// version number for real.
let version = "3.0.0"
let copyright = "© 2010-2026 LittleApps Inc. All rights reserved."

let buildNumber = Environment.buildNumber.getString(default: "0")

/// The Jalan Web Service application key. Never committed: direnv exports it
/// from `.env` via `.envrc`, and CI supplies it from a repository secret.
/// Generating without one produces a perfectly good build that tells the user
/// the key is missing instead of issuing requests that would all be rejected.
let jalanAPIKey = Environment.jalanApiKey.getString(default: "")

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
            "JALAN_API_KEY": .string(jalanAPIKey),
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
                "CFBundleDisplayName": .string("宿さがし"),
                "CFBundleVersion": .string("$(CURRENT_PROJECT_VERSION)"),
                "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
                "NSHumanReadableCopyright": .string(copyright),
                "LSApplicationCategoryType": .string("public.app-category.travel"),
                "UILaunchScreen": [
                    "UIColorName": "AccentColor",
                    "UIImageRespectsSafeAreaInsets": true
                ],
                "JalanAPIKey": .string("$(JALAN_API_KEY)"),
                "NSLocationWhenInUseUsageDescription": .string(
                    "現在地のまわりの宿を探すために位置情報を使います。"),
                // SwiftData + CloudKit receives changes pushed from the user's
                // other devices as silent remote notifications.
                "UIBackgroundModes": .array([.string("remote-notification")]),
                // jws.jalan.net answers on port 80 only — 443 is closed, so
                // there is no HTTPS endpoint to switch to. The exception is
                // scoped to that one host; every other connection the app makes
                // (photos on www.jalan.net, the booking site) stays on TLS.
                "NSAppTransportSecurity": .dictionary([
                    "NSExceptionDomains": .dictionary([
                        "jws.jalan.net": .dictionary([
                            "NSExceptionAllowsInsecureHTTPLoads": .boolean(true),
                            "NSIncludesSubdomains": .boolean(false)
                        ])
                    ])
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
