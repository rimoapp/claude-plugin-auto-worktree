#!/usr/bin/env bash
# Git worktree detection helpers for auto-worktree plugin.

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
