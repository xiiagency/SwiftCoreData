// swift-tools-version:5.5
import PackageDescription

let package =
  Package(
    name: "SwiftCoreData",
    platforms: [
      .iOS(.v15),
      .watchOS(.v8),
      .macOS(.v12),
    ],
    products: [
      .library(
        name: "SwiftCoreData",
        targets: ["SwiftCoreData"]
      ),
    ],
    dependencies: [
      .package(
        name: "SwiftConcurrency",
        url: "https://github.com/xiiagency/SwiftConcurrency",
        .upToNextMinor(from: "1.0.0")
      ),
      .package(
        name: "SwiftFoundationExtensions",
        url: "https://github.com/xiiagency/SwiftFoundationExtensions",
        .upToNextMinor(from: "1.0.0")
      ),
    ],
    targets: [
      .target(
        name: "SwiftCoreData",
        dependencies: [
          "SwiftConcurrency",
          "SwiftFoundationExtensions",
        ]
      ),
    ]
  )
