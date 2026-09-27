#!/usr/bin/env bash
set -euo pipefail

# Runs the version-entry revision check. The check itself is
# check-revision.lua, which loads each changed recipe AS LUA on the base ref
# and in the work tree and compares their version entries -- read that file
# for the rule and for what it does not cover (hook changes, which review
# has to judge).
#
# This wrapper finds an interpreter and the base ref, the way
# check-dep-namespace.sh does, and for the same reasons:
#
#   * no skip when there is no interpreter. A check that skips itself reports
#     the same green as a check that ran.
#
#   * Lua 5.3+, not any `lua`. The checker needs `math.type` to tell
#     `revision = 1` from `revision = 1.0`, which a client reads as 0; on 5.2
#     the distinction is not available, and on 5.1 / LuaJIT the sandbox does
#     not work at all.
#
#   * no base, no pass. The check is a comparison; without a base ref it has
#     compared nothing, and saying PASS would claim otherwise.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

CHECKER="$ROOT_DIR/.github/scripts/check-revision.lua"

find_lua() {
  for candidate in lua5.4 lua5.3 lua; do
    command -v "$candidate" >/dev/null 2>&1 || continue
    if "$candidate" -e 'os.exit(math.type ~= nil and 0 or 1)' >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if ! LUA_CMD="$(find_lua)"; then
  echo "::error::No Lua 5.3+ interpreter found (tried lua5.4, lua5.3, lua);" \
       "cannot check version-entry revisions. Install one:" \
       "apt-get install -y lua5.4"
  exit 1
fi

# The ref the change is measured against: REVISION_BASE_REF when set; in CI
# the pull request's base branch, or the parent of the pushed commit; locally
# origin/main.
resolve_base_ref() {
  if [[ -n "${REVISION_BASE_REF:-}" ]]; then
    echo "$REVISION_BASE_REF"; return 0
  fi
  if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
    echo "origin/main"; return 0
  fi
  # --depth only on a clone that is ALREADY shallow (actions/checkout's
  # default). On a full clone it would truncate the history to that depth.
  local shallow=()
  [[ "$(git rev-parse --is-shallow-repository)" == "true" ]] && shallow=(--depth=2)
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    git fetch --no-tags --quiet "${shallow[@]}" origin \
      "+refs/heads/${GITHUB_BASE_REF}:refs/remotes/origin/${GITHUB_BASE_REF}" >&2
    echo "origin/${GITHUB_BASE_REF}"
  else
    # push: the base is the commit this one landed on.
    git fetch --no-tags --quiet "${shallow[@]}" origin "${GITHUB_SHA}" >&2
    echo "${GITHUB_SHA}~1"
  fi
}

BASE_REF="$(resolve_base_ref)"
if [[ -z "$BASE_REF" ]] || ! git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null; then
  echo "::error::cannot resolve the base ref '${BASE_REF}' for the revision check;" \
       "refusing to report a pass that compared nothing (set REVISION_BASE_REF)"
  exit 1
fi

exec "$LUA_CMD" "$CHECKER" --base "$BASE_REF" "$ROOT_DIR"
