#!/usr/bin/env bash
# PreToolUse hook for auto-worktree plugin.
# Intercepts Write, Edit, and Bash tool calls. If Claude is about to modify
# files in the main repository (not a worktree), this hook creates a new
# git worktree and blocks the action, instructing Claude to cd there first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source library functions
source "${PLUGIN_ROOT}/lib/state.sh"
source "${PLUGIN_ROOT}/lib/worktree.sh"
source "${PLUGIN_ROOT}/lib/bash-filter.sh"

# --- JSON Parsing ---
# Try jq first, fall back to python3.
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

# --- Main Logic ---
main() {
  # Read JSON input from stdin
  local input
  input="$(cat)"

  local session_id tool_name cwd
  session_id="$(parse_json_field "$input" '.session_id')"
  tool_name="$(parse_json_field "$input" '.tool_name')"
  cwd="$(parse_json_field "$input" '.cwd')"

  # Guard: if we can't parse essential fields, allow the action
  if [[ -z "$session_id" || -z "$tool_name" || -z "$cwd" ]]; then
    exit 0
  fi

  # 1. Not a git repo? → no-op
  if ! is_git_repo "$cwd"; then
    exit 0
  fi

  # 2. Already inside a linked worktree? → allow
  if is_inside_worktree "$cwd"; then
    exit 0
  fi

  # 3. Check if a worktree was already created for this session
  if state_exists "$session_id"; then
    local saved_path
    saved_path="$(load_worktree_path "$session_id")"

    if [[ -n "$saved_path" && -d "$saved_path" ]]; then
      # Check if cwd is already inside the worktree
      case "$cwd" in
        "${saved_path}"*)
          # We're inside the worktree → allow
          exit 0
          ;;
        *)
          # Worktree exists but Claude hasn't cd'd there yet → re-remind
          local saved_branch
          saved_branch="$(load_branch_name "$session_id")"
          echo "A worktree has already been created for this session but you are not in it." >&2
          echo "" >&2
          echo "Worktree path: ${saved_path}" >&2
          echo "Branch: ${saved_branch}" >&2
          echo "" >&2
          echo "Please change to the worktree directory first:" >&2
          echo "  cd ${saved_path}" >&2
          echo "" >&2
          echo "Then retry your action." >&2
          exit 2
          ;;
      esac
    else
      # State file exists but worktree directory is gone → clean up and recreate
      remove_state "$session_id"
    fi
  fi

  # 4. For Bash tool, check if the command is read-only
  if [[ "$tool_name" == "Bash" ]]; then
    local bash_command
    bash_command="$(parse_json_field "$input" '.tool_input.command')"
    if [[ -n "$bash_command" ]] && ! is_mutating_command "$bash_command"; then
      exit 0
    fi
  fi

  # 5. Create a new worktree
  local repo_root
  repo_root="$(get_main_repo_root "$cwd")"
  if [[ -z "$repo_root" ]]; then
    # Can't determine repo root → allow (fail open)
    exit 0
  fi

  local branch_name
  branch_name="$(generate_branch_name "$session_id")"

  local worktree_base
  worktree_base="$(get_worktree_base_dir "$repo_root")"

  local worktree_path="${worktree_base}/${branch_name}"

  local create_output
  create_output="$(create_worktree "$repo_root" "$branch_name" "$worktree_path" 2>&1)" || {
    echo "Failed to create worktree: ${create_output}" >&2
    # Fail open: allow the action rather than blocking indefinitely
    exit 0
  }

  # 6. Save state
  save_state "$session_id" "$worktree_path" "$branch_name"

  # 7. Block the action and instruct Claude to use the worktree
  echo "Auto-worktree: Created a new git worktree for isolated work." >&2
  echo "" >&2
  echo "  Worktree path: ${worktree_path}" >&2
  echo "  Branch: ${branch_name}" >&2
  echo "" >&2
  echo "Please change to the worktree directory before making any file modifications:" >&2
  echo "  cd ${worktree_path}" >&2
  echo "" >&2
  echo "Then retry your action. All file operations should use paths within that directory." >&2
  exit 2
}

main
