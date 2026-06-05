// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "video_thumbnail",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "video-thumbnail", targets: ["video_thumbnail"])
    ],
    targets: [
        .target(
            name: "video_thumbnail",
            path: "Sources/video_thumbnail",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("UIKit")
            ]
        )
    ]
)
