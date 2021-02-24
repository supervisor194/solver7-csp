// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Solver7CSP",
    products: [
        .library(
            name: "Solver7CSP",
            targets: ["Solver7CSP"]),
    ],
    dependencies: [
        .package(
                url: "https://github.com/apple/swift-atomics.git",
                from: "0.0.1"
        )
    ],
    targets: [
        .target(
            name: "Solver7CSP",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics")
            ]),
        .testTarget(
            name: "Solver7CSPTests",
            dependencies: ["Solver7CSP"]),
    ]
)
