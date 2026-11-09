// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Metrixator",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Metrixator", targets: ["Metrixator"]),
        .library(name: "MetrixatorCore", targets: ["MetrixatorCore"]),
    ],
    targets: [
        // Logique métier pure (Foundation uniquement) : testable sur macOS et Linux.
        .target(name: "MetrixatorCore"),
        // Interface SwiftUI (macOS uniquement).
        .executableTarget(name: "Metrixator", dependencies: ["MetrixatorCore"]),
        .testTarget(name: "MetrixatorCoreTests", dependencies: ["MetrixatorCore"]),
    ]
)
