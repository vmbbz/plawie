#!/usr/bin/env bash
set -euo pipefail

# Builds the nodejs-mobile Android arm64 shared-library artifact for research.
# This does not produce the executable expected by NativeNodeSmokeProcess and
# must not be packaged with package_native_node_candidate.ps1.

MOBILE_REPO="${MOBILE_REPO:-https://github.com/nodejs-mobile/nodejs-mobile.git}"
MOBILE_REF="${MOBILE_REF:-106c51f95d55d1010de56a2ffd09bfb4ba819a47}"
ANDROID_SDK_VERSION="${ANDROID_SDK_VERSION:-24}"
TARGET_ARCH="${TARGET_ARCH:-arm64}"
WORK_DIR="${WORK_DIR:-$(pwd)/build/native-node/nodejs-mobile-${TARGET_ARCH}}"
OUTPUT_DIR="${OUTPUT_DIR:-${WORK_DIR}/output}"
ANDROID_NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"

if [[ -z "${ANDROID_NDK_PATH}" ]]; then
  cat >&2 <<'EOF'
ANDROID_NDK_HOME or ANDROID_NDK_ROOT must point to an extracted Android NDK.

nodejs-mobile's current Android CI uses NDK r26d and Android target SDK 24.
EOF
  exit 2
fi

for tool in git make sha256sum; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 2
  fi
done

if [[ "${TARGET_ARCH}" != "arm64" ]]; then
  echo "This helper is intentionally scoped to Android arm64. Got TARGET_ARCH=${TARGET_ARCH}" >&2
  exit 2
fi

HOST_TAG="linux-x86_64"
TARGET_CXX="${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/${HOST_TAG}/bin/aarch64-linux-android${ANDROID_SDK_VERSION}-clang++"

if [[ ! -x "${TARGET_CXX}" ]]; then
  cat >&2 <<EOF
The configured NDK is not usable from this Linux/WSL shell.

Expected compiler:
  ${TARGET_CXX}
EOF
  exit 2
fi

SOURCE_DIR="${WORK_DIR}/nodejs-mobile"
OUTPUT_LIB="${OUTPUT_DIR}/libnode-nodejs-mobile-v22.9.0-android-arm64.so"

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  echo "[nodejs-mobile] Cloning ${MOBILE_REPO}"
  git clone "${MOBILE_REPO}" "${SOURCE_DIR}"
fi

pushd "${SOURCE_DIR}" >/dev/null
echo "[nodejs-mobile] Checking out ${MOBILE_REF}"
git fetch --depth 1 origin "${MOBILE_REF}"
git checkout --detach FETCH_HEAD

echo "[nodejs-mobile] Building Android ${TARGET_ARCH} shared library"
./tools/android_build.sh "${ANDROID_NDK_PATH}" "${ANDROID_SDK_VERSION}" "${TARGET_ARCH}"
popd >/dev/null

BUILT_LIB="${SOURCE_DIR}/out_android/arm64-v8a/libnode.so"
if [[ ! -f "${BUILT_LIB}" ]]; then
  echo "nodejs-mobile build completed without ${BUILT_LIB}" >&2
  exit 1
fi

cp "${BUILT_LIB}" "${OUTPUT_LIB}"
sha256sum "${OUTPUT_LIB}" > "${OUTPUT_LIB}.sha256"

echo ""
echo "[nodejs-mobile] Shared library built:"
echo "  ${OUTPUT_LIB}"
echo "[nodejs-mobile] SHA-256:"
cat "${OUTPUT_LIB}.sha256"
echo ""
echo "Do not package this with package_native_node_candidate.ps1."
echo "It is an embedded libnode.so proof artifact, not a standalone Node executable."
