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
    dependencies: [
        // Session 19b: TelemetryDeck SDK. The engine package owns the
        // TelemetryService protocol and the LoggingTelemetryService /
        // RecordingTelemetryService impls already; the production
        // TelemetryDeckTelemetryService lives alongside them so the App
        // layer just imports SixthSeat and picks the right impl.
        .package(url: "https://github.com/TelemetryDeck/SwiftSDK", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SixthSeat",
            dependencies: [
                .product(name: "TelemetryDeck", package: "SwiftSDK")
            ]
        ),
        .testTarget(name: "SixthSeatTests", dependencies: ["SixthSeat"])
    ]
)
