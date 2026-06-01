// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnvSwitch",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EnvSwitchCore", targets: ["EnvSwitchCore"]),
        .executable(name: "envswitch", targets: ["envswitch"]),
        .executable(name: "EnvSwitchGUI", targets: ["EnvSwitchGUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "EnvSwitchCore",
            dependencies: [.product(name: "TOMLKit", package: "TOMLKit")]
        ),
        .executableTarget(
            name: "envswitch",
            dependencies: [
                "EnvSwitchCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "EnvSwitchGUI",
            dependencies: ["EnvSwitchCore"]
        ),
        .testTarget(
            name: "EnvSwitchCoreTests",
            dependencies: ["EnvSwitchCore"]
        ),
    ]
)
