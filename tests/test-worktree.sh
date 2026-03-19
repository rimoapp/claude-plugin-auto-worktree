#!/usr/bin/env bash
# Tests for lib/worktree.sh — git worktree detection.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PLUGIN_ROOT}/lib/worktree.sh"

TEMP_DIR="$(mktemp -d)"
trap 'cd /; rm -rf "$TEMP_DIR"' EXIT

REPO_DIR="${TEMP_DIR}/test-repo"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -b main &>/dev/null
git config commit.gpgsign false
git commit --allow-empty -m "initial commit" &>/dev/null

PASS=0
FAIL=0

assert_true() {
  local desc="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: expected true" >&2
  fi
}

assert_false() {
  local desc="$1"
  shift
  if ! "$@"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: expected false" >&2
  fi
}

# --- Test is_git_repo ---
assert_true "is_git_repo in repo" is_git_repo "$REPO_DIR"
assert_false "is_git_repo in /tmp" is_git_repo "/tmp"

# --- Test is_inside_worktree (main repo) ---
assert_false "not inside worktree in main repo" is_inside_worktree "$REPO_DIR"

# --- Test is_inside_worktree (in worktree) ---
WT_PATH="${TEMP_DIR}/test-worktree"
git worktree add "$WT_PATH" -b "test-branch" &>/dev/null
assert_true "is_inside_worktree in worktree" is_inside_worktree "$WT_PATH"

# --- Test subdirectory of main repo ---
SUBDIR="${REPO_DIR}/subdir"
mkdir -p "$SUBDIR"
assert_true "is_git_repo in repo subdir" is_git_repo "$SUBDIR"
assert_false "not inside worktree in repo subdir" is_inside_worktree "$SUBDIR"

# --- Test subdirectory of worktree ---
WT_SUBDIR="${WT_PATH}/deep/nested"
mkdir -p "$WT_SUBDIR"
assert_true "is_git_repo in worktree subdir" is_git_repo "$WT_SUBDIR"
assert_true "is_inside_worktree in worktree subdir" is_inside_worktree "$WT_SUBDIR"

# --- Test non-existent directory ---
assert_false "is_git_repo for non-existent dir" is_git_repo "/tmp/does-not-exist-$$"

# --- Cleanup ---
git -C "$REPO_DIR" worktree remove "$WT_PATH" 2>/dev/null || true

echo "${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then exit 1; fi
