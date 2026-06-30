#!/usr/bin/env bash
set -euo pipefail
# Build sherpa-onnx for Android arm64-v8a
# Prerequisites: Android NDK (set ANDROID_NDK_HOME)

NDK="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/27.0.12077973}"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
API_LEVEL=26
BIN_OUT="$(dirname "$0")/../assets/openclaw/tts-runtime/bin"
LIB_OUT="$(dirname "$0")/../assets/openclaw/tts-runtime/lib"

if [ ! -d "$NDK" ]; then
  echo "Error: Android NDK not found at $NDK"
  echo "Set ANDROID_NDK_HOME or install NDK 27+"
  exit 1
fi

BUILD_DIR=$(mktemp -d)
trap "rm -rf $BUILD_DIR" EXIT

echo "Cloning sherpa-onnx..."
git clone --depth=1 https://github.com/k2-fsa/sherpa-onnx "$BUILD_DIR/sherpa-onnx"

echo "Building for arm64-v8a (API $API_LEVEL)..."
cd "$BUILD_DIR/sherpa-onnx"
mkdir -p build && cd build

cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-$API_LEVEL \
  -DCMAKE_BUILD_TYPE=Release \
  -DSHERPA_ONNX_ENABLE_TTS=ON \
  -DSHERPA_ONNX_ENABLE_ASR=OFF \
  -DBUILD_PYTHON=OFF \
  -DBUILD_TESTING=OFF

cmake --build . --config Release -j$(nproc)

echo "Copying binary + libs to assets..."
mkdir -p "$BIN_OUT" "$LIB_OUT"

# Main TTS binary
find . -name "sherpa-onnx" -type f -executable | while read f; do
  cp "$f" "$BIN_OUT/sherpa-onnx"
  chmod 755 "$BIN_OUT/sherpa-onnx"
done

# Shared libraries
find . -name "*.so" | while read f; do
  basename=$(basename "$f")
  cp "$f" "$LIB_OUT/$basename"
  chmod 644 "$LIB_OUT/$basename"
done

echo "Done. Files in assets/openclaw/tts-runtime/"
ls -lh "$BIN_OUT" "$LIB_OUT"

echo ""
echo "NOTE: Download TTS model files separately:"
echo "  https://github.com/k2-fsa/sherpa-onnx/releases"
echo "  Place them in assets/openclaw/tts-runtime/models/"
echo "  Update kotlin extraction and dart provisioning if models are bundled."
