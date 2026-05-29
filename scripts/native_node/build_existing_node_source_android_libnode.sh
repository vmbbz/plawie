#!/usr/bin/env bash
set -euo pipefail

# Offline-only builder for an already-extracted Node source tree.
# It uses local Node source + local Linux-host Android NDK and refuses to
# download, clone, or fetch anything.

SOURCE_DIR="${SOURCE_DIR:-/home/cosyc/plawie-native-node-build/v22.22.3-arm64/node-v22.22.3}"
ANDROID_NDK_PATH="${ANDROID_NDK_HOME:-/home/cosyc/.plawie/android/android-ndk-r28c}"
ANDROID_SDK_VERSION="${ANDROID_SDK_VERSION:-29}"
TARGET_ARCH="${TARGET_ARCH:-arm64}"
INTL_MODE="${INTL_MODE:-small-icu}"
JOBS="${JOBS:-4}"
OUTPUT_DIR="${OUTPUT_DIR:-/home/cosyc/plawie-native-node-build/v22.22.3-arm64/output}"
BUILD_LOG="${OUTPUT_DIR}/offline-libnode-build.log"
FORCE_CONFIGURE="${FORCE_CONFIGURE:-0}"
FORCE_REBUILD="${FORCE_REBUILD:-0}"

for tool in gcc g++ grep make perl sed sha256sum; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required local tool: ${tool}" >&2
    exit 2
  fi
done

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Missing local Node source tree: ${SOURCE_DIR}" >&2
  exit 2
fi

toolchain="${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64"
target_cxx="${toolchain}/bin/aarch64-linux-android${ANDROID_SDK_VERSION}-clang++"
if [[ ! -x "${target_cxx}" ]]; then
  echo "Missing local Linux-host Android NDK compiler: ${target_cxx}" >&2
  exit 2
fi

case "${TARGET_ARCH}" in
  arm64|aarch64) ;;
  *)
    echo "This script is scoped to Android arm64. Got ${TARGET_ARCH}" >&2
    exit 2
    ;;
esac

case "${INTL_MODE}" in
  small-icu|full-icu|none) ;;
  *)
    echo "INTL_MODE must be small-icu, full-icu, or none. Got ${INTL_MODE}" >&2
    exit 2
    ;;
esac

mkdir -p "${OUTPUT_DIR}"
cd "${SOURCE_DIR}"

find_built_libnode() {
  local roots=()
  local root
  for root in out/Release/lib.target out/Release/obj.target out/Release; do
    if [[ -d "${root}" ]]; then
      roots+=("${root}")
    fi
  done

  if [[ "${#roots[@]}" -eq 0 ]]; then
    return 1
  fi

  find "${roots[@]}" \
    -maxdepth 1 -type f \( -name "libnode.so" -o -name "libnode.so.*" \) \
    2>/dev/null | sort | tail -n 1
}

echo "[offline-libnode] Source: ${SOURCE_DIR}"
echo "[offline-libnode] NDK: ${ANDROID_NDK_PATH}"
echo "[offline-libnode] Data use: 0 MB; this script performs no network operations."

existing_lib="$(find_built_libnode || true)"
if [[ -n "${existing_lib}" && "${FORCE_CONFIGURE}" != "1" && "${FORCE_REBUILD}" != "1" ]]; then
  candidate="${OUTPUT_DIR}/libnode-v22.22.3-android-arm64.so"
  cp "${existing_lib}" "${candidate}"
  cp "${existing_lib}" "${OUTPUT_DIR}/libnode.so"
  sha256sum "${candidate}" >"${candidate}.sha256"
  sha256sum "${OUTPUT_DIR}/libnode.so" >"${OUTPUT_DIR}/libnode.so.sha256"

  echo "[offline-libnode] Reused existing libnode.so: ${existing_lib}"
  echo "[offline-libnode] SUCCESS"
  echo "[offline-libnode] ${candidate}"
  cat "${candidate}.sha256"
  exit 0
fi

echo "[offline-libnode] Disabling V8 trap handler for Android"
perl -0pi -e 's!// X64 on Linux, Windows, MacOS, FreeBSD\.\n\#if V8_HOST_ARCH_X64.*?\n\#endif!// Plawie Android embedded-Node build: Android trap handler stays disabled.\n#define V8_TRAP_HANDLER_SUPPORTED false!s' \
  deps/v8/src/trap-handler/trap-handler.h
rm -f deps/v8/src/trap-handler/trap-handler.h.rej

echo "[offline-libnode] Adding Android warning flag if absent"
perl -0pi -e "s#'cflags': \\[ '-Wall', '-Wextra', '-Wno-unused-parameter', \\],#'cflags': [ '-Wall', '-Wextra', '-Wno-unused-parameter', '-Wno-enum-constexpr-conversion', ],# if index(\$_, '-Wno-enum-constexpr-conversion') < 0" \
  common.gypi

export PATH="${toolchain}/bin:${PATH}"
export CC="${toolchain}/bin/aarch64-linux-android${ANDROID_SDK_VERSION}-clang"
export CXX="${toolchain}/bin/aarch64-linux-android${ANDROID_SDK_VERSION}-clang++"
export CC_host
export CXX_host
export LINK_host
CC_host="$(command -v gcc)"
CXX_host="$(command -v g++)"
LINK_host="${CXX_host}"
export GYP_DEFINES
GYP_DEFINES="target_arch=arm64 v8_target_arch=arm64 android_target_arch=arm64 host_arch=x64 host_os=linux OS=android android_ndk_path=${ANDROID_NDK_PATH} android_ndk_sysroot=${toolchain}/sysroot"

config_is_valid=0
if [[ -f config.gypi ]] &&
  grep -q '"host_arch": "x64"' config.gypi &&
  grep -q '"target_arch": "arm64"' config.gypi &&
  grep -q '"node_shared": "true"' config.gypi; then
  config_is_valid=1
fi

if [[ "${FORCE_CONFIGURE}" == "1" || "${config_is_valid}" != "1" ]]; then
  echo "[offline-libnode] Configuring shared Node with ${INTL_MODE}"
  ./configure \
    --dest-cpu=arm64 \
    --dest-os=android \
    --openssl-no-asm \
    --with-intl="${INTL_MODE}" \
    --without-npm \
    --cross-compiling \
    --shared

  echo "[offline-libnode] Removing stale host objects"
  rm -rf out/Release/obj.host
else
  echo "[offline-libnode] Reusing existing valid config.gypi; set FORCE_CONFIGURE=1 to regenerate"
fi

echo "[offline-libnode] Config sanity"
grep -n '"host_arch": "x64"' config.gypi
grep -n '"target_arch": "arm64"' config.gypi
grep -n '"node_shared": "true"' config.gypi

if [[ -d out ]]; then
  find out -name "*.host.mk" -type f -print0 |
    xargs -0 -r sed -i '/-mbranch-protection=standard[[:space:]]*\\/d'
fi

prebuilt_lib="$(find_built_libnode || true)"
if [[ -n "${prebuilt_lib}" && "${FORCE_REBUILD}" != "1" ]]; then
  echo "[offline-libnode] Reusing existing libnode.so: ${prebuilt_lib}"
else
  echo "[offline-libnode] Building libnode.so"
  set +e
  make -C out -j"${JOBS}" libnode \
    CC.host="${CC_host}" \
    CXX.host="${CXX_host}" \
    LINK.host="${LINK_host}" 2>&1 | tee "${BUILD_LOG}"
  build_status=${PIPESTATUS[0]}
  set -e

  if [[ "${build_status}" -ne 0 ]]; then
    echo "[offline-libnode] Build failed with exit code ${build_status}. Log: ${BUILD_LOG}" >&2
    exit "${build_status}"
  fi
fi

built_lib="$(find_built_libnode || true)"

if [[ -z "${built_lib}" ]]; then
  echo "Build finished without a known libnode.so output" >&2
  exit 1
fi

candidate="${OUTPUT_DIR}/libnode-v22.22.3-android-arm64.so"
cp "${built_lib}" "${candidate}"
cp "${built_lib}" "${OUTPUT_DIR}/libnode.so"
sha256sum "${candidate}" >"${candidate}.sha256"
sha256sum "${OUTPUT_DIR}/libnode.so" >"${OUTPUT_DIR}/libnode.so.sha256"

echo "[offline-libnode] SUCCESS"
echo "[offline-libnode] ${candidate}"
cat "${candidate}.sha256"
