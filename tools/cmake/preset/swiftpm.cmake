# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

# Preset for Swift Package Manager artifact bundle builds
# This is a minimal preset that builds only what's needed for SwiftPM distribution

include(${PROJECT_SOURCE_DIR}/tools/cmake/preset/default.cmake)

# Enable core features needed for SwiftPM
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_DATA_LOADER ON)
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_MODULE ON)
set_overridable_option(EXECUTORCH_BUILD_EXTENSION_TENSOR ON)

# Enable XNNPACK backend
set_overridable_option(EXECUTORCH_BUILD_XNNPACK ON)
set_overridable_option(EXECUTORCH_BUILD_PTHREADPOOL ON)

# Enable optimized and quantized kernels
set_overridable_option(EXECUTORCH_BUILD_KERNELS_OPTIMIZED ON)
set_overridable_option(EXECUTORCH_BUILD_KERNELS_QUANTIZED ON)

# Disable features that require PyTorch or are not needed for SwiftPM
set_overridable_option(EXECUTORCH_BUILD_PYBIND OFF)
set_overridable_option(EXECUTORCH_BUILD_TESTS OFF)
set_overridable_option(EXECUTORCH_BUILD_EXECUTOR_RUNNER OFF)
