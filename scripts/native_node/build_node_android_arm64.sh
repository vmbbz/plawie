#!/usr/bin/env bash
set -euo pipefail

# Builds a local Android arm64 Node candidate from the official Node source
# tarball. This is a research helper; it does not touch production Gateway
# routing and does not package the binary into the APK by itself.

NODE_VERSION="${NODE_VERSION:-v22.22.3}"
NODE_SOURCE_SHA256="${NODE_SOURCE_SHA256:-f3e6a578db1ab335a4a72785c1e87ad18a2cf6d2fc25747a1d741fb34af0bd0f}"
ANDROID_SDK_VERSION="${ANDROID_SDK_VERSION:-29}"
TARGET_ARCH="${TARGET_ARCH:-arm64}"
JOBS="${JOBS:-4}"
WORK_DIR="${WORK_DIR:-$(pwd)/build/native-node/${NODE_VERSION}-${TARGET_ARCH}}"
OUTPUT_DIR="${OUTPUT_DIR:-${WORK_DIR}/output}"
ANDROID_NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
HOST_CC="${HOST_CC:-gcc}"
HOST_CXX="${HOST_CXX:-g++}"
CLEAN_HOST_OBJECTS="${CLEAN_HOST_OBJECTS:-0}"
ALLOW_NETWORK="${PLAWIE_ALLOW_NETWORK:-0}"

require_network() {
  if [[ "${ALLOW_NETWORK}" != "1" ]]; then
    cat >&2 <<EOF
Refusing network download.

This helper may download Node source from:
  ${SOURCE_URL}

Set PLAWIE_ALLOW_NETWORK=1 only after confirming data/disk budget.
EOF
    exit 3
  fi
}

if [[ -z "${ANDROID_NDK_PATH}" ]]; then
  cat >&2 <<'EOF'
ANDROID_NDK_HOME or ANDROID_NDK_ROOT must point to an extracted Android NDK.

Example:
  export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"
EOF
  exit 2
fi

for tool in curl cut make tar sha256sum; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 2
  fi
done

for tool in "${HOST_CC}" "${HOST_CXX}"; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing host compiler: ${tool}" >&2
    exit 2
  fi
done

HOST_TAG="linux-x86_64"
TOOLCHAIN_BIN="${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/${HOST_TAG}/bin"
TARGET_CXX="${TOOLCHAIN_BIN}/aarch64-linux-android${ANDROID_SDK_VERSION}-clang++"

if [[ ! -x "${TARGET_CXX}" ]]; then
  cat >&2 <<EOF
The configured NDK is not usable from this Linux/WSL shell.

Expected compiler:
  ${TARGET_CXX}

If your installed NDK only contains a Windows prebuilt toolchain, prepare a
Linux-host NDK first:

  ./scripts/native_node/prepare_android_ndk_linux.sh
  export ANDROID_NDK_HOME="\$HOME/.plawie/android/android-ndk-r28c"

Then rerun this build helper.
EOF
  exit 2
fi

if [[ "$(pwd)" == /mnt/* ]]; then
  echo "[native-node] Note: repo is on a Windows mount. For speed and disk headroom, consider WORK_DIR under the WSL filesystem, for example:"
  echo "  WORK_DIR=\"\$HOME/plawie-native-node-build/${NODE_VERSION}-${TARGET_ARCH}\" ./scripts/native_node/build_node_android_arm64.sh"
fi

case "${TARGET_ARCH}" in
  arm64|aarch64) ;;
  *)
    echo "This helper is intentionally scoped to Android arm64. Got TARGET_ARCH=${TARGET_ARCH}" >&2
    exit 2
    ;;
esac

SOURCE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}.tar.xz"
TARBALL="${WORK_DIR}/node-${NODE_VERSION}.tar.xz"
SOURCE_DIR="${WORK_DIR}/node-${NODE_VERSION}"
OUTPUT_NODE="${OUTPUT_DIR}/node-${NODE_VERSION}-android-${TARGET_ARCH}"

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"

if [[ ! -f "${TARBALL}" ]]; then
  require_network
  echo "[native-node] Downloading ${SOURCE_URL}"
  curl --fail --location --output "${TARBALL}" "${SOURCE_URL}"
else
  echo "[native-node] Reusing ${TARBALL}"
fi

echo "${NODE_SOURCE_SHA256}  ${TARBALL}" | sha256sum -c -

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "[native-node] Extracting ${TARBALL}"
  tar -xJf "${TARBALL}" -C "${WORK_DIR}"
else
  echo "[native-node] Reusing extracted source ${SOURCE_DIR}"
fi

pushd "${SOURCE_DIR}" >/dev/null
echo "[native-node] Configuring Node ${NODE_VERSION} for Android ${TARGET_ARCH} SDK ${ANDROID_SDK_VERSION}"
./android-configure "${ANDROID_NDK_PATH}" "${ANDROID_SDK_VERSION}" "${TARGET_ARCH}"

echo "[native-node] Removing Android-only flags from generated host makefiles"
find out -name "*.host.mk" -type f -print0 |
  xargs -0 sed -i '/-mbranch-protection=standard[[:space:]]*\\/d'

if [[ "${CLEAN_HOST_OBJECTS}" == "1" && -d out/Release/obj.host ]]; then
  echo "[native-node] Removing stale host objects before rebuilding with ${HOST_CC}/${HOST_CXX}"
  rm -rf out/Release/obj.host
fi

echo "[native-node] Building with make -j${JOBS}"
make -j"${JOBS}" \
  CC.host="${HOST_CC}" \
  CXX.host="${HOST_CXX}" \
  LINK.host="${HOST_CXX}"
popd >/dev/null

if [[ ! -f "${SOURCE_DIR}/out/Release/node" ]]; then
  echo "Node build completed without ${SOURCE_DIR}/out/Release/node" >&2
  exit 1
fi

cp "${SOURCE_DIR}/out/Release/node" "${OUTPUT_NODE}"
chmod +x "${OUTPUT_NODE}"
sha256sum "${OUTPUT_NODE}" > "${OUTPUT_NODE}.sha256"

echo ""
echo "[native-node] Candidate built:"
echo "  ${OUTPUT_NODE}"
echo "[native-node] Candidate SHA-256:"
cat "${OUTPUT_NODE}.sha256"
echo ""
echo "[native-node] Package into the local APK slot from PowerShell:"
echo "  ./scripts/native_node/package_native_node_candidate.ps1 -CandidatePath \"${OUTPUT_NODE}\" -ExpectedSha256 \"$(cut -d ' ' -f 1 "${OUTPUT_NODE}.sha256")\" -DeclaredNodeVersion ${NODE_VERSION} -Force"
