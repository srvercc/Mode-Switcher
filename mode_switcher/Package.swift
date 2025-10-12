// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ModeSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/cocoabits/MASShortcut.git", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "ModeSwitcherApp",
            dependencies: [
                .product(name: "MASShortcut", package: "MASShortcut")
            ]
        )
    ]
)
