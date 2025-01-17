//
//  Package.swift
//  AxisBank
//
//  Created by Desai on 16/01/25.
//

// swift-tools-version:6.0
import PackageDescription
import Foundation   // for environment checks if you want them

// ----------------------------------------------------
// 1) Decide if you want libevent or libuv by default.
//    For example, let's say we enable libevent, disable libuv:
// ----------------------------------------------------
let envUseLibEvent = ProcessInfo.processInfo.environment["USE_LIBEVENT"] == "1"
let envUseLibUV    = ProcessInfo.processInfo.environment["USE_LIBUV"] == "1"

// Construct your CSettings array:
var natsCCSettings: [CSetting] = [
    .unsafeFlags(["-I/opt/homebrew/include"])  // So we can find <event.h> or <uv.h>
]

// If you want to define NATS_HAS_LIBEVENT=1 or 0 based on your boolean:
if envUseLibEvent {
    natsCCSettings.append(.define("NATS_HAS_LIBEVENT", to: "1"))
} else {
    natsCCSettings.append(.define("NATS_HAS_LIBEVENT", to: "0"))
}

// Similarly for libuv:
if envUseLibUV {
    natsCCSettings.append(.define("NATS_HAS_LIBUV", to: "1"))
} else {
    natsCCSettings.append(.define("NATS_HAS_LIBUV", to: "0"))
}

// ----------------------------------------------------
// 2) Set up the library linking array
// ----------------------------------------------------
var natsLinkerSettings: [LinkerSetting] = []

if envUseLibEvent {
    // Link libevent
    natsLinkerSettings.append(.linkedLibrary("event"))
    // If you need event_core or event_extra, you can add them too:
    // natsLinkerSettings.append(.linkedLibrary("event_core"))
    // natsLinkerSettings.append(.linkedLibrary("event_extra"))
}

if envUseLibUV {
    // Link libuv
    natsLinkerSettings.append(.linkedLibrary("uv"))
}

// ----------------------------------------------------
// 3) Define the Swift Package
// ----------------------------------------------------
let package = Package(
    name: "NatsCSwift",
    products: [
        // The Swift library others can `import NatsCSwift` from
        .library(
            name: "NatsCSwift",
            targets: ["NatsSwift"]
        )
    ],
    targets: [
        // C target: nats.c sources
        .target(
            name: "NatsC",
            path: "Sources/NatsC",
            // Where SwiftPM expects public headers for the module
            publicHeadersPath: "include",
            cSettings: natsCCSettings,        // The array we built above
            linkerSettings: natsLinkerSettings
        ),
        // Swift target that wraps NatsC
        .target(
            name: "NatsSwift",
            dependencies: ["NatsC"],
            path: "Sources/NatsSwift",
            // Swift’s Clang importer also needs -I/opt/homebrew/include:
            cSettings: [
                .unsafeFlags(["-I/opt/homebrew/include"])
            ]
        ),
        // Test target
        .testTarget(
            name: "NatsCSwiftTests",
            dependencies: ["NatsSwift"],
            path: "Tests/NatsCSwiftTests"
        )
    ]
)
