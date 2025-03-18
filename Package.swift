// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Crane",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "Crane",
            targets: ["Crane"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),

        .package(url: "https://github.com/liveview-native/liveview-native-core", from: "0.4.1-rc-2"),
    ],
    targets: [
        .target(
            name: "Crane",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "LiveViewNativeCore", package: "liveview-native-core"),
                // .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            plugins: [
                .plugin(name: "GRPCProtobufGenerator", package: "grpc-swift-protobuf")
            ]
        )
    ]
)
