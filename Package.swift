// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkTrafficLight",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NetworkTrafficLight", targets: ["NetworkTrafficLightApp"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            from: "2.9.4"
        )
    ],
    targets: [
        .target(name: "NetworkTrafficLightCore"),
        .executableTarget(
            name: "NetworkTrafficLightApp",
            dependencies: [
                "NetworkTrafficLightCore",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .executableTarget(
            name: "NetworkTrafficLightChecks",
            dependencies: ["NetworkTrafficLightCore"],
            path: "Checks/NetworkTrafficLightChecks"
        )
    ]
)
