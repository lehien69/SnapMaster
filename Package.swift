// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SnapMaster",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SnapMaster", targets: ["SnapMaster"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SnapMaster",
            dependencies: [],
            path: "Sources/SnapMaster",
            resources: []
        )
    ],
    swiftLanguageModes: [.v5]
)
