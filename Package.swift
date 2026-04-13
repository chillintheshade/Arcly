// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PieMenu",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PieMenu",
            path: "Sources/PieMenu"
        )
    ]
)
