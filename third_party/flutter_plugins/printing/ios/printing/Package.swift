// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "printing",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "printing", targets: ["printing"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "printing",
            dependencies: [],
            resources: []
        )
    ]
)
