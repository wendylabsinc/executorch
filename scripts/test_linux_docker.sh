#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

set -euo pipefail

# Test Linux artifact bundle builds in Docker

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Testing Linux x86_64 Artifact Bundle Build in Docker ==="
echo ""

# Use Ubuntu image with build tools (we'll test Swift package later)
SWIFT_IMAGE="ubuntu:22.04"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
  echo "Error: Docker is not installed or not in PATH"
  exit 1
fi

echo "Using Docker image: ${SWIFT_IMAGE}"
echo "Source directory: ${SOURCE_ROOT_DIR}"
echo ""

# Run the build in Docker
docker run --rm \
  -v "${SOURCE_ROOT_DIR}:/executorch" \
  -w /executorch \
  "${SWIFT_IMAGE}" \
  bash -c "
    set -euxo pipefail

    echo '=== Installing dependencies ==='
    apt-get update

    # Install newer CMake from Kitware APT repository (3.22 doesn't support presets v6)
    apt-get install -y wget gpg software-properties-common
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null
    apt-get update
    apt-get install -y cmake

    # Install other dependencies
    apt-get install -y git python3 python3-pip binutils zstd rsync
    pip3 install certifi zstd

    echo ''
    echo '=== Initializing submodules ==='
    git config --global --add safe.directory /executorch
    git submodule update --init third-party/flatbuffers third-party/json third-party/gflags third-party/flatcc
    git submodule update --init backends/xnnpack/third-party/XNNPACK
    git submodule update --init backends/xnnpack/third-party/cpuinfo
    git submodule update --init backends/xnnpack/third-party/pthreadpool
    git submodule update --init backends/xnnpack/third-party/FP16
    git submodule update --init backends/xnnpack/third-party/FXdiv

    echo ''
    echo '=== Building artifact bundle ==='
    ./scripts/build_artifact_bundles.sh --linux-x86_64

    echo ''
    echo '=== Validating artifact bundle ==='
    ./scripts/validate_artifact_bundles.sh

    echo ''
    echo '=== Build Complete ==='
    ls -lh cmake-out/*.artifactbundle 2>/dev/null || true
  "

echo ""
echo "=== Docker Test Complete ==="
