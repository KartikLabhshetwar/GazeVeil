// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GazeVeil",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GazeVeil", targets: ["GazeVeil"]),
    ],
    targets: [
        .executableTarget(
            name: "GazeVeil",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "GazeVeilTests",
            dependencies: ["GazeVeil"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
