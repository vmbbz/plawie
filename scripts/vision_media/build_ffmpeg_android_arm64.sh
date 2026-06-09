#!/usr/bin/env bash
set -euo pipefail

# Builds a minimal LGPL-only Android arm64 FFmpeg executable for video-frame
# extraction. This helper is intentionally source-based and hash-pinned; it does
# not install the payload into the APK unless INSTALL_ASSET=1 is set.

FFMPEG_VERSION="${FFMPEG_VERSION:-8.1.1}"
FFMPEG_SOURCE_ARCHIVE="${FFMPEG_SOURCE_ARCHIVE:-ffmpeg-8.1.1.tar.xz}"
FFMPEG_SOURCE_SHA256="${FFMPEG_SOURCE_SHA256:-b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3}"
ANDROID_API="${ANDROID_API:-29}"
JOBS="${JOBS:-4}"
ALLOW_NETWORK="${PLAWIE_ALLOW_NETWORK:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORK_ROOT="${WORK_ROOT:-${REPO_ROOT}/.tmp/vision-media/ffmpeg-android-arm64}"
SOURCE_URL="https://ffmpeg.org/releases/${FFMPEG_SOURCE_ARCHIVE}"
SOURCE_TARBALL="${WORK_ROOT}/sources/${FFMPEG_SOURCE_ARCHIVE}"
SOURCE_DIR="${WORK_ROOT}/sources/ffmpeg-${FFMPEG_VERSION}"
BUILD_DIR="${WORK_ROOT}/build"
OUTPUT_DIR="${WORK_ROOT}/out"
OUTPUT_BINARY="${OUTPUT_DIR}/ffmpeg"
ASSET_BINARY="${REPO_ROOT}/assets/openclaw/vision-media/bin/ffmpeg"

ANDROID_NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [[ -z "${ANDROID_NDK_PATH}" && -d "${HOME}/.plawie/android/android-ndk-r28c" ]]; then
  ANDROID_NDK_PATH="${HOME}/.plawie/android/android-ndk-r28c"
fi

require_network() {
  if [[ "${ALLOW_NETWORK}" != "1" ]]; then
    cat >&2 <<EOF
Refusing network download.

This helper may download FFmpeg source from:
  ${SOURCE_URL}

Set PLAWIE_ALLOW_NETWORK=1 only after confirming data/disk budget.
EOF
    exit 3
  fi
}

if [[ -z "${ANDROID_NDK_PATH}" ]]; then
  cat >&2 <<'EOF'
ANDROID_NDK_HOME or ANDROID_NDK_ROOT must point to a Linux-host Android NDK.

If only a Windows-host NDK is installed, prepare a local Linux NDK from WSL:
  PLAWIE_ALLOW_NETWORK=1 ./scripts/native_node/prepare_android_ndk_linux.sh
  export ANDROID_NDK_HOME="$HOME/.plawie/android/android-ndk-r28c"
EOF
  exit 2
fi

TOOLCHAIN_BIN="${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"
CC="${TOOLCHAIN_BIN}/aarch64-linux-android${ANDROID_API}-clang"
CXX="${TOOLCHAIN_BIN}/aarch64-linux-android${ANDROID_API}-clang++"
AR="${TOOLCHAIN_BIN}/llvm-ar"
NM="${TOOLCHAIN_BIN}/llvm-nm"
RANLIB="${TOOLCHAIN_BIN}/llvm-ranlib"
STRIP="${TOOLCHAIN_BIN}/llvm-strip"
PKG_CONFIG_BIN="${PKG_CONFIG_BIN:-/usr/bin/false}"

for tool in curl make tar sha256sum python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 2
  fi
done
for tool in "${CC}" "${CXX}" "${AR}" "${NM}" "${RANLIB}" "${STRIP}"; do
  if [[ ! -x "${tool}" ]]; then
    echo "Missing Android toolchain executable: ${tool}" >&2
    exit 2
  fi
done
if [[ -z "${PKG_CONFIG_BIN}" || ! -x "${PKG_CONFIG_BIN}" ]]; then
  echo "Missing false command for disabling pkg-config." >&2
  exit 2
fi

mkdir -p "$(dirname "${SOURCE_TARBALL}")" "${BUILD_DIR}" "${OUTPUT_DIR}"

if [[ ! -f "${SOURCE_TARBALL}" ]]; then
  require_network
  echo "[vision-media] Downloading ${SOURCE_URL}"
  curl --fail --location --output "${SOURCE_TARBALL}" "${SOURCE_URL}"
else
  echo "[vision-media] Reusing ${SOURCE_TARBALL}"
fi

echo "${FFMPEG_SOURCE_SHA256}  ${SOURCE_TARBALL}" | sha256sum -c -

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "[vision-media] Extracting FFmpeg ${FFMPEG_VERSION}"
  tar -xJf "${SOURCE_TARBALL}" -C "$(dirname "${SOURCE_DIR}")"
else
  echo "[vision-media] Reusing extracted source ${SOURCE_DIR}"
fi

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
pushd "${BUILD_DIR}" >/dev/null

"${SOURCE_DIR}/configure" \
  --prefix="${OUTPUT_DIR}/install" \
  --target-os=android \
  --arch=aarch64 \
  --cpu=armv8-a \
  --enable-cross-compile \
  --cc="${CC}" \
  --cxx="${CXX}" \
  --ar="${AR}" \
  --nm="${NM}" \
  --ranlib="${RANLIB}" \
  --strip="${STRIP}" \
  --pkg-config="${PKG_CONFIG_BIN}" \
  --disable-autodetect \
  --disable-gpl \
  --disable-nonfree \
  --disable-iconv \
  --disable-doc \
  --disable-debug \
  --disable-ffplay \
  --disable-ffprobe \
  --disable-network \
  --disable-everything \
  --enable-avcodec \
  --enable-avformat \
  --enable-avfilter \
  --enable-swscale \
  --enable-swresample \
  --enable-ffmpeg \
  --enable-protocol=file \
  --enable-demuxer=mov \
  --enable-demuxer=matroska \
  --enable-demuxer=avi \
  --enable-muxer=image2 \
  --enable-decoder=h264 \
  --enable-decoder=hevc \
  --enable-decoder=mpeg4 \
  --enable-decoder=mjpeg \
  --enable-parser=h264 \
  --enable-parser=hevc \
  --enable-parser=mpeg4video \
  --enable-parser=mjpeg \
  --enable-encoder=mjpeg \
  --enable-filter=fps \
  --enable-filter=scale \
  --enable-filter=format \
  --enable-small

make -j"${JOBS}" ffmpeg
cp ffmpeg "${OUTPUT_BINARY}"
"${STRIP}" "${OUTPUT_BINARY}" || true
chmod +x "${OUTPUT_BINARY}"
popd >/dev/null

python3 - "${OUTPUT_BINARY}" <<'PY'
import pathlib
import struct
import sys

payload = pathlib.Path(sys.argv[1])
data = payload.read_bytes()
if len(data) < 1024 * 1024:
    raise SystemExit(f"FFmpeg payload unexpectedly small: {len(data)} bytes")
if data[:4] != b"\x7fELF":
    raise SystemExit("FFmpeg payload is not an ELF executable")
if data[4] != 2 or data[5] != 1:
    raise SystemExit("FFmpeg payload is not ELF64 little-endian")
machine = struct.unpack_from("<H", data, 18)[0]
if machine != 183:
    raise SystemExit(f"FFmpeg payload is not AArch64. ELF machine={machine}")
PY

payload_sha="$(sha256sum "${OUTPUT_BINARY}" | cut -d ' ' -f 1)"

if [[ "${INSTALL_ASSET:-0}" == "1" ]]; then
  mkdir -p "$(dirname "${ASSET_BINARY}")"
  cp "${OUTPUT_BINARY}" "${ASSET_BINARY}"
  chmod +x "${ASSET_BINARY}"
fi

cat <<EOF
{
  "source": "${SOURCE_URL}",
  "sourceSha256": "${FFMPEG_SOURCE_SHA256}",
  "ffmpegVersion": "${FFMPEG_VERSION}",
  "androidNdk": "${ANDROID_NDK_PATH}",
  "androidApi": "${ANDROID_API}",
  "target": "aarch64-linux-android",
  "licenseMode": "LGPL-only",
  "output": "${OUTPUT_BINARY}",
  "outputBytes": $(wc -c < "${OUTPUT_BINARY}" | tr -d ' '),
  "outputSha256": "${payload_sha}",
  "installedAsset": $([[ "${INSTALL_ASSET:-0}" == "1" ]] && echo true || echo false)
}
EOF
