// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SixthSeat",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SixthSeat", targets: ["SixthSeat"])
    ],
    targets: [
        .target(name: "SixthSeat"),
        .testTarget(name: "SixthSeatTests", dependencies: ["SixthSeat"])
    ]
)
