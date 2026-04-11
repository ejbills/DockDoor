// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.54.3"),
    ],
    targets: [.target(name: "BuildTools", path: "", exclude: ["Package.resolved", ".build"])]
)
