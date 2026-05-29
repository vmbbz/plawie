#!/usr/bin/env bash
set -euo pipefail

# Downloads and extracts the Linux-host Android NDK that matches the Flutter
# app's current Gradle ndkVersion. This is local build tooling only; it does
# not modify app runtime code or production Gateway routing.

NDK_RELEASE="${NDK_RELEASE:-r28c}"
NDK_VERSION="${NDK_VERSION:-28.2.13676358}"
NDK_SHA1="${NDK_SHA1:-a7b54a5de87fecd125a17d54f73c446199e72a64}"
NDK_SIZE_BYTES="${NDK_SIZE_BYTES:-722261334}"
NDK_ZIP_NAME="android-ndk-${NDK_RELEASE}-linux.zip"
NDK_URL="${NDK_URL:-https://dl.google.com/android/repository/${NDK_ZIP_NAME}}"
INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.plawie/android}"
CACHE_DIR="${CACHE_DIR:-$HOME/.plawie/cache}"
ZIP_PATH="${CACHE_DIR}/${NDK_ZIP_NAME}"
INSTALL_DIR="${INSTALL_ROOT}/android-ndk-${NDK_RELEASE}"
TARGET_COMPILER="${INSTALL_DIR}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang++"
CLANG_LINK="${INSTALL_DIR}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"

for tool in curl python3 sha1sum; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 2
  fi
done

mkdir -p "${CACHE_DIR}" "${INSTALL_ROOT}"

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "[native-node] Downloading Android NDK ${NDK_RELEASE} for Linux"
  echo "[native-node] ${NDK_URL}"
  curl --fail --location --output "${ZIP_PATH}" "${NDK_URL}"
else
  echo "[native-node] Reusing ${ZIP_PATH}"
fi

actual_size="$(wc -c < "${ZIP_PATH}" | tr -d ' ')"
if [[ "${actual_size}" != "${NDK_SIZE_BYTES}" ]]; then
  echo "NDK zip size mismatch. Expected ${NDK_SIZE_BYTES}, got ${actual_size}" >&2
  exit 1
fi

echo "${NDK_SHA1}  ${ZIP_PATH}" | sha1sum -c -

if [[ -e "${CLANG_LINK}" && ! -L "${CLANG_LINK}" ]]; then
  case "${INSTALL_DIR}" in
    "$HOME/.plawie/android"/android-ndk-*)
      echo "[native-node] Existing NDK extraction lost symlinks; replacing ${INSTALL_DIR}"
      rm -rf "${INSTALL_DIR}"
      ;;
    *)
      echo "Refusing to replace unexpected NDK directory: ${INSTALL_DIR}" >&2
      exit 1
      ;;
  esac
fi

if [[ -x "${TARGET_COMPILER}" && -L "${CLANG_LINK}" ]]; then
  echo "[native-node] Linux NDK already installed at ${INSTALL_DIR}"
else
  if [[ ! -d "${INSTALL_DIR}" ]]; then
    echo "[native-node] Extracting ${ZIP_PATH} to ${INSTALL_ROOT}"
    python3 - "${ZIP_PATH}" "${INSTALL_ROOT}" <<'PY'
import os
import stat
import sys
import zipfile

zip_path, install_root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    for member in archive.infolist():
        target = os.path.join(install_root, member.filename)
        mode = member.external_attr >> 16
        kind = stat.S_IFMT(mode)

        if member.is_dir():
            os.makedirs(target, exist_ok=True)
            continue

        os.makedirs(os.path.dirname(target), exist_ok=True)

        if kind == stat.S_IFLNK:
            link_target = archive.read(member).decode("utf-8")
            if os.path.lexists(target):
                os.unlink(target)
            os.symlink(link_target, target)
            continue

        with archive.open(member) as source, open(target, "wb") as dest:
            dest.write(source.read())
        if mode:
            os.chmod(target, mode & 0o777)
PY
  fi

  echo "[native-node] Repairing executable bits for extracted NDK tools"
  find "${INSTALL_DIR}" -type f \
    \( -path "*/bin/*" -o -path "*/prebuilt/linux-x86_64/*" \) \
    -exec chmod u+x {} +
fi

if [[ ! -x "${TARGET_COMPILER}" ]]; then
  echo "Linux NDK extraction did not produce the expected arm64 compiler." >&2
  echo "Expected: ${TARGET_COMPILER}" >&2
  exit 1
fi

if [[ ! -L "${CLANG_LINK}" ]]; then
  echo "Linux NDK extraction did not preserve expected compiler symlink." >&2
  echo "Expected symlink: ${CLANG_LINK}" >&2
  exit 1
fi

echo ""
echo "[native-node] Linux NDK ready:"
echo "  ${INSTALL_DIR}"
echo ""
echo "Use it with:"
echo "  export ANDROID_NDK_HOME=\"${INSTALL_DIR}\""
echo "  WORK_DIR=\"\$HOME/plawie-native-node-build/v22.22.3-arm64\" JOBS=4 ./scripts/native_node/build_node_android_arm64.sh"
