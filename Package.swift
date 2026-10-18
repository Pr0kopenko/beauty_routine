// swift-tools-version:5.9
import PackageDescription

// Ядро приложения без UI — для `swift test` на macOS и Linux.
// Те же исходники компилируются в таргет приложения через CareTracker.xcodeproj.
let package = Package(
    name: "RitmCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(name: "RitmCore", path: "CareTracker/Core", resources: [.copy("Resources/ingredients-kb.json")]),
        .testTarget(name: "RitmCoreTests", dependencies: ["RitmCore"], path: "Tests/RitmCoreTests"),
    ]
)
