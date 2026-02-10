# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

# Preset for Swift Package Manager artifact bundle builds
# This preset builds all cross-platform frameworks for SwiftPM distribution
# Note: default.cmake is included automatically by CMakeLists.txt, not here

# Enable all core extensions
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_DATA_LOADER ON)
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_MODULE ON)
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_NAMED_DATA_MAP ON)
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_FLAT_TENSOR ON)
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_TENSOR ON)

# Enable XNNPACK backend
set_overridable_option(EXECUTORCH_BUILD_XNNPACK ON)
set_overridable_option(EXECUTORCH_BUILD_CPUINFO ON)
set_overridable_option(EXECUTORCH_BUILD_PTHREADPOOL ON)
set_overridable_option(EXECUTORCH_XNNPACK_ENABLE_WEIGHT_CACHE ON)
set_overridable_option(EXECUTORCH_XNNPACK_SHARED_WORKSPACE ON)
set_overridable_option(EXECUTORCH_XNNPACK_ENABLE_KLEIDI ON)

# Enable kernel types that don't require PyTorch
# NOTE: Optimized, quantized, and LLM kernels all require PyTorch headers for now
# Using portable kernels instead
set_overridable_option(EXECUTORCH_BUILD_PORTABLE_OPS ON)
set_overridable_option(EXECUTORCH_BUILD_KERNELS_OPTIMIZED OFF)
set_overridable_option(EXECUTORCH_BUILD_KERNELS_QUANTIZED OFF)
set_overridable_option(EXECUTORCH_BUILD_KERNELS_LLM OFF)

# Disable LLM extensions for now (requires PyTorch dependencies)
# TODO: Re-enable once PyTorch header conflicts are resolved
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_LLM OFF)
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_LLM_RUNNER OFF)

# Disable features that require PyTorch or are not needed for SwiftPM
set_overridable_option(EXECUTORCH_BUILD_PYBIND OFF)
set_overridable_option(EXECUTORCH_BUILD_TESTS OFF)
set_overridable_option(EXECUTORCH_BUILD_EXECUTOR_RUNNER OFF)
