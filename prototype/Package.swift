// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "posetool",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "posetool",
            path: "Sources/posetool"
        )
    ]
)
