// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkTrafficLight",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NetworkTrafficLight", targets: ["NetworkTrafficLightApp"])
    ],
    targets: [
        .target(name: "NetworkTrafficLightCore"),
        .executableTarget(
            name: "NetworkTrafficLightApp",
            dependencies: ["NetworkTrafficLightCore"]
        ),
        .executableTarget(
            name: "NetworkTrafficLightChecks",
            dependencies: ["NetworkTrafficLightCore"],
            path: "Checks/NetworkTrafficLightChecks"
        )
    ]
)
