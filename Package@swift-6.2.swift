// swift-tools-version:6.2
/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

// NOTE: This package manifest is for Swift 6.2+ with cross-platform support.
// It uses artifact bundles to support Linux, macOS, and iOS platforms.
// For frameworks built locally with CMake, use the main Package.swift.
//
// To use prebuilt binaries, switch to one of the "swiftpm-6.2" branches,
// which fetch the precompiled artifact bundles.
//
// For details on building artifact bundles locally or using prebuilt binaries,
// see the documentation:
// https://pytorch.org/executorch/main/using-executorch-ios

import PackageDescription

let debug_suffix = "_debug"
let dependencies_suffix = "_with_dependencies"

func deliverables(_ dict: [String: [String: Any]]) -> [String: [String: Any]] {
  dict
    .reduce(into: [String: [String: Any]]()) { result, pair in
      let (key, value) = pair
      result[key] = value
      result[key + debug_suffix] = value
    }
    .reduce(into: [String: [String: Any]]()) { result, pair in
      let (key, value) = pair
      var newValue = value
      if key.hasSuffix(debug_suffix) {
        for (k, v) in value where k.hasSuffix(debug_suffix) {
          let trimmed = String(k.dropLast(debug_suffix.count))
          newValue[trimmed] = v
        }
      }
      result[key] = newValue.filter { !$0.key.hasSuffix(debug_suffix) }
    }
}

// Cross-platform products (Linux, macOS, iOS)
let crossPlatformProducts = deliverables([
  "backend_xnnpack": [
    "targets": [
      "threadpool",
    ],
  ],
  "executorch": [
    "libraries": [
      "c++",
    ],
    "linuxLibraries": [
      "pthread",
    ],
  ],
  "executorch_llm": [
    "targets": [
      "executorch",
    ],
  ],
  "kernels_llm": [:],
  "kernels_optimized": [
    "appleFrameworks": [
      "Accelerate",
    ],
    "targets": [
      "threadpool",
    ],
  ],
  "kernels_quantized": [:],
])

// Apple-only products (macOS, iOS)
let appleOnlyProducts = deliverables([
  "backend_coreml": [
    "frameworks": [
      "Accelerate",
      "CoreML",
    ],
    "libraries": [
      "sqlite3",
    ],
  ],
  "backend_mps": [
    "frameworks": [
      "Metal",
      "MetalPerformanceShaders",
      "MetalPerformanceShadersGraph",
    ],
  ],
])

// Merge all products
let products = crossPlatformProducts.merging(appleOnlyProducts) { (current, _) in current }

let targets = deliverables([
  "threadpool": [:],
])

let packageProducts: [Product] = products.keys.map { key -> Product in
  .library(name: key, targets: ["\(key)\(dependencies_suffix)"])
}.sorted { $0.name < $1.name }

var packageTargets: [Target] = []

for (key, value) in targets {
  packageTargets.append(.binaryTarget(
    name: key,
    path: "cmake-out/\(key).artifactbundle"
  ))
}

for (key, value) in products {
  packageTargets.append(.binaryTarget(
    name: key,
    path: "cmake-out/\(key).artifactbundle"
  ))

  var linkerSettings: [LinkerSetting] = []

  // Apple frameworks (macOS and iOS only)
  if let appleFrameworks = value["appleFrameworks"] as? [String] {
    linkerSettings.append(contentsOf: appleFrameworks.map {
      .linkedFramework($0, .when(platforms: [.iOS, .macOS]))
    })
  }

  // Legacy "frameworks" key (Apple-only, kept for backwards compatibility)
  if let frameworks = value["frameworks"] as? [String] {
    linkerSettings.append(contentsOf: frameworks.map {
      .linkedFramework($0, .when(platforms: [.iOS, .macOS]))
    })
  }

  // Cross-platform libraries (libc++ on all platforms)
  if let libraries = value["libraries"] as? [String] {
    linkerSettings.append(contentsOf: libraries.map { .linkedLibrary($0) })
  }

  // Linux-specific libraries (pthread)
  if let linuxLibraries = value["linuxLibraries"] as? [String] {
    linkerSettings.append(contentsOf: linuxLibraries.map {
      .linkedLibrary($0, .when(platforms: [.linux]))
    })
  }

  let target: Target = .target(
    name: "\(key)\(dependencies_suffix)",
    dependencies: ([key] + (value["targets"] as? [String] ?? []).map {
      key.hasSuffix(debug_suffix) ? $0 + debug_suffix : $0
    }).map { .target(name: $0) },
    path: ".Package.swift/\(key)",
    linkerSettings: linkerSettings
  )
  packageTargets.append(target)
}

let package = Package(
  name: "executorch",
  platforms: [
    .iOS(.v17),
    .macOS(.v12),
  ],
  products: packageProducts,
  targets: packageTargets + [
    .testTarget(
      name: "tests",
      dependencies: [
        .target(name: "executorch\(debug_suffix)"),
        .target(name: "kernels_optimized\(dependencies_suffix)"),
      ],
      path: "extension/apple/ExecuTorch/__tests__",
      resources: [
        .copy("resources/add.pte"),
      ],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-force_load",
          "-Xlinker", "cmake-out/kernels_optimized.artifactbundle/macos-arm64/libkernels_optimized.a",
        ], .when(platforms: [.macOS]))
      ]
    )
  ]
)
