// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Susurro",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SusurroCore"),
        .executableTarget(name: "Susurro", dependencies: ["SusurroCore"]),
        .testTarget(name: "SusurroCoreTests", dependencies: ["SusurroCore"]),
    ]
)
