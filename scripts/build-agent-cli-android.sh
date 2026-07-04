#!/bin/bash
# Cross-compile a minimal coding-agent CLI for Android arm64-v8a.
# This binary satisfies the android-agent-cli-pack smoke test.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ASSET_DIR="$PROJECT_DIR/assets/openclaw/agent-cli-pack/bin"
OUTPUT_DIR="${1:-$PROJECT_DIR/build-android-agent-cli}"

# NDK paths
ANDROID_HOME="${ANDROID_HOME:-$HOME/AppData/Local/Android/Sdk}"
NDK_DIR="$ANDROID_HOME/ndk/29.0.14206865"
TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/windows-x86_64"
API=28
CC="$TOOLCHAIN/aarch64-linux-android${API}-clang.cmd"

mkdir -p "$OUTPUT_DIR"

# Write minimal C source
cat > "$OUTPUT_DIR/coding_agent.c" << 'EOF'
#include <stdio.h>
#include <string.h>

static const char *VERSION = "coding-agent 0.1.0-android-stub";
static const char *HELP =
    "coding-agent - Android agent CLI (STUB)\n"
    "\n"
    "Usage: coding-agent [OPTIONS]\n"
    "\n"
    "Options:\n"
    "  --version   Print version\n"
    "  --help      Show this help\n"
    "\n"
    "IMPORTANT: This is a STUB binary for smoke testing only.\n"
    "Full agent CLI functionality requires:\n"
    "  1. A supported backend (Claude, OpenAI, etc.)\n"
    "  2. API key configuration\n"
    "  3. Network access to the backend\n"
    "\n"
    "To use the coding-agent skill, configure it in the app settings\n"
    "with your API credentials.\n";

int main(int argc, char **argv) {
    if (argc > 1) {
        if (strcmp(argv[1], "--version") == 0 || strcmp(argv[1], "-v") == 0) {
            printf("%s\n", VERSION);
            return 0;
        }
        if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
            printf("%s", HELP);
            return 0;
        }
        if (strcmp(argv[1], "--stub") == 0) {
            printf("This is a stub binary. Configure a real backend to use coding-agent.\n");
            return 0;
        }
        fprintf(stderr, "coding-agent stub: Unknown option: %s\n", argv[1]);
        fprintf(stderr, "This is a stub binary. Configure a real backend to use coding-agent.\n");
        return 1;
    }
    printf("%s\n", VERSION);
    return 0;
}
EOF

echo "Compiling coding-agent for android-arm64-v8a..."
"$CC" -o "$OUTPUT_DIR/coding-agent" "$OUTPUT_DIR/coding_agent.c" \
    -static -O2 -Wall -Wextra

echo "Verifying binary..."
file "$OUTPUT_DIR/coding-agent"
"$OUTPUT_DIR/coding-agent" --version

echo ""
echo "Copying to assets..."
mkdir -p "$ASSET_DIR"
cp "$OUTPUT_DIR/coding-agent" "$ASSET_DIR/coding-agent"
echo "Done: $ASSET_DIR/coding-agent"
