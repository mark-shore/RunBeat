// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RunBeat",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "RunBeat", targets: ["RunBeat"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.20.0"),
        .package(url: "https://github.com/spotify/ios-sdk", from: "2.1.6")
    ],
    targets: [
        .target(
            name: "RunBeat",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "SpotifyiOS", package: "ios-sdk")
            ]
        )
    ]
)