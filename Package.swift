// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KitchenCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "KitchenCore", targets: ["KitchenCore"])
    ],
    targets: [
        .target(name: "KitchenCore"),
        .testTarget(name: "KitchenCoreTests", dependencies: ["KitchenCore"]),
    ],
    swiftLanguageModes: [.v6]
)
