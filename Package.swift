// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HWiD",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
          .library(
              name: "HWiD",
              targets: ["HWiD"]
          ),
      ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0")
    ],
    targets: [
        .target (
            name: "HWiD",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
    ]
)
