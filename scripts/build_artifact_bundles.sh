#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

set -euxo pipefail

# Build artifact bundles for Swift Package Manager 6.2+ cross-platform support
# Supports Linux x86_64, Linux ARM64, macOS, iOS platforms

SOURCE_ROOT_DIR=$(git rev-parse --show-toplevel)
OUTPUT_DIR="${SOURCE_ROOT_DIR}/cmake-out"
SWIFTPM_OUTPUT_DIR="${OUTPUT_DIR}/swiftpm"
VERSION="1.2.0"

BUCK2=$(python3 "$SOURCE_ROOT_DIR/tools/cmake/resolve_buck.py" --cache_dir="$SOURCE_ROOT_DIR/buck2-bin")
if [[ "$BUCK2" == "buck2" ]]; then
  BUCK2=$(command -v buck2)
fi

# Platform support flags
BUILD_LINUX_X86_64=false
BUILD_LINUX_AARCH64=false
BUILD_MACOS=false
BUILD_IOS=false
BUILD_ALL=false

# Build mode (Release or Debug)
BUILD_MODE="Release"

# Framework definitions
# Format: "name:component_libs:has_headers"
FRAMEWORK_EXECUTORCH="executorch:libexecutorch.a,libexecutorch_core.a,libextension_apple.a,libextension_data_loader.a,libextension_flat_tensor.a,libextension_module.a,libextension_named_data_map.a,libextension_tensor.a:yes"
FRAMEWORK_EXECUTORCH_LLM="executorch_llm:libabsl_base.a,libabsl_city.a,libabsl_hash.a,libabsl_int128.a,libabsl_low_level_hash.a,libabsl_raw_hash_set.a,libabsl_strings.a,libabsl_strings_internal.a,libextension_llm_runner.a,libre2.a,libsentencepiece.a,libtokenizers.a:no"
FRAMEWORK_THREADPOOL="threadpool:libcpuinfo.a,libextension_threadpool.a,libpthreadpool.a:no"
FRAMEWORK_BACKEND_XNNPACK="backend_xnnpack:libXNNPACK.a,libkleidiai.a,libxnnpack_backend.a,libxnnpack-microkernels-prod.a:no"
FRAMEWORK_KERNELS_LLM="kernels_llm:libcustom_ops.a:no"
FRAMEWORK_KERNELS_OPTIMIZED="kernels_optimized:libcpublas.a,liboptimized_kernels.a,liboptimized_native_cpu_ops_lib.a,libportable_kernels.a:no"
FRAMEWORK_KERNELS_QUANTIZED="kernels_quantized:libquantized_kernels.a,libquantized_ops_lib.a:no"

# All frameworks to build (Phase 2: Complete framework coverage)
FRAMEWORKS=(
  "$FRAMEWORK_EXECUTORCH"
  "$FRAMEWORK_THREADPOOL"
  "$FRAMEWORK_BACKEND_XNNPACK"
  "$FRAMEWORK_KERNELS_OPTIMIZED"
  "$FRAMEWORK_KERNELS_QUANTIZED"
  "$FRAMEWORK_KERNELS_LLM"
  "$FRAMEWORK_EXECUTORCH_LLM"
)

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Build artifact bundles for Swift Package Manager 6.2+."
  echo
  echo "Platform Options:"
  echo "  --linux-x86_64       Build for Linux x86_64"
  echo "  --linux-aarch64      Build for Linux ARM64"
  echo "  --macos              Build for macOS ARM64"
  echo "  --ios                Build for iOS (device + simulator)"
  echo "  --all-platforms      Build for all supported platforms"
  echo
  echo "Build Options:"
  echo "  --Debug              Build Debug version (default: Release)"
  echo "  --Release            Build Release version (default)"
  echo
  exit 0
}

for arg in "$@"; do
  case $arg in
    -h|--help) usage ;;
    --linux-x86_64) BUILD_LINUX_X86_64=true ;;
    --linux-aarch64) BUILD_LINUX_AARCH64=true ;;
    --macos) BUILD_MACOS=true ;;
    --ios) BUILD_IOS=true ;;
    --all-platforms)
      BUILD_ALL=true
      BUILD_LINUX_X86_64=true
      BUILD_LINUX_AARCH64=true
      BUILD_MACOS=true
      BUILD_IOS=true
      ;;
    --Debug) BUILD_MODE="Debug" ;;
    --Release) BUILD_MODE="Release" ;;
    *)
      echo -e "\033[31m[error] unknown option: ${arg}\033[0m"
      exit 1
      ;;
  esac
done

# Validate at least one platform is selected
if ! $BUILD_LINUX_X86_64 && ! $BUILD_LINUX_AARCH64 && ! $BUILD_MACOS && ! $BUILD_IOS; then
  echo -e "\033[31m[error] No platform selected. Use --help for options.\033[0m"
  exit 1
fi

echo "Building artifact bundles (${BUILD_MODE} mode)"
echo "Platforms: linux-x86_64=$BUILD_LINUX_X86_64, linux-aarch64=$BUILD_LINUX_AARCH64, macos=$BUILD_MACOS, ios=$BUILD_IOS"

# Platform configurations
# Format: "preset:output_subdir:platform_name"
declare -a PLATFORM_CONFIGS=()

if $BUILD_LINUX_X86_64; then
  PLATFORM_CONFIGS+=("linux-x86_64-swiftpm:linux-x86_64:linux-x86_64")
fi

if $BUILD_LINUX_AARCH64; then
  PLATFORM_CONFIGS+=("linux-aarch64-swiftpm:linux-aarch64:linux-aarch64")
fi

if $BUILD_MACOS; then
  PLATFORM_CONFIGS+=("macos:macos:macos-arm64")
fi

if $BUILD_IOS; then
  PLATFORM_CONFIGS+=("ios:ios:ios-arm64")
  PLATFORM_CONFIGS+=("ios-simulator:simulator:ios-arm64-simulator")
fi

# Build libraries for each platform
echo "=== Building libraries ==="

for config in "${PLATFORM_CONFIGS[@]}"; do
  IFS=':' read -r preset output_subdir platform_name <<< "$config"

  build_dir="${SWIFTPM_OUTPUT_DIR}/${output_subdir}"

  echo "Building preset ${preset} (${BUILD_MODE}) in ${build_dir}..."

  # Remove build directory if it exists (--fresh not available in CMake < 3.24)
  rm -rf "${build_dir}"

  cmake -S "${SOURCE_ROOT_DIR}" \
        -B "${build_dir}" \
        -DCMAKE_BUILD_TYPE="${BUILD_MODE}" \
        --preset "${preset}"

  cmake --build "${build_dir}" \
        --config "${BUILD_MODE}" \
        -j "$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
done

# Function to merge libraries into a single static library
merge_libraries() {
  local platform_name=$1
  local build_dir=$2
  local framework_name=$3
  local lib_list=$4
  local output_lib=$5

  echo "Merging libraries for ${framework_name} (${platform_name})"

  local lib_paths=()
  IFS=',' read -ra LIBS <<< "$lib_list"
  for lib in "${LIBS[@]}"; do
    lib_path="${build_dir}/${lib}"
    if [ ! -f "${lib_path}" ]; then
      echo "Warning: Library not found: ${lib_path}, skipping"
      continue
    fi
    lib_paths+=("${lib_path}")
  done

  if [ ${#lib_paths[@]} -eq 0 ]; then
    echo "Error: No libraries found for ${framework_name}"
    return 1
  fi

  # Use appropriate tool based on platform
  if [[ "$platform_name" == linux-* ]]; then
    # Use ar for Linux
    ar -rcs "${output_lib}" "${lib_paths[@]}"
  else
    # Use libtool for Apple platforms
    libtool -static -o "${output_lib}" "${lib_paths[@]}"
  fi
}

# Function to export headers for a framework
export_headers() {
  local framework_name=$1
  local module_name=$2
  local output_dir=$3

  echo "Exporting headers for ${framework_name}"

  mkdir -p "${output_dir}/${module_name}"

  # Use buck2 to export headers
  case $framework_name in
    executorch)
      "$SOURCE_ROOT_DIR"/scripts/print_exported_headers.py --buck2="$(realpath "$BUCK2")" --targets \
        //extension/module: \
        //extension/tensor: \
      | rsync -av --files-from=- "$SOURCE_ROOT_DIR" "${output_dir}/${module_name}"

      # Copy Apple-specific exported headers
      if [ -d "$SOURCE_ROOT_DIR/extension/apple/${module_name}/Exported" ]; then
        cp "$SOURCE_ROOT_DIR/extension/apple/${module_name}/Exported/"*.h "${output_dir}/${module_name}/"
      fi

      # HACK: Patch for c10 paths and macros (matching build_apple_frameworks.sh)
      sed -i.bak '1i\
#define C10_USING_CUSTOM_GENERATED_MACROS
' \
      "${output_dir}/executorch/runtime/core/portable_type/c10/torch/headeronly/macros/Export.h" \
      "${output_dir}/executorch/runtime/core/portable_type/c10/torch/headeronly/macros/Macros.h" 2>/dev/null || true

      rm -f "${output_dir}"/executorch/runtime/core/portable_type/c10/torch/headeronly/macros/*.bak 2>/dev/null || true

      # Copy c10 headers to top level
      if [ -d "${output_dir}/executorch/runtime/core/portable_type/c10/c10" ]; then
        cp -r "${output_dir}/executorch/runtime/core/portable_type/c10/c10" "${output_dir}/"
        cp -r "${output_dir}/executorch/runtime/core/portable_type/c10/torch" "${output_dir}/"
      fi
      ;;
    executorch_llm)
      # Copy LLM exported headers
      if [ -d "$SOURCE_ROOT_DIR/extension/llm/apple/ExecuTorchLLM/Exported" ]; then
        mkdir -p "${output_dir}/${module_name}"
        cp "$SOURCE_ROOT_DIR/extension/llm/apple/ExecuTorchLLM/Exported/"*.h "${output_dir}/${module_name}/"
      fi
      ;;
    *)
      echo "No headers to export for ${framework_name}"
      return 0
      ;;
  esac
}

# Function to create module.modulemap
create_modulemap() {
  local module_name=$1
  local output_path=$2

  cat > "${output_path}" << EOF
module ${module_name} {
  umbrella header "${module_name}/${module_name}.h"
  export *
}
EOF
}

# Create artifact bundles for each framework
echo "=== Creating artifact bundles ==="

for framework_spec in "${FRAMEWORKS[@]}"; do
  IFS=':' read -r framework_name lib_list has_headers <<< "$framework_spec"

  echo "Processing framework: ${framework_name}"

  bundle_dir="${OUTPUT_DIR}/${framework_name}.artifactbundle"
  rm -rf "${bundle_dir}"
  mkdir -p "${bundle_dir}"

  # Module name (convert to PascalCase for executorch -> ExecuTorch)
  case $framework_name in
    executorch) module_name="ExecuTorch" ;;
    executorch_llm) module_name="ExecuTorchLLM" ;;
    *) module_name="${framework_name}" ;;
  esac

  # Collect platform variants for manifest
  declare -a platforms=()
  declare -a library_paths=()
  declare -a header_paths=()
  declare -a modulemap_paths=()

  for config in "${PLATFORM_CONFIGS[@]}"; do
    IFS=':' read -r preset output_subdir platform_name <<< "$config"

    build_dir="${SWIFTPM_OUTPUT_DIR}/${output_subdir}"
    platform_dir="${bundle_dir}/${platform_name}"
    mkdir -p "${platform_dir}"

    # Merge libraries
    output_lib="${platform_dir}/lib${framework_name}.a"
    if ! merge_libraries "${platform_name}" "${build_dir}" "${framework_name}" "${lib_list}" "${output_lib}"; then
      echo "Warning: Failed to merge libraries for ${framework_name} on ${platform_name}, skipping platform"
      rm -rf "${platform_dir}"
      continue
    fi

    # Export headers if needed
    if [ "$has_headers" == "yes" ]; then
      include_dir="${platform_dir}/include"
      mkdir -p "${include_dir}"
      export_headers "${framework_name}" "${module_name}" "${include_dir}"

      # Create module.modulemap
      modulemap_file="${include_dir}/module.modulemap"
      create_modulemap "${module_name}" "${modulemap_file}"

      header_paths+=("${platform_name}/include")
      modulemap_paths+=("${platform_name}/include/module.modulemap")
    else
      header_paths+=("")
      modulemap_paths+=("")
    fi

    platforms+=("${platform_name}")
    library_paths+=("${platform_name}/lib${framework_name}.a")
  done

  # Generate info.json manifest
  if [ ${#platforms[@]} -gt 0 ]; then
    manifest_args=(
      --name "${framework_name}"
      --version "${VERSION}"
      --output "${bundle_dir}/info.json"
    )

    for i in "${!platforms[@]}"; do
      manifest_args+=(--platform "${platforms[$i]}")
      manifest_args+=(--library-path "${library_paths[$i]}")

      if [ -n "${header_paths[$i]}" ]; then
        manifest_args+=(--header-path "${header_paths[$i]}")
      fi

      if [ -n "${modulemap_paths[$i]}" ]; then
        manifest_args+=(--modulemap-path "${modulemap_paths[$i]}")
      fi
    done

    python3 "${SOURCE_ROOT_DIR}/scripts/create_artifact_bundle_manifest.py" "${manifest_args[@]}"

    echo "Created artifact bundle: ${bundle_dir}"
  else
    echo "Warning: No platforms built for ${framework_name}, removing empty bundle"
    rm -rf "${bundle_dir}"
  fi

  # Clear arrays for next framework
  unset platforms library_paths header_paths modulemap_paths
done

echo "=== Artifact bundle build complete ==="
echo "Output directory: ${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}"/*.artifactbundle 2>/dev/null || echo "No artifact bundles created"
