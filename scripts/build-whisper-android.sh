#!/usr/bin/env bash
set -euo pipefail
# Build whisper.cpp for Android arm64-v8a
# Prerequisites: Android NDK (set ANDROID_NDK_HOME)

NDK="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/27.0.12077973}"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
API_LEVEL=26
OUTPUT_DIR="$(dirname "$0")/../assets/openclaw/whisper-runtime/bin"

if [ ! -d "$NDK" ]; then
  echo "Error: Android NDK not found at $NDK"
  echo "Set ANDROID_NDK_HOME or install NDK 27+"
  exit 1
fi

BUILD_DIR=$(mktemp -d)
trap "rm -rf $BUILD_DIR" EXIT

echo "Cloning whisper.cpp..."
git clone --depth=1 https://github.com/ggerganov/whisper.cpp "$BUILD_DIR/whisper.cpp"

echo "Building for arm64-v8a (API $API_LEVEL)..."
cd "$BUILD_DIR/whisper.cpp"
mkdir -p build && cd build

cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-$API_LEVEL \
  -DCMAKE_BUILD_TYPE=Release \
  -DWHISPER_NO_AVX=ON \
  -DWHISPER_NO_AVX2=ON \
  -DWHISPER_NO_FMA=ON \
  -DWHISPER_NO_F16C=ON \
  -DWHISPER_NO_COREML=ON \
  -DWHISPER_CUBLAS=OFF \
  -DWHISPER_METAL=OFF \
  -DBUILD_SHARED_LIBS=OFF

cmake --build . --config Release -j$(nproc)

echo "Copying binary to assets..."
mkdir -p "$OUTPUT_DIR"
cp bin/main "$OUTPUT_DIR/whisper"
chmod 755 "$OUTPUT_DIR/whisper"
file "$OUTPUT_DIR/whisper"

echo "Downloading base model (150MB)..."
MODELS_DIR="$(dirname "$0")/../assets/openclaw/whisper-runtime/models"
mkdir -p "$MODELS_DIR"
if [ ! -f "$MODELS_DIR/ggml-base.bin" ]; then
  curl -L -o "$MODELS_DIR/ggml-base.bin" \
    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
fi

echo "Done. Binary + model ready in assets/openclaw/whisper-runtime/"
echo "Binary size: $(du -h "$OUTPUT_DIR/whisper" | cut -f1)"
echo "Model size:  $(du -h "$MODELS_DIR/ggml-base.bin" | cut -f1)"
