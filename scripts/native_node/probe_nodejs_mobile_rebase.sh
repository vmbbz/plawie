#!/usr/bin/env bash
set -euo pipefail

# Probes whether nodejs-mobile's Android branch can be rebased onto a
# Plawie-compliant Node 22 tag. This is a source-control experiment only:
# it does not build libnode.so and it does not touch app runtime code.

MOBILE_REPO="${MOBILE_REPO:-https://github.com/nodejs-mobile/nodejs-mobile.git}"
MOBILE_BASE_REF="${MOBILE_BASE_REF:-update22-9-0}"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/nodejs/node.git}"
TARGET_NODE_TAG="${TARGET_NODE_TAG:-v22.22.3}"
WORK_ROOT="${WORK_ROOT:-${HOME}/.plawie/native-node}"
WORK_DIR="${WORK_DIR:-${WORK_ROOT}/nodejs-mobile-rebase-${TARGET_NODE_TAG}}"
SOURCE_DIR="${WORK_DIR}/nodejs-mobile"
REPORT_DIR="${WORK_DIR}/reports"
REBASE_LOG="${REPORT_DIR}/rebase-${TARGET_NODE_TAG}.log"
STATUS_FILE="${REPORT_DIR}/status-${TARGET_NODE_TAG}.txt"
CONFLICTS_FILE="${REPORT_DIR}/conflicts-${TARGET_NODE_TAG}.txt"
SUMMARY_FILE="${REPORT_DIR}/summary-${TARGET_NODE_TAG}.txt"
EXPERIMENT_BRANCH="${EXPERIMENT_BRANCH:-plawie-rebase-${TARGET_NODE_TAG}}"
CONFLICT_PRINT_LIMIT="${CONFLICT_PRINT_LIMIT:-120}"

for tool in git sed tee; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 2
  fi
done

mkdir -p "${WORK_DIR}" "${REPORT_DIR}"

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  echo "[nodejs-mobile-rebase] Cloning ${MOBILE_REPO}"
  git clone --filter=blob:none --single-branch --branch "${MOBILE_BASE_REF}" "${MOBILE_REPO}" "${SOURCE_DIR}"
else
  echo "[nodejs-mobile-rebase] Reusing ${SOURCE_DIR}"
fi

pushd "${SOURCE_DIR}" >/dev/null

if [[ -d ".git/rebase-merge" || -d ".git/rebase-apply" ]]; then
  echo "[nodejs-mobile-rebase] Aborting previous incomplete rebase"
  git rebase --abort || true
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream "${UPSTREAM_REPO}"
else
  git remote set-url upstream "${UPSTREAM_REPO}"
fi

echo "[nodejs-mobile-rebase] Fetching mobile base ${MOBILE_BASE_REF}"
git fetch --no-tags origin "refs/heads/${MOBILE_BASE_REF}:refs/remotes/origin/${MOBILE_BASE_REF}"
git checkout -B "${EXPERIMENT_BRANCH}" "origin/${MOBILE_BASE_REF}"

echo "[nodejs-mobile-rebase] Cleaning experiment branch"
git reset --hard HEAD
git clean -fdx

base_commit="$(git rev-parse HEAD)"
base_version="$(sed -n 's/^#define NODE_MAJOR_VERSION[[:space:]]*//p' src/node_version.h).$(sed -n 's/^#define NODE_MINOR_VERSION[[:space:]]*//p' src/node_version.h).$(sed -n 's/^#define NODE_PATCH_VERSION[[:space:]]*//p' src/node_version.h)"

echo "[nodejs-mobile-rebase] Fetching upstream tag ${TARGET_NODE_TAG}"
git fetch --no-tags upstream "refs/tags/${TARGET_NODE_TAG}:refs/tags/${TARGET_NODE_TAG}"
target_commit="$(git rev-list -n 1 "${TARGET_NODE_TAG}")"

set +e
git \
  -c user.name="Plawie Native Probe" \
  -c user.email="native-probe@plawie.local" \
  rebase "${TARGET_NODE_TAG}" >"${REBASE_LOG}" 2>&1
rebase_status=$?
set -e

git status --short >"${STATUS_FILE}" || true
git diff --name-only --diff-filter=U >"${CONFLICTS_FILE}" || true

if [[ "${rebase_status}" -eq 0 ]]; then
  result="success"
  rebased_head="$(git rev-parse HEAD)"
  rebased_version="$(sed -n 's/^#define NODE_MAJOR_VERSION[[:space:]]*//p' src/node_version.h).$(sed -n 's/^#define NODE_MINOR_VERSION[[:space:]]*//p' src/node_version.h).$(sed -n 's/^#define NODE_PATCH_VERSION[[:space:]]*//p' src/node_version.h)"
else
  if [[ -s "${CONFLICTS_FILE}" ]]; then
    result="conflict"
  else
    result="failed"
  fi
  rebased_head=""
  rebased_version=""
fi

{
  echo "nodejs-mobile rebase probe"
  echo "==========================="
  echo "mobile_repo=${MOBILE_REPO}"
  echo "mobile_base_ref=${MOBILE_BASE_REF}"
  echo "base_commit=${base_commit}"
  echo "base_version=${base_version}"
  echo "upstream_repo=${UPSTREAM_REPO}"
  echo "target_node_tag=${TARGET_NODE_TAG}"
  echo "target_commit=${target_commit}"
  echo "experiment_branch=${EXPERIMENT_BRANCH}"
  echo "result=${result}"
  echo "rebase_exit_code=${rebase_status}"
  if [[ -n "${rebased_head}" ]]; then
    echo "rebased_head=${rebased_head}"
    echo "rebased_version=${rebased_version}"
  fi
  echo "rebase_log=${REBASE_LOG}"
  echo "status_file=${STATUS_FILE}"
  echo "conflicts_file=${CONFLICTS_FILE}"
} | tee "${SUMMARY_FILE}"

if [[ "${rebase_status}" -ne 0 ]]; then
  echo ""
  echo "[nodejs-mobile-rebase] Rebase stopped with conflicts."
  echo "[nodejs-mobile-rebase] Conflicted files shown up to ${CONFLICT_PRINT_LIMIT}:"
  if [[ -s "${CONFLICTS_FILE}" ]]; then
    sed -n "1,${CONFLICT_PRINT_LIMIT}p" "${CONFLICTS_FILE}" | sed 's/^/  /'
  else
    echo "  none reported by git diff --diff-filter=U"
  fi
  echo "[nodejs-mobile-rebase] Inspect ${REBASE_LOG}"
fi

popd >/dev/null
exit "${rebase_status}"
