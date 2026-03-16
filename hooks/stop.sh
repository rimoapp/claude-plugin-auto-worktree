#!/usr/bin/env bash
# Stop hook for auto-worktree plugin.
# Prints a summary of the worktree created during this session,
# including the path, branch, and any uncommitted changes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PLUGIN_ROOT}/lib/state.sh"

# --- JSON Parsing ---
parse_json_field() {
  local json="$1"
  local field="$2"
  if command -v jq &>/dev/null; then
    echo "$json" | jq -r "$field"
  elif command -v python3 &>/dev/null; then
    echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(eval('d' + ''.join('[\"' + k + '\"]' for k in '$field'.strip('.').split('.'))))" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

main() {
  local input
  input="$(cat)"

  local session_id
  session_id="$(parse_json_field "$input" '.session_id')"

  if [[ -z "$session_id" ]]; then
    exit 0
  fi

  # Check if a worktree was created for this session
  if ! state_exists "$session_id"; then
    exit 0
  fi

  local worktree_path branch_name
  worktree_path="$(load_worktree_path "$session_id")"
  branch_name="$(load_branch_name "$session_id")"

  if [[ -z "$worktree_path" || ! -d "$worktree_path" ]]; then
    exit 0
  fi

  # Print session summary
  echo "" >&2
  echo "=== Auto-Worktree Session Summary ===" >&2
  echo "  Worktree: ${worktree_path}" >&2
  echo "  Branch:   ${branch_name}" >&2

  # Check for uncommitted changes
  local status_output
  status_output="$(git -C "$worktree_path" status --porcelain 2>/dev/null)" || true

  if [[ -n "$status_output" ]]; then
    echo "" >&2
    echo "  WARNING: Uncommitted changes in worktree:" >&2
    echo "$status_output" | while IFS= read -r line; do
      echo "    ${line}" >&2
    done
  fi

  # Check for unpushed commits
  local unpushed
  unpushed="$(git -C "$worktree_path" log --oneline '@{upstream}..HEAD' 2>/dev/null)" || true

  if [[ -n "$unpushed" ]]; then
    echo "" >&2
    echo "  Unpushed commits:" >&2
    echo "$unpushed" | while IFS= read -r line; do
      echo "    ${line}" >&2
    done
  fi

  echo "" >&2
  echo "  To continue working: cd ${worktree_path}" >&2
  echo "  To clean up:         git worktree remove ${worktree_path}" >&2
  echo "======================================" >&2

  # Always allow stopping
  exit 0
}

main
