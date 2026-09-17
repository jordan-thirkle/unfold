// swift-tools-version:6.0
import PackageDescription

// Swift Testing lives outside the SDK in current Command Line Tools
// (XCTest was removed in CLT 26.x). Point the compiler and linker at the
// CLT Testing.framework so `swift test` works from a plain CLT install.
let testingSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
]

let testingLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"]),
    .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"]),
    .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"])
]

let package = Package(
    name: "Unfold",
    platforms: [
        .macOS("14.0")
    ],
    products: [
        .library(name: "UnfoldCore", targets: ["UnfoldCore"]),
        .executable(name: "Unfold", targets: ["UnfoldApp"]),
        .executable(name: "unfold-verify", targets: ["unfold-verify"])
    ],
    targets: [
        // Deterministic simulation. No AppKit, no I/O, no globals — so the
        // fold can be tested frame-by-frame without a display.
        .target(
            name: "UnfoldCore",
            path: "Sources/UnfoldCore"
        ),
        // The executable assertions. Framework-free on purpose: XCTest was
        // removed from the Command Line Tools in CLT 26.x, and `swift test`
        // silently runs nothing without it. See UnfoldChecks.swift.
        .target(
            name: "UnfoldChecks",
            dependencies: ["UnfoldCore"],
            path: "Sources/UnfoldChecks"
        ),
        .executableTarget(
            name: "unfold-verify",
            dependencies: ["UnfoldChecks"],
            path: "Sources/unfold-verify"
        ),
        // Menu bar agent: event sources + overlay rendering.
        .executableTarget(
            name: "UnfoldApp",
            dependencies: ["UnfoldCore"],
            path: "Sources/UnfoldApp"
        ),
        // Thin wrappers over UnfoldChecks, so `swift test` works in a full
        // Xcode toolchain without duplicating a single assertion.
        .testTarget(
            name: "UnfoldCoreTests",
            dependencies: ["UnfoldCore", "UnfoldChecks"],
            path: "Tests/UnfoldCoreTests",
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        )
    ]
)
