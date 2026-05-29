#!/usr/bin/env bash
set -euo pipefail

# Generates the small Android/core patch surface from nodejs-mobile's Node 22.9
# branch and probes whether it applies to a clean upstream Node 22 target.
# This is the follow-up to the broad rebase probe: it tests the surgical path
# without replaying the entire mobile fork history.

MOBILE_REPO="${MOBILE_REPO:-https://github.com/nodejs-mobile/nodejs-mobile.git}"
MOBILE_BASE_REF="${MOBILE_BASE_REF:-update22-9-0}"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/nodejs/node.git}"
SOURCE_BASE_TAG="${SOURCE_BASE_TAG:-v22.9.0}"
TARGET_NODE_TAG="${TARGET_NODE_TAG:-v22.22.3}"
WORK_ROOT="${WORK_ROOT:-${HOME}/.plawie/native-node}"
WORK_DIR="${WORK_DIR:-${WORK_ROOT}/nodejs-mobile-core-patch-${TARGET_NODE_TAG}}"
MOBILE_DIR="${WORK_DIR}/nodejs-mobile"
NODE_DIR="${WORK_DIR}/node-target"
REPORT_DIR="${WORK_DIR}/reports"
PATCH_PATH="${REPORT_DIR}/nodejs-mobile-core-${SOURCE_BASE_TAG}-to-${TARGET_NODE_TAG}.patch"
CHECK_LOG="${REPORT_DIR}/apply-check-${TARGET_NODE_TAG}.log"
APPLY_LOG="${REPORT_DIR}/apply-threeway-${TARGET_NODE_TAG}.log"
REJECT_LOG="${REPORT_DIR}/apply-reject-${TARGET_NODE_TAG}.log"
CONFLICTS_FILE="${REPORT_DIR}/conflicts-${TARGET_NODE_TAG}.txt"
FAILED_PATCH_FILE="${REPORT_DIR}/failed-patches-${TARGET_NODE_TAG}.txt"
REJECT_FILES_FILE="${REPORT_DIR}/reject-files-${TARGET_NODE_TAG}.txt"
REJECT_DIFF_STAT_FILE="${REPORT_DIR}/reject-diff-stat-${TARGET_NODE_TAG}.txt"
STATUS_FILE="${REPORT_DIR}/status-${TARGET_NODE_TAG}.txt"
SUMMARY_FILE="${REPORT_DIR}/summary-${TARGET_NODE_TAG}.txt"
EXPERIMENT_BRANCH="${EXPERIMENT_BRANCH:-plawie-core-patch-${TARGET_NODE_TAG}}"
CONFLICT_PRINT_LIMIT="${CONFLICT_PRINT_LIMIT:-120}"
RUN_REJECT_INSPECTION="${RUN_REJECT_INSPECTION:-1}"
ALLOW_NETWORK="${PLAWIE_ALLOW_NETWORK:-0}"

require_network() {
  if [[ "${ALLOW_NETWORK}" != "1" ]]; then
    cat >&2 <<EOF
Refusing network access.

This probe may clone/fetch from:
  ${MOBILE_REPO}
  ${UPSTREAM_REPO}

Set PLAWIE_ALLOW_NETWORK=1 only after confirming data/disk budget.
EOF
    exit 3
  fi
}

CORE_PATHS=(
  android_configure.py
  android-configure
  common.gypi
  node.gyp
  tools/android_build.sh
  tools/copy_libnode_headers.sh
  deps/v8/src/trap-handler/trap-handler.h
  tools/v8_gypfiles/v8.gyp
  tools/v8_gypfiles/toolchain.gypi
)

for tool in find git sed tee wc; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 2
  fi
done

mkdir -p "${WORK_DIR}" "${REPORT_DIR}"

if [[ ! -d "${MOBILE_DIR}/.git" ]]; then
  require_network
  echo "[nodejs-mobile-core] Cloning mobile branch ${MOBILE_BASE_REF}"
  git clone --filter=blob:none --single-branch --branch "${MOBILE_BASE_REF}" "${MOBILE_REPO}" "${MOBILE_DIR}"
else
  echo "[nodejs-mobile-core] Reusing ${MOBILE_DIR}"
fi

pushd "${MOBILE_DIR}" >/dev/null
if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream "${UPSTREAM_REPO}"
else
  git remote set-url upstream "${UPSTREAM_REPO}"
fi
require_network
git fetch --no-tags origin "refs/heads/${MOBILE_BASE_REF}:refs/remotes/origin/${MOBILE_BASE_REF}"
git checkout -B "plawie-mobile-source-${SOURCE_BASE_TAG}" "origin/${MOBILE_BASE_REF}"
git reset --hard HEAD
git clean -fdx
require_network
git fetch --no-tags upstream "refs/tags/${SOURCE_BASE_TAG}:refs/tags/${SOURCE_BASE_TAG}"
mobile_commit="$(git rev-parse HEAD)"
base_commit="$(git rev-list -n 1 "${SOURCE_BASE_TAG}")"
git diff "${SOURCE_BASE_TAG}..HEAD" -- "${CORE_PATHS[@]}" >"${PATCH_PATH}"
popd >/dev/null

if [[ ! -s "${PATCH_PATH}" ]]; then
  echo "Generated core patch is empty: ${PATCH_PATH}" >&2
  exit 1
fi

if [[ ! -d "${NODE_DIR}/.git" ]]; then
  require_network
  echo "[nodejs-mobile-core] Cloning upstream Node"
  git clone --filter=blob:none "${UPSTREAM_REPO}" "${NODE_DIR}"
else
  echo "[nodejs-mobile-core] Reusing ${NODE_DIR}"
fi

pushd "${NODE_DIR}" >/dev/null
if [[ -d ".git/rebase-merge" || -d ".git/rebase-apply" ]]; then
  git rebase --abort || true
fi
require_network
git fetch --no-tags origin "refs/tags/${TARGET_NODE_TAG}:refs/tags/${TARGET_NODE_TAG}"
git checkout -B "${EXPERIMENT_BRANCH}" "${TARGET_NODE_TAG}"
git reset --hard HEAD
git clean -fdx
target_commit="$(git rev-list -n 1 "${TARGET_NODE_TAG}")"

set +e
git apply --check "${PATCH_PATH}" >"${CHECK_LOG}" 2>&1
check_status=$?
set -e

if [[ "${check_status}" -eq 0 ]]; then
  set +e
  git apply "${PATCH_PATH}" >"${APPLY_LOG}" 2>&1
  apply_status=$?
  set -e
  mode="exact"
else
  set +e
  git apply --3way "${PATCH_PATH}" >"${APPLY_LOG}" 2>&1
  apply_status=$?
  set -e
  mode="threeway"
fi

git status --short >"${STATUS_FILE}" || true
git diff --name-only --diff-filter=U >"${CONFLICTS_FILE}" || true
grep -hE '^(error: patch failed:|error: .*patch does not apply)' "${CHECK_LOG}" "${APPLY_LOG}" \
  | sort -u >"${FAILED_PATCH_FILE}" || true

reject_status=""
reject_count="0"
if [[ "${apply_status}" -ne 0 && "${RUN_REJECT_INSPECTION}" == "1" ]]; then
  git reset --hard HEAD >/dev/null
  git clean -fdx >/dev/null
  set +e
  git apply --reject "${PATCH_PATH}" >"${REJECT_LOG}" 2>&1
  reject_status=$?
  set -e
  find . -name '*.rej' -print | sed 's#^\./##' | sort >"${REJECT_FILES_FILE}"
  git diff --stat >"${REJECT_DIFF_STAT_FILE}" || true
  if [[ -s "${REJECT_FILES_FILE}" ]]; then
    reject_count="$(wc -l < "${REJECT_FILES_FILE}" | tr -d ' ')"
  fi
  git status --short >"${STATUS_FILE}" || true
else
  : >"${REJECT_LOG}"
  : >"${REJECT_FILES_FILE}"
  : >"${REJECT_DIFF_STAT_FILE}"
fi

if [[ "${apply_status}" -eq 0 ]]; then
  result="${mode}_success"
else
  if [[ -s "${CONFLICTS_FILE}" ]]; then
    result="${mode}_conflict"
  else
    result="${mode}_failed"
  fi
fi

patch_lines="$(wc -l < "${PATCH_PATH}" | tr -d ' ')"
patch_files="$(git -C "${MOBILE_DIR}" diff --name-only "${SOURCE_BASE_TAG}..HEAD" -- "${CORE_PATHS[@]}" | wc -l | tr -d ' ')"
conflict_count="0"
if [[ -s "${CONFLICTS_FILE}" ]]; then
  conflict_count="$(wc -l < "${CONFLICTS_FILE}" | tr -d ' ')"
fi
failed_patch_count="0"
if [[ -s "${FAILED_PATCH_FILE}" ]]; then
  failed_patch_count="$(wc -l < "${FAILED_PATCH_FILE}" | tr -d ' ')"
fi

{
  echo "nodejs-mobile core patch probe"
  echo "=============================="
  echo "mobile_repo=${MOBILE_REPO}"
  echo "mobile_base_ref=${MOBILE_BASE_REF}"
  echo "mobile_commit=${mobile_commit}"
  echo "source_base_tag=${SOURCE_BASE_TAG}"
  echo "source_base_commit=${base_commit}"
  echo "target_node_tag=${TARGET_NODE_TAG}"
  echo "target_commit=${target_commit}"
  echo "experiment_branch=${EXPERIMENT_BRANCH}"
  echo "patch_path=${PATCH_PATH}"
  echo "patch_lines=${patch_lines}"
  echo "patch_files=${patch_files}"
  echo "apply_mode=${mode}"
  echo "check_exit_code=${check_status}"
  echo "apply_exit_code=${apply_status}"
  echo "result=${result}"
  echo "conflict_count=${conflict_count}"
  echo "failed_patch_count=${failed_patch_count}"
  echo "reject_inspection=${RUN_REJECT_INSPECTION}"
  echo "reject_apply_exit_code=${reject_status}"
  echo "reject_file_count=${reject_count}"
  echo "check_log=${CHECK_LOG}"
  echo "apply_log=${APPLY_LOG}"
  echo "reject_log=${REJECT_LOG}"
  echo "status_file=${STATUS_FILE}"
  echo "conflicts_file=${CONFLICTS_FILE}"
  echo "failed_patch_file=${FAILED_PATCH_FILE}"
  echo "reject_files_file=${REJECT_FILES_FILE}"
  echo "reject_diff_stat_file=${REJECT_DIFF_STAT_FILE}"
} | tee "${SUMMARY_FILE}"

if [[ "${apply_status}" -ne 0 ]]; then
  echo ""
  echo "[nodejs-mobile-core] Patch did not apply cleanly."
  echo "[nodejs-mobile-core] Conflicted files shown up to ${CONFLICT_PRINT_LIMIT}:"
  if [[ -s "${CONFLICTS_FILE}" ]]; then
    sed -n "1,${CONFLICT_PRINT_LIMIT}p" "${CONFLICTS_FILE}" | sed 's/^/  /'
  else
    echo "  none reported by git diff --diff-filter=U"
  fi
  if [[ -s "${FAILED_PATCH_FILE}" ]]; then
    echo "[nodejs-mobile-core] Failed patch lines:"
    sed -n "1,${CONFLICT_PRINT_LIMIT}p" "${FAILED_PATCH_FILE}" | sed 's/^/  /'
  fi
  if [[ -s "${REJECT_FILES_FILE}" ]]; then
    echo "[nodejs-mobile-core] Reject files from git apply --reject:"
    sed -n "1,${CONFLICT_PRINT_LIMIT}p" "${REJECT_FILES_FILE}" | sed 's/^/  /'
  fi
fi

popd >/dev/null
exit "${apply_status}"
