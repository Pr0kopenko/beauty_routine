// swift-tools-version:5.9
// Чистая логика «Ритма кожи» (CareTracker/Core) как пакет — для `swift test` на macOS и Linux.
// Те же файлы компилируются в приложение через synchronized group в CareTracker.xcodeproj.
import PackageDescription

let package = Package(
    name: "RitmCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(name: "RitmCore", path: "CareTracker/Core"),
        .testTarget(name: "RitmCoreTests", dependencies: ["RitmCore"], path: "Tests/RitmCoreTests"),
    ]
)
