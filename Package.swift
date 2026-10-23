// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "KitchenCore",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "KitchenCore", targets: ["KitchenCore"])
    ],
    targets: [
        .target(name: "KitchenCore"),
        .testTarget(name: "KitchenCoreTests", dependencies: ["KitchenCore"]),
    ],
    swiftLanguageModes: [.v6]
)
