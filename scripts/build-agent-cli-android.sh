#!/bin/bash
# Fetch and package the Android-native opencode binary for the
# android-agent-cli-pack dependency pack.
#
# Source:  guysoft/opencode-termux v0.2.1
# Binary:  opencode v1.17.9 (Bun/JSC, Bionic-native, aarch64)
# License: MIT (opencode), MIT (Bun/JavaScriptCore runtime)
#
# The resulting pack zip is uploaded to:
#   https://github.com/vmbbz/plawie/releases/tag/dependency-packs-v1
# and referenced in android-arm64-v8a.json.
#
# This script does NOT bundle the binary in the APK — the pack is
# ~50 MB and is downloaded on demand, exactly like android-whisper-runtime
# and android-tts-runtime.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${1:-$PROJECT_DIR/build-android-agent-cli}"
PACK_DIR="$BUILD_DIR/android-agent-cli-pack"

OPENCODE_VERSION="1.17.9"
RELEASE_TAG="v0.2.1"
UPSTREAM_ZIP="opencode-${OPENCODE_VERSION}-android-aarch64.zip"
UPSTREAM_URL="https://github.com/guysoft/opencode-termux/releases/download/${RELEASE_TAG}/${UPSTREAM_ZIP}"
UPSTREAM_SHA256="0c77d4b8f286e01ba08c9e9aeca8c73a0e0c655342044ab3a59cf1953093a9b0"

PACK_ZIP="android-agent-cli-pack-opencode-v${OPENCODE_VERSION}-2026.zip"

mkdir -p "$BUILD_DIR"

echo "=== Downloading opencode ${OPENCODE_VERSION} (Android aarch64) ==="
echo "Source: $UPSTREAM_URL"
curl -L --fail --progress-bar -o "$BUILD_DIR/$UPSTREAM_ZIP" "$UPSTREAM_URL"

echo ""
echo "=== Verifying SHA256 ==="
ACTUAL_SHA=$(sha256sum "$BUILD_DIR/$UPSTREAM_ZIP" | awk '{print $1}')
if [ "$ACTUAL_SHA" != "$UPSTREAM_SHA256" ]; then
  echo "ERROR: SHA256 mismatch!"
  echo "  Expected: $UPSTREAM_SHA256"
  echo "  Actual:   $ACTUAL_SHA"
  exit 1
fi
echo "✅ SHA256 verified: $ACTUAL_SHA"

echo ""
echo "=== Extracting upstream zip ==="
rm -rf "$BUILD_DIR/extracted"
mkdir -p "$BUILD_DIR/extracted"
unzip -q "$BUILD_DIR/$UPSTREAM_ZIP" -d "$BUILD_DIR/extracted"
echo "Contents:"
ls -lh "$BUILD_DIR/extracted/"

echo ""
echo "=== Packaging dependency pack ==="
# Pack structure mirrors other packs:
#   bin/coding-agent       — the ELF binary (named for OpenClaw's skill gate)
#   lib/libc++_shared.so   — LLVM C++ runtime (required by opencode.bin)
#   lib/libopentui.so      — OpenTUI terminal rendering library
#   lib/libtagfix.so       — Android 11+ MTE pointer-tagging fix preload
#   bin/opencode-launcher.sh — original upstream launcher script (reference)
rm -rf "$PACK_DIR"
mkdir -p "$PACK_DIR/bin" "$PACK_DIR/lib"

cp "$BUILD_DIR/extracted/opencode.bin"       "$PACK_DIR/bin/coding-agent"
cp "$BUILD_DIR/extracted/opencode"           "$PACK_DIR/bin/opencode-launcher.sh"
cp "$BUILD_DIR/extracted/libc++_shared.so"   "$PACK_DIR/lib/libc++_shared.so"
cp "$BUILD_DIR/extracted/libopentui.so"      "$PACK_DIR/lib/libopentui.so"
cp "$BUILD_DIR/extracted/libtagfix.so"       "$PACK_DIR/lib/libtagfix.so"

echo ""
echo "=== Verifying ELF architecture ==="
BIN="$PACK_DIR/bin/coding-agent"
# Byte 18 of an ELF header is e_machine: 0xB7 = EM_AARCH64
EMACHINE=$(xxd -p -l 1 -s 18 "$BIN")
if [ "$EMACHINE" = "b7" ]; then
  echo "✅ aarch64 ELF confirmed (e_machine=0xB7)"
else
  echo "WARNING: Unexpected e_machine byte: 0x$EMACHINE (expected 0xB7 for aarch64)"
fi

echo ""
echo "=== Creating pack zip: $PACK_ZIP ==="
cd "$PACK_DIR"
zip -r -9 "$BUILD_DIR/$PACK_ZIP" bin/ lib/
cd "$BUILD_DIR"

PACK_SIZE=$(du -sh "$PACK_ZIP" | cut -f1)
PACK_SHA=$(sha256sum "$PACK_ZIP" | awk '{print $1}')
echo ""
echo "=== Pack complete ==="
echo "  File:   $BUILD_DIR/$PACK_ZIP"
echo "  Size:   $PACK_SIZE"
echo "  SHA256: $PACK_SHA"
echo ""
echo "=== Next steps ==="
echo "1. Upload to GitHub release:"
echo "   gh release upload dependency-packs-v1 '$BUILD_DIR/$PACK_ZIP' \\"
echo "     --repo vmbbz/plawie --clobber"
echo ""
echo "2. Sign the pack (requires \$TEMP/opencode/signing-private.pem):"
echo "   openssl pkeyutl -sign -inkey \$TEMP/opencode/signing-private.pem \\"
echo "     -rawin -in <(sha256sum '$BUILD_DIR/$PACK_ZIP' | awk '{print \$1}') \\"
echo "     | base64 -w0"
echo ""
echo "3. Update android-arm64-v8a.json:"
echo "   - sizeBytes: \$(stat -c%s '$BUILD_DIR/$PACK_ZIP')"
echo "   - sha256: $PACK_SHA"
echo "   - signature.value: <base64 from step 2>"
echo "   - Update file-level sha256 values for bin/coding-agent and lib/*.so"
