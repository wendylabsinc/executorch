#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

set -euo pipefail

# Validate artifact bundles for Swift Package Manager

SOURCE_ROOT_DIR=$(git rev-parse --show-toplevel)
OUTPUT_DIR="${SOURCE_ROOT_DIR}/cmake-out"

ERRORS=0

validate_bundle() {
  local bundle_path=$1
  local bundle_name=$(basename "$bundle_path" .artifactbundle)

  echo "Validating bundle: ${bundle_name}"

  # Check that info.json exists
  if [ ! -f "${bundle_path}/info.json" ]; then
    echo "  ✗ Missing info.json"
    ((ERRORS++))
    return
  fi

  # Validate JSON syntax
  if ! python3 -m json.tool "${bundle_path}/info.json" > /dev/null 2>&1; then
    echo "  ✗ Invalid JSON in info.json"
    ((ERRORS++))
    return
  fi

  echo "  ✓ info.json valid"

  # Check for platform directories and libraries
  local platform_count=0
  for platform_dir in "${bundle_path}"/*; do
    if [ -d "${platform_dir}" ] && [ "$(basename "${platform_dir}")" != "info.json" ]; then
      platform_name=$(basename "${platform_dir}")
      platform_count=$((platform_count + 1))

      # Check for static library
      local lib_found=false
      for lib in "${platform_dir}"/lib*.a; do
        if [ -f "$lib" ]; then
          lib_found=true
          lib_size=$(stat -f%z "$lib" 2>/dev/null || stat -c%s "$lib" 2>/dev/null || echo 0)
          if [ "$lib_size" -gt 0 ]; then
            echo "  ✓ ${platform_name}: $(basename "$lib") (${lib_size} bytes)"
          else
            echo "  ✗ ${platform_name}: $(basename "$lib") is empty"
            ((ERRORS++))
          fi
        fi
      done

      if ! $lib_found; then
        echo "  ✗ ${platform_name}: No static library found"
        ((ERRORS++))
      fi

      # Check for headers if include directory exists
      if [ -d "${platform_dir}/include" ]; then
        header_count=$(find "${platform_dir}/include" -name "*.h" | wc -l)
        echo "  ✓ ${platform_name}: ${header_count} headers"

        # Check for module.modulemap
        if [ -f "${platform_dir}/include/module.modulemap" ]; then
          echo "  ✓ ${platform_name}: module.modulemap found"
        else
          echo "  ⚠ ${platform_name}: module.modulemap not found"
        fi
      fi
    fi
  done

  if [ $platform_count -eq 0 ]; then
    echo "  ✗ No platform variants found"
    ((ERRORS++))
  else
    echo "  ✓ ${platform_count} platform variants"
  fi

  echo ""
}

# Find all artifact bundles
bundles=()
while IFS= read -r -d '' bundle; do
  bundles+=("$bundle")
done < <(find "${OUTPUT_DIR}" -maxdepth 1 -name "*.artifactbundle" -type d -print0)

if [ ${#bundles[@]} -eq 0 ]; then
  echo "No artifact bundles found in ${OUTPUT_DIR}"
  exit 1
fi

echo "Found ${#bundles[@]} artifact bundle(s)"
echo ""

for bundle in "${bundles[@]}"; do
  validate_bundle "$bundle"
done

if [ $ERRORS -eq 0 ]; then
  echo "✓ All artifact bundles valid"
  exit 0
else
  echo "✗ Validation failed with ${ERRORS} error(s)"
  exit 1
fi
