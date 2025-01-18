//
//  Package.swift
//  AxisBank
//
//  Created by Desai on 16/01/25.
//

// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NatsCSwift",
    products: [
        // The public library, so you can `import NatsCSwift` in other projects.
        .library(
            name: "NatsCSwift",
            targets: ["NatsSwift"]
        )
    ],
    targets: [
        // The C target that compiles nats.c, conn.c, etc.
        // `publicHeadersPath: "include"` means Swift sees only the headers under `Sources/NatsC/include/`.
        .target(
            name: "NatsC",
            path: "Sources/NatsC",
            publicHeadersPath: "include",
            cSettings: [
                // Explicitly disable libevent and libuv references:
                .define("NATS_HAS_LIBEVENT", to: "0"),
                .define("NATS_HAS_LIBUV", to: "0")
            ],
            linkerSettings: [
                // No linking to libevent or libuv
            ]
        ),

        // The Swift wrapper target that depends on NatsC
        .target(
            name: "NatsSwift",
            dependencies: ["NatsC"],
            path: "Sources/NatsSwift"
        ),

        // (Optional) Test target for your unit tests
        .testTarget(
            name: "NatsCSwiftTests",
            dependencies: ["NatsSwift"],
            path: "Tests/NatsCSwiftTests"
        )
    ]
)
