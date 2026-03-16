#!/usr/bin/env bash
# Tests for hooks/stop.sh — Stop hook session summary.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Create a temporary git repo for testing
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

REPO_DIR="${TEMP_DIR}/test-repo"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -b main &>/dev/null
git config commit.gpgsign false
git commit --allow-empty -m "initial commit" &>/dev/null

# Override STATE_DIR used by state.sh
export STATE_DIR="${TEMP_DIR}/state"
mkdir -p "$STATE_DIR"

# Source state.sh to create test state
source "${PLUGIN_ROOT}/lib/state.sh"

HOOK="${PLUGIN_ROOT}/hooks/stop.sh"

PASS=0
FAIL=0

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local desc="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: expected exit ${expected}, got ${actual}" >&2
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local desc="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: output does not contain '${needle}'" >&2
  fi
}

# --- Test 1: No worktree state → silent exit 0 ---
exit_code=0
output="$(echo '{"session_id":"no-state-session"}' | bash "$HOOK" 2>&1)" || exit_code=$?
assert_exit_code 0 "$exit_code" "No state → exit 0"

# --- Test 2: With worktree state → prints summary ---
# Create a worktree first
WT_PATH="${TEMP_DIR}/test-repo-worktrees/worktree/test-stop"
git worktree add "$WT_PATH" -b "worktree/test-stop" &>/dev/null

save_state "stop-test-session" "$WT_PATH" "worktree/test-stop"

exit_code=0
output="$(echo '{"session_id":"stop-test-session"}' | bash "$HOOK" 2>&1)" || exit_code=$?
assert_exit_code 0 "$exit_code" "With state → exit 0 (never blocks)"
assert_contains "$output" "Auto-Worktree Session Summary" "Output contains summary header"
assert_contains "$output" "$WT_PATH" "Output contains worktree path"
assert_contains "$output" "worktree/test-stop" "Output contains branch name"

# --- Test 3: With uncommitted changes → shows warning ---
echo "test content" > "${WT_PATH}/newfile.txt"
git -C "$WT_PATH" add newfile.txt &>/dev/null

exit_code=0
output="$(echo '{"session_id":"stop-test-session"}' | bash "$HOOK" 2>&1)" || exit_code=$?
assert_exit_code 0 "$exit_code" "With uncommitted changes → still exit 0"
assert_contains "$output" "Uncommitted changes" "Output warns about uncommitted changes"

# --- Test 4: Empty session_id → exit 0 ---
exit_code=0
echo '{"session_id":""}' | bash "$HOOK" 2>/dev/null || exit_code=$?
assert_exit_code 0 "$exit_code" "Empty session_id → exit 0"

# Cleanup
git -C "$REPO_DIR" worktree remove "$WT_PATH" --force 2>/dev/null || true

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
