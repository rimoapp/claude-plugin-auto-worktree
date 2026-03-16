#!/usr/bin/env bash
# Tests for lib/worktree.sh — git worktree operations.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PLUGIN_ROOT}/lib/worktree.sh"

# Create a temporary git repo for testing
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

REPO_DIR="${TEMP_DIR}/test-repo"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -b main &>/dev/null
git config commit.gpgsign false
git commit --allow-empty -m "initial commit" &>/dev/null

PASS=0
FAIL=0

assert_eq() {
  local actual="$1"
  local expected="$2"
  local desc="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: expected '${expected}', got '${actual}'" >&2
  fi
}

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

# --- Test get_main_repo_root ---
root="$(get_main_repo_root "$REPO_DIR")"
assert_eq "$root" "$REPO_DIR" "get_main_repo_root from main repo"

# --- Test generate_branch_name ---
branch="$(generate_branch_name "abc123def")"
assert_true "branch starts with worktree/" test "$(echo "$branch" | grep -c '^worktree/')" -eq 1
assert_true "branch contains session prefix" test "$(echo "$branch" | grep -c 'abc123')" -eq 1

# --- Test create_worktree ---
WT_PATH="${TEMP_DIR}/test-repo-worktrees/worktree/test-branch"
create_worktree "$REPO_DIR" "worktree/test-branch" "$WT_PATH" &>/dev/null

assert_true "worktree directory exists" test -d "$WT_PATH"
assert_true "worktree has .git" test -e "$WT_PATH/.git"

# --- Test is_inside_worktree (in worktree) ---
assert_true "is_inside_worktree in worktree" is_inside_worktree "$WT_PATH"

# --- Test get_main_repo_root from worktree ---
root_from_wt="$(get_main_repo_root "$WT_PATH")"
assert_eq "$root_from_wt" "$REPO_DIR" "get_main_repo_root from worktree"

# --- Test get_worktree_base_dir ---
base="$(get_worktree_base_dir "$REPO_DIR")"
assert_eq "$base" "${TEMP_DIR}/test-repo-worktrees" "get_worktree_base_dir"

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
