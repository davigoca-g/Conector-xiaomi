// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ConectorXiaomi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ConectorXiaomi",
            path: "Sources/ConectorXiaomi"
        )
    ]
)
