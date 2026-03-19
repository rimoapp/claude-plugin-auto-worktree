#!/usr/bin/env bash
# Integration tests for hooks/pre-tool-use.sh
# Tests that the hook blocks mutations in main repo and allows in worktrees.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Create a temporary git repo for testing
TEMP_DIR="$(mktemp -d)"
trap 'cd /; rm -rf "$TEMP_DIR"' EXIT

REPO_DIR="${TEMP_DIR}/test-repo"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -b main &>/dev/null
git config commit.gpgsign false
git commit --allow-empty -m "initial commit" &>/dev/null

HOOK="${PLUGIN_ROOT}/hooks/pre-tool-use.sh"

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

run_hook() {
  local json="$1"
  local exit_code=0
  echo "$json" | bash "$HOOK" 2>/dev/null || exit_code=$?
  echo $exit_code
}

run_hook_stderr() {
  local json="$1"
  echo "$json" | bash "$HOOK" 2>&1 >/dev/null || true
}

SESSION="test-$(date +%s)-$$"

# --- Test 1: Write tool in main repo → exit 2 ---
result="$(run_hook "{\"session_id\":\"${SESSION}-1\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${REPO_DIR}\"}")"
assert_exit_code 2 "$result" "Write in main repo should exit 2"

# --- Test 2: Stderr should mention EnterWorktree ---
stderr_output="$(run_hook_stderr "{\"session_id\":\"${SESSION}-2\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${REPO_DIR}\"}")"
if echo "$stderr_output" | grep -q "EnterWorktree"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: stderr should mention EnterWorktree" >&2
fi

# --- Test 3: Edit tool in main repo → exit 2 ---
result="$(run_hook "{\"session_id\":\"${SESSION}-3\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${REPO_DIR}\"}")"
assert_exit_code 2 "$result" "Edit in main repo should exit 2"

# --- Test 4: Write tool in a worktree → exit 0 ---
WORKTREE_DIR="${TEMP_DIR}/test-worktree"
git worktree add "$WORKTREE_DIR" -b test-branch &>/dev/null
result="$(run_hook "{\"session_id\":\"${SESSION}-4\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${WORKTREE_DIR}\"}")"
assert_exit_code 0 "$result" "Write in worktree should exit 0"

# --- Test 5: Bash read-only command in main repo → exit 0 ---
result="$(run_hook "{\"session_id\":\"${SESSION}-5\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls -la\"},\"cwd\":\"${REPO_DIR}\"}")"
assert_exit_code 0 "$result" "Bash read-only (ls) should exit 0"

# --- Test 6: Bash mutating command in main repo → exit 2 ---
result="$(run_hook "{\"session_id\":\"${SESSION}-6\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"touch newfile.txt\"},\"cwd\":\"${REPO_DIR}\"}")"
assert_exit_code 2 "$result" "Bash mutating (touch) should exit 2"

# --- Test 7: Bash mutating in worktree → exit 0 ---
result="$(run_hook "{\"session_id\":\"${SESSION}-7\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"touch newfile.txt\"},\"cwd\":\"${WORKTREE_DIR}\"}")"
assert_exit_code 0 "$result" "Bash mutating in worktree should exit 0"

# --- Test 8: Non-git directory → exit 0 ---
NON_GIT_DIR="$(mktemp -d)"
result="$(run_hook "{\"session_id\":\"${SESSION}-8\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${NON_GIT_DIR}\"}")"
assert_exit_code 0 "$result" "Write in non-git dir should exit 0"
rmdir "$NON_GIT_DIR"

# --- Test 9: Empty/invalid JSON → exit 0 (fail open) ---
result="$(run_hook "{}")"
assert_exit_code 0 "$result" "Empty JSON should exit 0 (fail open)"

# --- Test 10: Edit tool in worktree → exit 0 ---
result="$(run_hook "{\"session_id\":\"${SESSION}-10\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${WORKTREE_DIR}\"}")"
assert_exit_code 0 "$result" "Edit in worktree should exit 0"

# --- Test 11: Bash git status (read-only) in main repo → exit 0 ---
result="$(run_hook "{\"session_id\":\"${SESSION}-11\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status\"},\"cwd\":\"${REPO_DIR}\"}")"
assert_exit_code 0 "$result" "Bash git status in main repo should exit 0"

# --- Test 12: Bash git commit (mutating) in main repo → exit 2 ---
result="$(run_hook "{\"session_id\":\"${SESSION}-12\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'test'\"},\"cwd\":\"${REPO_DIR}\"}")"
assert_exit_code 2 "$result" "Bash git commit in main repo should exit 2"

# --- Test 13: Write in subdirectory of main repo → exit 2 ---
SUBDIR="${REPO_DIR}/subdir"
mkdir -p "$SUBDIR"
result="$(run_hook "{\"session_id\":\"${SESSION}-13\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${SUBDIR}\"}")"
assert_exit_code 2 "$result" "Write in subdirectory of main repo should exit 2"

# --- Test 14: Write in subdirectory of worktree → exit 0 ---
WT_SUBDIR="${WORKTREE_DIR}/subdir"
mkdir -p "$WT_SUBDIR"
result="$(run_hook "{\"session_id\":\"${SESSION}-14\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${WT_SUBDIR}\"}")"
assert_exit_code 0 "$result" "Write in subdirectory of worktree should exit 0"

# --- Test 15: Bash empty command in main repo → exit 2 (not proven read-only) ---
result="$(run_hook "{\"session_id\":\"${SESSION}-15\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"\"},\"cwd\":\"${REPO_DIR}\"}")"
assert_exit_code 2 "$result" "Bash empty command should exit 2"

# --- Test 16: Stderr mentions 'main repository' ---
stderr_output="$(run_hook_stderr "{\"session_id\":\"${SESSION}-16\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${REPO_DIR}\"}")"
if echo "$stderr_output" | grep -q "main repository"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: stderr should mention 'main repository'" >&2
fi

# --- Cleanup ---
git -C "$REPO_DIR" worktree remove "$WORKTREE_DIR" 2>/dev/null || true

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
