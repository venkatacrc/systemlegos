// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SystemLegos",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SystemLegos",
            resources: [.copy("Resources/deck.json")]
        )
    ]
)
