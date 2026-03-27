// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HaMenake",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "HaMenake",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
