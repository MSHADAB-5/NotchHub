// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchHub",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "NotchHub",
            path: "NotchHub",
            exclude: [
                "Resources/Info.plist",
                "NotchHub.entitlements",
                "Resources/Assets.xcassets",
                "Resources/Scripts"
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "NotchHubTests",
            dependencies: ["NotchHub"],
            path: "NotchHubTests"
        )
    ]
)
