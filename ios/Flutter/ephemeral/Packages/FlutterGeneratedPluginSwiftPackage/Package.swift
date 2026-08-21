// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "app_links", path: "../.packages/app_links-7.2.1"),
        .package(name: "geocoding_ios", path: "../.packages/geocoding_ios-3.1.0"),
        .package(name: "geolocator_apple", path: "../.packages/geolocator_apple-2.3.14"),
        .package(name: "image_picker_ios", path: "../.packages/image_picker_ios-0.8.13+6"),
        .package(name: "package_info_plus", path: "../.packages/package_info_plus-10.2.1"),
        .package(name: "share_plus", path: "../.packages/share_plus-13.3.0"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.6"),
        .package(name: "sign_in_with_apple", path: "../.packages/sign_in_with_apple-8.1.0"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.4.1"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "app-links", package: "app_links"),
                .product(name: "geocoding-ios", package: "geocoding_ios"),
                .product(name: "geolocator-apple", package: "geolocator_apple"),
                .product(name: "image-picker-ios", package: "image_picker_ios"),
                .product(name: "package-info-plus", package: "package_info_plus"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "sign-in-with-apple", package: "sign_in_with_apple"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
