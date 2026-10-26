// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sweep",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Sweep", targets: ["Sweep"]),
        .library(name: "SweepCore", targets: ["SweepCore"]),
    ],
    targets: [
        // Scanning, rules, profiles and safe deletion. No UI code, so it can be unit tested.
        .target(name: "SweepCore"),
        // The menu bar app itself (SwiftUI + AppKit).
        .executableTarget(name: "Sweep", dependencies: ["SweepCore"]),
        .testTarget(name: "SweepCoreTests", dependencies: ["SweepCore"]),
    ]
)
