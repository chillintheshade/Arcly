// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Arcly",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Arcly",
            path: "Sources/Arcly",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
