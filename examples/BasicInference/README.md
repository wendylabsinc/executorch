# Basic Inference Example

This example demonstrates cross-platform ExecuTorch usage with Swift Package Manager 6.2.

## Prerequisites

**Note**: This example uses Package@swift-6.2.swift which requires pre-built artifact bundles. Building these bundles is currently complex and requires Buck2.

For a simpler alternative for local testing, see "Alternative: Testing Without Artifact Bundles" below.

### For Artifact Bundle Testing

1. **Swift 6.2+** installed
2. **Buck2 build system** configured
3. **Build artifact bundles** for your platform:

```bash
# From executorch root directory
cd ../..

# For Linux x86_64
./scripts/build_artifact_bundles.sh --linux-x86_64

# For Linux ARM64
./scripts/build_artifact_bundles.sh --linux-aarch64

# For macOS (requires Buck2 setup)
./scripts/build_artifact_bundles.sh --macos
```

## Running the Example

### macOS / Linux

```bash
cd Examples/BasicInference
swift run
```

### With Docker (Linux)

```bash
docker run --rm -v $PWD:/workspace -w /workspace swift:6.2-jammy bash -c "
  apt-get update && apt-get install -y libstdc++-11-dev
  cd Examples/BasicInference
  swift run
"
```

## Expected Output

```
=== ExecuTorch Basic Inference Example ===
Platform: [Linux/macOS/iOS]

ExecuTorch cross-platform example
----------------------------------
✓ ExecuTorch framework imported successfully
✓ Cross-platform support working!
ℹ️  No model.pte found - this is just a framework test
  To test with a real model:
  1. Export a PyTorch model: python -m executorch.exir.export ...
  2. Place model.pte in this directory
  3. Run again

Example complete! ✓
```

## Using with a Real Model

To run inference with an actual model:

1. **Export a PyTorch model to .pte format:**

```python
import torch
from torch.export import export
from executorch.exir import to_edge

# Your model
model = YourModel()
example_inputs = (torch.randn(1, 3, 224, 224),)

# Export to ExecuTorch
aten_dialect = export(model, example_inputs)
edge_program = to_edge(aten_dialect)
executorch_program = edge_program.to_executorch()

# Save
with open("model.pte", "wb") as f:
    f.write(executorch_program.buffer)
```

2. **Place model.pte in the BasicInference directory**

3. **Uncomment the inference code in Sources/main.swift:**

```swift
let module = try Module(filePath: modelPath)
let result = try module.forward(inputs: [inputTensor])
print("Inference result: \(result)")
```

4. **Run again:**

```bash
swift run
```

## Alternative: Testing Without Artifact Bundles

For local development and testing without building artifact bundles, you can temporarily modify the Package.swift to use the source-based implementation:

1. **Check your Swift version**:

```bash
swift --version
# If you have Swift 5.9-6.1, the Package.swift will be used automatically
# If you have Swift 6.2+, you'll need to temporarily rename Package@swift-6.2.swift
```

2. **Temporarily disable Swift 6.2 manifest** (if using Swift 6.2+):

```bash
cd ../..
mv Package@swift-6.2.swift Package@swift-6.2.swift.bak
```

3. **Build and run**:

```bash
cd Examples/BasicInference
swift run
```

4. **Restore Swift 6.2 manifest when done**:

```bash
cd ../..
mv Package@swift-6.2.swift.bak Package@swift-6.2.swift
```

**Note**: This approach builds ExecuTorch from source using CMake, which works on macOS but requires xcframeworks to exist. For the simplest test, use this approach to verify the example code structure.

## Platform Support

- ✅ Linux x86_64
- ✅ Linux ARM64
- ✅ macOS ARM64
- ✅ iOS 17+ (in iOS app context)

## Troubleshooting

**"Module 'ExecuTorch' not found"**
- Build the artifact bundles first (see Prerequisites)
- Make sure you're using Swift 6.2+

**Linker errors**
- Ensure all required frameworks are built
- Check that artifact bundles exist in `../../cmake-out/`

## Next Steps

- See `Examples/LLMRunner` for LLM-specific example
- Check the main documentation: `../../SWIFTPM_6.2.md`
