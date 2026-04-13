// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "TypingLensMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TypingLensMac",
            targets: ["TypingLensMac"]
        )
    ],
    dependencies: [
        .package(path: "../../swift/Packages/Core"),
        .package(path: "../../swift/Packages/Capture")
    ],
    targets: [
        .executableTarget(
            name: "TypingLensMac",
            dependencies: [
                "Core",
                "Capture"
            ],
            path: "Sources/TypingLensMac"
        )
    ]
)
