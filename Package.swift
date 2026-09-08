// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenRouterWidget",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenRouterWidget", targets: ["OpenRouterWidget"])
    ],
    targets: [
        // All app logic and views live in a library target so that the test
        // target can depend on them (SwiftPM tests cannot link executables).
        .target(
            name: "OpenRouterWidgetCore",
            path: "Sources/OpenRouterWidgetCore"
        ),
        .executableTarget(
            name: "OpenRouterWidget",
            dependencies: ["OpenRouterWidgetCore"],
            path: "Sources/OpenRouterWidget"
        ),
        .testTarget(
            name: "OpenRouterWidgetTests",
            dependencies: ["OpenRouterWidgetCore"],
            path: "Tests/OpenRouterWidgetTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
