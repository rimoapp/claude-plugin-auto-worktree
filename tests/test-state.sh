#!/usr/bin/env bash
# Tests for lib/state.sh — session state management.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PLUGIN_ROOT}/lib/state.sh"

# Override STATE_DIR to use a temp directory for testing
STATE_DIR="$(mktemp -d)"
trap 'rm -rf "$STATE_DIR"' EXIT

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

# --- Test state_exists before save ---
assert_false "state_exists before save" state_exists "test-session-1"

# --- Test save and load ---
save_state "test-session-1" "/tmp/worktree/path" "worktree/20250101-120000-abc123"

assert_true "state_exists after save" state_exists "test-session-1"

path="$(load_worktree_path "test-session-1")"
assert_eq "$path" "/tmp/worktree/path" "load_worktree_path"

branch="$(load_branch_name "test-session-1")"
assert_eq "$branch" "worktree/20250101-120000-abc123" "load_branch_name"

# --- Test multiple sessions ---
save_state "test-session-2" "/tmp/worktree/other" "worktree/20250102-130000-def456"

path2="$(load_worktree_path "test-session-2")"
assert_eq "$path2" "/tmp/worktree/other" "load_worktree_path session 2"

# Session 1 still intact
path1="$(load_worktree_path "test-session-1")"
assert_eq "$path1" "/tmp/worktree/path" "session 1 still intact"

# --- Test remove_state ---
remove_state "test-session-1"
assert_false "state_exists after remove" state_exists "test-session-1"

# Session 2 still intact
assert_true "session 2 still exists" state_exists "test-session-2"

# --- Test load from non-existent session ---
empty_path="$(load_worktree_path "nonexistent")"
assert_eq "$empty_path" "" "load from nonexistent session returns empty"

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
