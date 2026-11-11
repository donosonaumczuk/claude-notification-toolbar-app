// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ClaudeNotifier",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeNotifier",
            path: "Sources/ClaudeNotifier"
        )
    ]
)
