// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Beast",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Beast", targets: ["Beast"]),
    ],
    targets: [
        // The game itself: a direct translation of src/Beast.p, no AppKit.
        .target(name: "BeastCore"),
        // The Mac app: window, menus, dialogs, drawing.
        .executableTarget(name: "Beast", dependencies: ["BeastCore"]),
        .testTarget(name: "BeastCoreTests", dependencies: ["BeastCore"]),
    ]
)
