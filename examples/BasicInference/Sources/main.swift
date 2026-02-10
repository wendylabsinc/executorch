/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

#if canImport(ExecuTorch)
import ExecuTorch
#endif

print("=== ExecuTorch Basic Inference Example ===")
print("Platform: \(getPlatformInfo())")
print("")

// This example demonstrates basic ExecuTorch usage across platforms
// To run with an actual model:
// 1. Export a PyTorch model to .pte format
// 2. Place the model file in this directory
// 3. Update the modelPath below

func getPlatformInfo() -> String {
    #if os(Linux)
    return "Linux"
    #elseif os(macOS)
    return "macOS"
    #elseif os(iOS)
    return "iOS"
    #else
    return "Unknown"
    #endif
}

func runBasicExample() {
    print("ExecuTorch cross-platform example")
    print("----------------------------------")

    #if canImport(ExecuTorch)
    print("✓ ExecuTorch framework imported successfully")
    print("✓ Cross-platform support working!")

    // Example: Check if a model file exists
    let modelPath = "model.pte"
    if FileManager.default.fileExists(atPath: modelPath) {
        print("✓ Found model at: \(modelPath)")

        // TODO: Load and run inference with ExecuTorch
        // let module = try Module(filePath: modelPath)
        // let result = try module.forward(inputs: [...])

        print("  To run inference, uncomment the Module loading code")
    } else {
        print("ℹ️  No model.pte found - this is just a framework test")
        print("  To test with a real model:")
        print("  1. Export a PyTorch model: python -m executorch.exir.export ...")
        print("  2. Place model.pte in this directory")
        print("  3. Run again")
    }
    #else
    print("✗ ExecuTorch framework not available")
    print("  Make sure to build the artifact bundles first:")
    print("  cd ../..")
    print("  ./scripts/build_artifact_bundles.sh --linux-x86_64  # or --macos")
    #endif

    print("")
    print("Example complete! ✓")
}

// Run the example
runBasicExample()
