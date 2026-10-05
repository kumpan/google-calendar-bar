// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "CalendarBar",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "CalendarBar"),
        .testTarget(name: "CalendarBarTests", dependencies: ["CalendarBar"]),
    ],
    swiftLanguageModes: [.v5]
)
