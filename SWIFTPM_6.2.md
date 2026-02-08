# Swift Package Manager 6.2+ Cross-Platform Support

This document describes the cross-platform support for ExecuTorch using Swift Package Manager 6.2+ with artifact bundles.

## Overview

Swift 6.2 introduces [SE-0482](https://github.com/apple/swift-evolution/blob/main/proposals/0482-swiftpm-binary-artifact-bundles.md), which enables static library binary targets on non-Apple platforms (Linux, Windows) through artifact bundles. This implementation extends ExecuTorch's Swift package to support:

- **Linux x86_64**
- **Linux ARM64** (aarch64)
- **macOS ARM64**
- **iOS ARM64** (device + simulator)

## Architecture

### Artifact Bundle Format

Each framework is packaged as an artifact bundle with platform-specific variants:

```
executorch.artifactbundle/
├── info.json                    # Manifest describing variants
├── linux-x86_64/
│   ├── libexecutorch.a         # Static library
│   └── include/                 # Headers (if applicable)
│       ├── ExecuTorch/
│       └── module.modulemap
├── linux-aarch64/
│   └── ...
├── macos-arm64/
│   └── ...
└── ios-arm64/
    └── ...
```

### Package Manifests

Two package manifests coexist:

1. **Package.swift** (Swift 5.9+)
   - Apple platforms only (iOS, macOS)
   - Uses xcframework format
   - Maintained for backwards compatibility

2. **Package@swift-6.2.swift** (Swift 6.2+)
   - Cross-platform (Linux, macOS, iOS)
   - Uses artifact bundle format
   - Automatically selected by Swift 6.2+ users

## Building Artifact Bundles

### Prerequisites

- CMake 3.19+
- Swift 6.2+ (for testing)
- Buck2 (for header export)
- Platform-specific toolchains:
  - **Linux**: GCC or Clang
  - **macOS**: Xcode Command Line Tools
  - **Linux ARM64**: Cross-compilation toolchain or native ARM64 host

### Build Commands

Build artifact bundles for specific platforms:

```bash
# Linux x86_64 only
./scripts/build_artifact_bundles.sh --linux-x86_64

# Linux ARM64 only
./scripts/build_artifact_bundles.sh --linux-aarch64

# macOS only
./scripts/build_artifact_bundles.sh --macos

# iOS (device + simulator)
./scripts/build_artifact_bundles.sh --ios

# All platforms
./scripts/build_artifact_bundles.sh --all-platforms

# Debug build
./scripts/build_artifact_bundles.sh --linux-x86_64 --Debug
```

### Build Process

The `build_artifact_bundles.sh` script:

1. **Configures CMake** for each platform using presets:
   - `linux-x86_64-swiftpm`
   - `linux-aarch64-swiftpm`
   - `macos`
   - `ios` / `ios-simulator`

2. **Builds static libraries** with appropriate backends and kernels:
   - XNNPACK backend
   - Optimized kernels
   - Quantized kernels
   - LLM kernels

3. **Merges component libraries** into single framework libraries:
   - Uses `ar` for Linux
   - Uses `libtool` for Apple platforms

4. **Exports headers** (for frameworks with public APIs):
   - Uses `print_exported_headers.py` with Buck2
   - Generates `module.modulemap`

5. **Creates artifact bundle structure** with platform variants

6. **Generates info.json manifest** using `create_artifact_bundle_manifest.py`

### Validation

Validate artifact bundles after building:

```bash
./scripts/validate_artifact_bundles.sh
```

This checks:
- `info.json` exists and has valid JSON
- Platform directories exist
- Static libraries are non-empty
- Headers are present (if applicable)
- Module maps are present (if applicable)

## Using the Package

### Swift 6.2+ Local Development

```swift
// Package.swift
dependencies: [
    .package(path: "/path/to/executorch"),
]
```

Swift 6.2+ automatically selects `Package@swift-6.2.swift`.

### Swift 6.2+ Remote (Future)

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/pytorch/executorch",
        branch: "swiftpm-6.2-1.2.0.YYYYMMDD"
    ),
]
```

### Platform-Specific Code

```swift
import ExecuTorch

#if os(Linux)
// Linux-specific code
#elseif os(macOS)
// macOS-specific code
#elseif os(iOS)
// iOS-specific code
#endif
```

## Supported Frameworks

### Cross-Platform (Linux, macOS, iOS)

- ✅ `executorch` - Core runtime
- ✅ `threadpool` - Thread pool extension
- ✅ `executorch_llm` - LLM runner
- ✅ `backend_xnnpack` - XNNPACK backend
- ✅ `kernels_optimized` - Optimized kernels
- ✅ `kernels_quantized` - Quantized kernels
- ✅ `kernels_llm` - LLM custom kernels
- ✅ `kernels_torchao` - TorchAO kernels

### Apple-Only

These frameworks remain Apple-only due to platform dependencies:

- `backend_coreml` - CoreML backend (requires CoreML framework)
- `backend_mps` - Metal Performance Shaders backend (requires Metal)

## CMake Presets

### Linux x86_64 SwiftPM

```json
{
  "name": "linux-x86_64-swiftpm",
  "binaryDir": "${sourceDir}/cmake-out/swiftpm/linux-x86_64",
  "cacheVariables": {
    "CMAKE_SYSTEM_NAME": "Linux",
    "CMAKE_SYSTEM_PROCESSOR": "x86_64",
    "EXECUTORCH_BUILD_XNNPACK": "ON",
    "EXECUTORCH_BUILD_KERNELS_OPTIMIZED": "ON",
    "EXECUTORCH_BUILD_KERNELS_QUANTIZED": "ON",
    "EXECUTORCH_BUILD_KERNELS_LLM": "ON"
  }
}
```

### Linux ARM64 SwiftPM

```json
{
  "name": "linux-aarch64-swiftpm",
  "binaryDir": "${sourceDir}/cmake-out/swiftpm/linux-aarch64",
  "cacheVariables": {
    "CMAKE_SYSTEM_NAME": "Linux",
    "CMAKE_SYSTEM_PROCESSOR": "aarch64",
    "EXECUTORCH_BUILD_XNNPACK": "ON",
    "EXECUTORCH_BUILD_KERNELS_OPTIMIZED": "ON",
    "EXECUTORCH_BUILD_KERNELS_QUANTIZED": "ON",
    "EXECUTORCH_BUILD_KERNELS_LLM": "ON"
  }
}
```

## Testing

### Docker Testing (Linux x86_64)

```bash
docker run --rm -v $PWD:/workspace swift:6.2-jammy bash -c "
  cd /workspace && \
  ./scripts/build_artifact_bundles.sh --linux-x86_64 && \
  ./scripts/validate_artifact_bundles.sh
"
```

### Local Testing (macOS)

```bash
./scripts/build_artifact_bundles.sh --macos
./scripts/validate_artifact_bundles.sh
swift build  # Uses Package@swift-6.2.swift automatically
```

## Dependencies

### Cross-Platform Dependencies

All frameworks link against:
- `libc++` (C++ standard library)
- `pthread` (Linux only, for threading)

No other external runtime dependencies are required.

### System Requirements

- **Linux**: glibc 2.27+ (Ubuntu 18.04+, Debian 10+, CentOS 8+)
- **macOS**: macOS 12.0+
- **iOS**: iOS 17.0+

## Troubleshooting

### Build Errors

**Issue**: `cmake: command not found`
**Solution**: Install CMake 3.19 or later

**Issue**: `buck2: command not found`
**Solution**: Buck2 will be automatically downloaded to `buck2-bin/` on first run

**Issue**: `ar: command not found` (Linux)
**Solution**: Install `binutils` package

### Validation Errors

**Issue**: Empty static libraries
**Solution**: Check that all component libraries were built successfully

**Issue**: Missing headers
**Solution**: Verify Buck2 can query the target successfully

## Implementation Status

### Completed

- ✅ CMake presets for Linux x86_64 and ARM64
- ✅ Artifact bundle build script (`build_artifact_bundles.sh`)
- ✅ Manifest generator (`create_artifact_bundle_manifest.py`)
- ✅ Package@swift-6.2.swift manifest
- ✅ Validation script (`validate_artifact_bundles.sh`)
- ✅ Core `executorch` framework support

### In Progress

- 🚧 Expand to all frameworks (threadpool, backends, kernels)
- 🚧 CI/CD integration
- 🚧 Testing on actual Linux hardware

### Planned

- 📋 CUDA backend support (Phase 3)
- 📋 Windows support (Phase 3)
- 📋 Release automation for swiftpm-6.2-* branches

## Contributing

When adding new frameworks or platforms:

1. Update `FRAMEWORKS` array in `build_artifact_bundles.sh`
2. Update `products` dictionary in `Package@swift-6.2.swift`
3. Add platform-specific linker settings if needed
4. Test on target platform
5. Update this documentation

## References

- [SE-0482: SwiftPM Binary Artifact Bundles](https://github.com/apple/swift-evolution/blob/main/proposals/0482-swiftpm-binary-artifact-bundles.md)
- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [ExecuTorch Documentation](https://pytorch.org/executorch/)
