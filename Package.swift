// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LSLS",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "LSLS",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/LSLS",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "LSLSTests",
            dependencies: ["LSLS"],
            path: "Tests/LSLSTests"
        ),
    ]
)
