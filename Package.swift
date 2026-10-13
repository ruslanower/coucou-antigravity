// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TukTuk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TukTuk",
            targets: ["TukTuk"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TukTuk",
            path: "Sources/TukTuk"
        )
    ]
)
