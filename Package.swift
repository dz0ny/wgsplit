// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "wgsplit",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WGSplitKit", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "wgsplitd", dependencies: ["WGSplitKit"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "WGSplitKitTests", dependencies: ["WGSplitKit"],
                    resources: [.copy("Fixtures")],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
