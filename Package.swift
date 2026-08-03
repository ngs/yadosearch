// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YadoSearch",
    defaultLocalization: "ja",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        // Exposed as libraries so the Tuist-managed app target can depend on them.
        // Static so Xcode never embeds them as (separately signed) dynamic
        // frameworks in the app bundle.
        .library(name: "YadoSearchCore", type: .static, targets: ["YadoSearchCore"]),
        .library(name: "YadoSearchPlatform", type: .static, targets: ["YadoSearchPlatform"]),
        .library(name: "YadoSearchUI", type: .static, targets: ["YadoSearchUI"])
    ],
    targets: [
        // Jalan Web Service client and its models (Foundation only).
        .target(
            name: "YadoSearchCore",
            path: "Sources/Core",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // SwiftData persistence, Core Location, and MapKit-backed station search.
        .target(
            name: "YadoSearchPlatform",
            dependencies: ["YadoSearchCore"],
            path: "Sources/Platform",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // SwiftUI views and view models.
        .target(
            name: "YadoSearchUI",
            dependencies: ["YadoSearchCore", "YadoSearchPlatform"],
            path: "Sources/UI",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Parser and request-building tests, driven by captured API responses.
        .testTarget(
            name: "YadoSearchCoreTests",
            dependencies: ["YadoSearchCore"],
            path: "Tests/YadoSearchCoreTests",
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "YadoSearchUITests",
            dependencies: ["YadoSearchUI", "YadoSearchPlatform", "YadoSearchCore"],
            path: "Tests/YadoSearchUITests"
        )
    ]
)
