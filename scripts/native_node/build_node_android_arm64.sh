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

echo "[native-node] Building with make -j${JOBS}"
make -j"${JOBS}"
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
