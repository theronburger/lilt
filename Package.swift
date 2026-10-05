// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lilt",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Lilt", targets: ["Lilt"])],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "3.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "LiltCore"),
        .executableTarget(name: "Lilt", dependencies: ["LiltCore", "KeyboardShortcuts", .product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "LiltCoreTests", dependencies: ["LiltCore"]),
        .testTarget(name: "LiltTests", dependencies: ["Lilt", "LiltCore"])
    ],
    swiftLanguageModes: [.v5]
)
