// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MouseKeyboard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MouseKeyboard",
            path: "Sources/MouseKeyboard"
        )
    ]
)
