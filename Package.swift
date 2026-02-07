// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FLACMusic",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "FLACMusic",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/FLACMusic"
        ),
        .testTarget(
            name: "FLACMusicTests",
            dependencies: ["FLACMusic"],
            path: "Tests/FLACMusicTests"
        ),
    ]
)
