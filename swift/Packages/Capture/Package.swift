// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Capture",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Capture",
            targets: ["Capture"]
        )
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        .target(
            name: "Capture",
            dependencies: ["Core"]
        )
    ]
)
