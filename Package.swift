// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Rango",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Rango",
            targets: ["Rango"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Rango",
            path: "Sources/Rango"
        )
    ]
)
