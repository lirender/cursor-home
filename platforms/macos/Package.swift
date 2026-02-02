// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorHome",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CursorHome", targets: ["CursorHome"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "CursorHome",
            dependencies: ["HotKey"],
            path: "Sources/CursorHome",
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)
