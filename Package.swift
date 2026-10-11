// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaLens",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MediaLens", targets: ["MediaLens"])],
    targets: [
        .target(name: "MediaLensCore"),
        .executableTarget(name: "MediaLens", dependencies: ["MediaLensCore"]),
        .executableTarget(name: "MediaLensChecks", dependencies: ["MediaLensCore"], path: "Tests/MediaLensCoreTests")
    ]
)
