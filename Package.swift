// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PhotoBrowser",
    platforms: [.iOS(.v10)],
    products: [
        .library(name: "PhotoLib", targets: ["PhotoLib"]),
        .library(name: "PhotoBrowserUIKit", targets: ["PhotoBrowserUIKit"]),
        
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "PhotoLib", dependencies: [], path: "Sources/PhotoBrowser/PhotoLib", sources: [""]),
        .target(name: "PhotoBrowserUIKit", dependencies: ["PhotoLib"], path: "Sources/PhotoBrowser/PhotoBrowserUIKit", sources: ["Media", "Manager", "PhotoTool", "View", "ViewController"], resources: [.process("PhotoBrowser.bundle")]),
        
        

        .testTarget(
            name: "PhotoBrowserTests",
            dependencies: []),
    ],
    swiftLanguageVersions: [.v5]
)
