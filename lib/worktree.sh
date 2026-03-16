#!/usr/bin/env bash
# Git worktree operations for auto-worktree plugin.

# Check if the given directory is inside a non-main git worktree.
# Arguments: $1 = directory path
# Returns: 0 if inside a linked worktree, 1 if in main repo or not a git repo.
is_inside_worktree() {
  local dir="$1"
  local git_dir
  git_dir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null)" || return 1

  # Linked worktrees have a git-dir path containing "/worktrees/"
  if [[ "$git_dir" == *"/worktrees/"* ]]; then
    return 0
  fi

  # Also check if .git is a gitfile (file pointing to actual git dir)
  local dot_git="${dir}/.git"
  if [[ -f "$dot_git" ]]; then
    return 0
  fi

  return 1
}

# Check if the given directory is inside any git repository.
# Arguments: $1 = directory path
# Returns: 0 if inside a git repo, 1 otherwise.
is_git_repo() {
  local dir="$1"
  git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null
}

# Get the toplevel directory of the main repository.
# If inside a worktree, resolves back to the main repo root.
# Arguments: $1 = directory path
# Outputs: absolute path to the main repo root.
get_main_repo_root() {
  local dir="$1"
  local git_common_dir
  git_common_dir="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)" || return 1

  # --git-common-dir gives the path to the shared .git directory.
  # The main repo root is the parent of that directory.
  local abs_common_dir
  abs_common_dir="$(cd "$dir" && cd "$git_common_dir" && pwd)"
  dirname "$abs_common_dir"
}

# Get the toplevel directory of the current working tree (may be a worktree).
# Arguments: $1 = directory path
# Outputs: absolute path to the current worktree root.
get_worktree_root() {
  local dir="$1"
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null
}

# Compute the base directory for worktrees.
# Convention: sibling to the main repo, named "<repo>-worktrees".
# Arguments: $1 = main repo root
# Outputs: absolute path to the worktrees base directory.
get_worktree_base_dir() {
  local repo_root="$1"
  local repo_name
  repo_name="$(basename "$repo_root")"
  echo "$(dirname "$repo_root")/${repo_name}-worktrees"
}

# Create a new git worktree with a new branch.
# Arguments: $1 = main repo root, $2 = branch name, $3 = worktree path
# Returns: 0 on success, non-zero on failure.
create_worktree() {
  local repo_root="$1"
  local branch_name="$2"
  local worktree_path="$3"

  mkdir -p "$(dirname "$worktree_path")"
  git -C "$repo_root" worktree add "$worktree_path" -b "$branch_name" 2>&1
}

# Generate a unique branch name for a new worktree.
# Format: worktree/<YYYYMMDD-HHMMSS>-<session_id_prefix>
# Arguments: $1 = session_id
# Outputs: branch name string.
generate_branch_name() {
  local session_id="$1"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local short_id
  short_id="$(echo "$session_id" | head -c 8)"
  # Add nanoseconds or random suffix for uniqueness within the same second
  local suffix
  if date +%N &>/dev/null && [[ "$(date +%N)" != "N" ]]; then
    suffix="$(date +%N | head -c 4)"
  else
    suffix="$$"
  fi
  echo "worktree/${timestamp}-${short_id}-${suffix}"
}
