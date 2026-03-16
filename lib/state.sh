#!/usr/bin/env bash
# Session state management for auto-worktree plugin.
# Tracks which worktree was created for each Claude session.

STATE_DIR="${STATE_DIR:-/tmp/claude-auto-worktree}"

_ensure_state_dir() {
  mkdir -p "$STATE_DIR"
}

# Get the state file path for a given session ID.
# Arguments: $1 = session_id
get_state_file() {
  local session_id="$1"
  echo "${STATE_DIR}/session-${session_id}"
}

# Save worktree path and branch to the session state file.
# Arguments: $1 = session_id, $2 = worktree_path, $3 = branch_name
save_state() {
  local session_id="$1"
  local worktree_path="$2"
  local branch_name="$3"
  _ensure_state_dir
  local state_file
  state_file="$(get_state_file "$session_id")"
  printf '%s\n%s\n' "$worktree_path" "$branch_name" > "$state_file"
}

# Load worktree path from the session state file.
# Arguments: $1 = session_id
# Outputs: worktree_path on stdout, or empty if no state exists.
load_worktree_path() {
  local session_id="$1"
  local state_file
  state_file="$(get_state_file "$session_id")"
  if [[ -f "$state_file" ]]; then
    sed -n '1p' "$state_file"
  fi
}

# Load branch name from the session state file.
# Arguments: $1 = session_id
# Outputs: branch_name on stdout, or empty if no state exists.
load_branch_name() {
  local session_id="$1"
  local state_file
  state_file="$(get_state_file "$session_id")"
  if [[ -f "$state_file" ]]; then
    sed -n '2p' "$state_file"
  fi
}

# Check if state exists for a given session.
# Arguments: $1 = session_id
# Returns: 0 if state exists, 1 otherwise.
state_exists() {
  local session_id="$1"
  local state_file
  state_file="$(get_state_file "$session_id")"
  [[ -f "$state_file" ]]
}

# Remove state file for a given session.
# Arguments: $1 = session_id
remove_state() {
  local session_id="$1"
  local state_file
  state_file="$(get_state_file "$session_id")"
  rm -f "$state_file"
}
