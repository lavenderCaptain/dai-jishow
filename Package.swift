// swift-tools-version: 5.9
// Swift Package Manager manifest for Dai-Jishow (alongside DaiJishow.xcodeproj).
// Compiles the C++20 `core/` engine directly and links it into the native
// macOS SwiftUI glass-material application (`DaiJishowMac`).

import PackageDescription

let package = Package(
    name: "DaiJishow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DaiJishowMac", targets: ["DaiJishowMac"])
    ],
    targets: [
        // 1. Platform-agnostic C++20 core library exposed via C11 ABI (`dj_capi.h`)
        .target(
            name: "DaiJishowCore",
            path: "core",
            sources: [
                "dj_capi.cpp",
                "dj_storage/storage.cpp",
                "dj_nlp/romaji.cpp",
                "dj_graph/fisheye.cpp",
                "dj_state/session_state.cpp"
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .unsafeFlags(["-std=c++20", "-O3"])
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),

        // 2. Pure Swift morphology core (conjugation + POS + pitch), extracted from
        //    the executable so it can be unit-tested. SwiftPM cannot `@testable`
        //    import an executable target, so this logic lives in its own library.
        //    Dependency-free: no engine, no DB, no UI, no MainActor.
        .target(
            name: "DaiJishowMorph",
            path: "Sources/DaiJishowMorph"
        ),

        // 3. Native macOS SwiftUI + Canvas glass-material shell (shared + macOS layers)
        .executableTarget(
            name: "DaiJishowMac",
            dependencies: ["DaiJishowCore", "DaiJishowMorph"],
            path: "platform-apple",
            exclude: [
                "iOS",
                "watchOS",
                "macOS/DaiJishow.entitlements",
                "macOS/PrivacyInfo.xcprivacy"
            ],
            sources: [
                "Shared",
                "macOS"
            ]
        ),

        // 4. Regression tests for the morphology core (Swift Testing). Locked in by
        //    `swift test` in tools/build_app_bundle.sh so a broken conjugation/POS
        //    change cannot ship a DMG.
        .testTarget(
            name: "DaiJishowMorphTests",
            dependencies: ["DaiJishowMorph"]
        )
    ]
)
