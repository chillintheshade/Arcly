// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PieMenu",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "PieMenu",
            path: "Sources/PieMenu",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
