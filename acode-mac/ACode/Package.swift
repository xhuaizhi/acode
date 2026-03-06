// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ACode",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // SQLite.swift - 轻量级 SQLite 封装（本地依赖）
        .package(path: "../deps/SQLite.swift-0.15.3"),
        // SwiftTerm - macOS 终端模拟器（本地依赖）
        .package(path: "../deps/SwiftTerm-main"),
    ],
    targets: [
        .executableTarget(
            name: "ACode",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift-0.15.3"),
                .product(name: "SwiftTerm", package: "SwiftTerm-main"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ACodeTests",
            dependencies: ["ACode"],
            path: "Tests"
        ),
    ]
)
