// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PiPKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "PiPKit", targets: ["PiPKit"])
    ],
    targets: [
        .target(name: "PiPKit"),
        .testTarget(name: "PiPKitTests", dependencies: ["PiPKit"])
    ]
)
