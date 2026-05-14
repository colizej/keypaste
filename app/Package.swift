// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "KeyPaste",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "KeyPaste", targets: ["KeyPaste"])
    ],
    dependencies: [
        // No external dependencies yet. Candidates for later:
        // .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        // .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "KeyPaste",
            path: "Sources/KeyPaste"
        ),
        .testTarget(
            name: "KeyPasteTests",
            dependencies: ["KeyPaste"],
            path: "Tests/KeyPasteTests"
        )
    ]
)
