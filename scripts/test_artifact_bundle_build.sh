#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

set -euo pipefail

# Test script for artifact bundle builds
# Can be run on macOS or in Docker for Linux testing

SOURCE_ROOT_DIR=$(git rev-parse --show-toplevel)
cd "${SOURCE_ROOT_DIR}"

echo "=== Artifact Bundle Build Test ==="
echo ""

# Detect platform
PLATFORM=$(uname -s)
echo "Platform: ${PLATFORM}"
echo ""

# Determine which platforms to build
if [ "$PLATFORM" = "Darwin" ]; then
  echo "Building for macOS..."
  BUILD_FLAGS="--macos"
elif [ "$PLATFORM" = "Linux" ]; then
  echo "Building for Linux x86_64..."
  BUILD_FLAGS="--linux-x86_64"
else
  echo "Unsupported platform: ${PLATFORM}"
  exit 1
fi

# Clean previous builds
echo "=== Cleaning previous builds ==="
rm -rf cmake-out/swiftpm
rm -rf cmake-out/*.artifactbundle
echo ""

# Build artifact bundles
echo "=== Building artifact bundles ==="
./scripts/build_artifact_bundles.sh ${BUILD_FLAGS}
echo ""

# Validate artifact bundles
echo "=== Validating artifact bundles ==="
./scripts/validate_artifact_bundles.sh
echo ""

# Check Package@swift-6.2.swift syntax
echo "=== Checking Package@swift-6.2.swift syntax ==="
if command -v swift &> /dev/null; then
  SWIFT_VERSION=$(swift --version | head -n1)
  echo "Swift version: ${SWIFT_VERSION}"

  # Check if we have Swift 6.2+
  if swift --version | grep -q "Swift version 6\.[2-9]"; then
    echo "Testing package resolution..."
    if swift package resolve 2>&1 | tee /tmp/swift-resolve.log; then
      echo "✓ Package resolved successfully"
    else
      echo "✗ Package resolution failed"
      cat /tmp/swift-resolve.log
      exit 1
    fi

    # Try to build (may fail if dependencies are missing, but should parse)
    echo "Testing package dump..."
    if swift package dump-package > /dev/null 2>&1; then
      echo "✓ Package manifest is valid"
    else
      echo "✗ Package manifest has errors"
      swift package dump-package
      exit 1
    fi
  else
    echo "⚠ Swift 6.2+ not available, skipping Swift package tests"
    echo "  Install Swift 6.2+ to test Package@swift-6.2.swift"
  fi
else
  echo "⚠ Swift not found, skipping Swift package tests"
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo "✓ Artifact bundles built successfully"
echo "✓ Artifact bundles validated"
if command -v swift &> /dev/null && swift --version | grep -q "Swift version 6\.[2-9]"; then
  echo "✓ Package manifest validated"
fi
echo ""
echo "=== Test Complete ==="
echo ""
echo "Artifact bundles are in: cmake-out/"
ls -lh cmake-out/*.artifactbundle 2>/dev/null || true
