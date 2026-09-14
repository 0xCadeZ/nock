// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Nock", targets: ["Nock"])
    ],
    targets: [
        .executableTarget(
            name: "Nock",
            path: "Sources/Nock",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "NockTests",
            dependencies: ["Nock"],
            path: "Tests/NockTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
