// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MiniPlayer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MiniPlayer",
            path: "Sources/MiniPlayer"
        )
    ]
)
