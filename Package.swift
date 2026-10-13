// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoucouAntigravity",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "CoucouAntigravity",
            targets: ["CoucouAntigravity"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CoucouAntigravity",
            path: "Sources/CoucouAntigravity",
            exclude: ["Resources"]
        )
    ]
)
