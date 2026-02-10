// swift-tools-version: 6.2
/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import PackageDescription

let package = Package(
    name: "BasicInference",
    platforms: [
        .macOS(.v12),
        .iOS(.v17),
    ],
    dependencies: [
        // Reference the local executorch package
        .package(name: "executorch", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "BasicInference",
            dependencies: [
                .product(name: "executorch", package: "executorch"),
                .product(name: "backend_xnnpack", package: "executorch"),
            ]
        ),
    ]
)
