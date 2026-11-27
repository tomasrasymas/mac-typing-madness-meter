// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TypingMadness",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure game rules and speed colors: no AppKit, unit-tested.
        .target(name: "MadnessCore"),
        // The menu-bar app: key tap, overlay, floating meter.
        .executableTarget(name: "TypingMadness", dependencies: ["MadnessCore"]),
        // `swift run selftest`: checks for MadnessCore. A plain executable because
        // XCTest and the Swift Testing macros need full Xcode, not just the
        // Command Line Tools.
        .executableTarget(name: "selftest", dependencies: ["MadnessCore"]),
    ]
)
