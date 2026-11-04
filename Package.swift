// swift-tools-version:5.9
import PackageDescription

// The app target needs macOS 14. Linux CI and `swift test` only build the
// logic module; an empty platform list lets that succeed here.
#if os(macOS)
let packagePlatforms: [SupportedPlatform] = [.macOS(.v14)]
#else
let packagePlatforms: [SupportedPlatform]? = nil
#endif

let package = Package(
    name: "SpellingBee",
    platforms: packagePlatforms,
    products: [
        .library(name: "SpellingBeeCore", targets: ["SpellingBeeCore"]),
        .executable(name: "SpellingBee", targets: ["SpellingBee"]),
    ],
    targets: [
        .target(name: "SpellingBeeCore"),
        .executableTarget(
            name: "SpellingBee",
            dependencies: ["SpellingBeeCore"],
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("SwiftUI", .when(platforms: [.macOS])),
                .linkedFramework("AVFoundation", .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "SpellingBeeCoreTests",
            dependencies: ["SpellingBeeCore"]
        ),
    ]
)
