// swift-tools-version: 5.9
// Zero-Xcode-project Swift Package Manager manifest for Dai-Jishow.
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

        // 2. Native macOS SwiftUI + Canvas glass-material shell
        .executableTarget(
            name: "DaiJishowMac",
            dependencies: ["DaiJishowCore"],
            path: "platform-apple/macOS"
        )
    ]
)
