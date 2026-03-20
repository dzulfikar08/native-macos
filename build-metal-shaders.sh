#!/bin/bash
# Compile Metal shaders to metallib
xcrun -sdk macosx metal -c Sources/native-macos/Editing/MetalShaders.metal -o MetalShaders.air
xcrun -sdk macosx metallib MetalShaders.air -o Sources/native-macos/Editing/MetalShaders.metallib
