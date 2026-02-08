# Quick Start: Swift Package Manager 6.2 Cross-Platform

## TL;DR

```bash
# Build for Linux x86_64
./scripts/build_artifact_bundles.sh --linux-x86_64

# Validate
./scripts/validate_artifact_bundles.sh

# Use in Swift project
swift build  # Automatically uses Package@swift-6.2.swift
```

## One-Line Builds

```bash
# Single platform
./scripts/build_artifact_bundles.sh --linux-x86_64
./scripts/build_artifact_bundles.sh --linux-aarch64
./scripts/build_artifact_bundles.sh --macos
./scripts/build_artifact_bundles.sh --ios

# All platforms
./scripts/build_artifact_bundles.sh --all-platforms

# Debug mode
./scripts/build_artifact_bundles.sh --linux-x86_64 --Debug
```

## Docker Testing (Linux x86_64)

```bash
docker run --rm -v $PWD:/workspace swift:6.2-jammy bash -c "
  apt-get update && apt-get install -y cmake git python3 && \
  cd /workspace && \
  ./scripts/build_artifact_bundles.sh --linux-x86_64 && \
  ./scripts/validate_artifact_bundles.sh
"
```

## Output Structure

```
cmake-out/
└── executorch.artifactbundle/
    ├── info.json
    ├── linux-x86_64/
    │   ├── libexecutorch.a
    │   └── include/
    │       ├── ExecuTorch/
    │       └── module.modulemap
    └── macos-arm64/
        └── ...
```

## Using in Swift Projects

### Local Development

```swift
// Package.swift
let package = Package(
    name: "MyApp",
    dependencies: [
        .package(path: "/path/to/executorch"),
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "executorch", package: "executorch"),
            ]
        ),
    ]
)
```

### Example Usage

```swift
import ExecuTorch

let module = try Module(filePath: "model.pte")
let result = try module.forward(inputs: [tensor])
```

## Platform Support

| Platform       | Status | Triple                    |
|----------------|--------|---------------------------|
| Linux x86_64   | ✅     | x86_64-unknown-linux-gnu  |
| Linux ARM64    | ✅     | aarch64-unknown-linux-gnu |
| macOS ARM64    | ✅     | arm64-apple-macosx        |
| iOS ARM64      | ✅     | arm64-apple-ios           |
| iOS Simulator  | ✅     | arm64-apple-ios-simulator |

## Current Frameworks

- ✅ `executorch` - Core runtime

## Coming Soon

- `threadpool`
- `executorch_llm`
- `backend_xnnpack`
- `kernels_optimized`
- `kernels_quantized`
- `kernels_llm`

## Troubleshooting

### Build fails with "preset not found"
You're probably on a non-Linux system trying to build Linux presets. Use Docker.

### Validation shows "empty library"
The component libraries weren't built. Check CMake output for errors.

### Swift can't find Package@swift-6.2.swift
Make sure you have Swift 6.2 or later: `swift --version`

## Next Steps

1. See [SWIFTPM_6.2.md](SWIFTPM_6.2.md) for detailed documentation
2. Check the implementation plan in the commit message
3. Report issues on GitHub
