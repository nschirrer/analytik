// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Analytik",
    platforms: [.macOS("14.4")],
    products: [
        .library(name: "AnalytikCore", targets: ["AnalytikCore"]),
        .executable(name: "Analytik", targets: ["Analytik"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", .upToNextMinor(from: "0.14.2")),
    ],
    targets: [
        .target(
            name: "AnalytikCore",
            dependencies: [.product(name: "CoreXLSX", package: "CoreXLSX")]
        ),
        .executableTarget(
            name: "Analytik",
            dependencies: ["AnalytikCore"]
        ),
        .testTarget(
            name: "AnalytikCoreTests",
            dependencies: ["AnalytikCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
