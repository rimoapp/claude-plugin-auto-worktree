#!/usr/bin/env bash
# Manual cleanup utility for auto-worktree plugin.
# Lists worktrees created by the plugin and offers to remove them.
#
# Usage:
#   ./cleanup.sh           # Interactive mode: list and confirm removal
#   ./cleanup.sh --force   # Non-interactive: remove all plugin worktrees
#   ./cleanup.sh --list    # List only, no removal
#   ./cleanup.sh --merged  # Remove only worktrees whose branches are merged

set -euo pipefail

BRANCH_PREFIX="worktree-"

usage() {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo ""
  echo "Clean up git worktrees created by the auto-worktree plugin."
  echo ""
  echo "Options:"
  echo "  --list     List all plugin worktrees without removing"
  echo "  --merged   Remove only worktrees with branches merged into HEAD"
  echo "  --force    Remove all plugin worktrees without confirmation"
  echo "  --help     Show this help message"
}

main() {
  local mode="interactive"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)   mode="list"; shift ;;
      --merged) mode="merged"; shift ;;
      --force)  mode="force"; shift ;;
      --help)   usage; exit 0 ;;
      *)        echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  # Ensure we're in a git repo
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: Not inside a git repository." >&2
    exit 1
  fi

  # List worktrees
  local worktree_count=0
  local worktrees=()
  local branches=()

  while IFS= read -r line; do
    local wt_path wt_branch
    wt_path="$(echo "$line" | awk '{print $1}')"
    wt_branch="$(echo "$line" | sed -n 's/.*\[\(.*\)\].*/\1/p')"

    # Only process worktrees created by this plugin
    if [[ "$wt_branch" == ${BRANCH_PREFIX}* ]]; then
      worktrees+=("$wt_path")
      branches+=("$wt_branch")
      worktree_count=$((worktree_count + 1))
    fi
  done < <(git worktree list 2>/dev/null)

  if [[ $worktree_count -eq 0 ]]; then
    echo "No auto-worktree worktrees found."
    exit 0
  fi

  echo "Found ${worktree_count} auto-worktree worktree(s):"
  echo ""

  for i in "${!worktrees[@]}"; do
    local wt_path="${worktrees[$i]}"
    local wt_branch="${branches[$i]}"
    local last_commit merged_status status_info

    last_commit="$(git -C "$wt_path" log -1 --format='%cr' 2>/dev/null || echo 'unknown')"

    if git merge-base --is-ancestor "$wt_branch" HEAD 2>/dev/null; then
      merged_status="merged"
    else
      merged_status="not merged"
    fi

    local dirty=""
    if [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]]; then
      dirty=" [uncommitted changes]"
    fi

    echo "  $((i + 1)). ${wt_path}"
    echo "     Branch: ${wt_branch} (${merged_status})"
    echo "     Last commit: ${last_commit}${dirty}"
    echo ""
  done

  if [[ "$mode" == "list" ]]; then
    exit 0
  fi

  # Determine which worktrees to remove
  local to_remove=()

  if [[ "$mode" == "merged" ]]; then
    for i in "${!worktrees[@]}"; do
      if git merge-base --is-ancestor "${branches[$i]}" HEAD 2>/dev/null; then
        to_remove+=("$i")
      fi
    done
    if [[ ${#to_remove[@]} -eq 0 ]]; then
      echo "No merged worktrees to remove."
      exit 0
    fi
  elif [[ "$mode" == "force" ]]; then
    for i in "${!worktrees[@]}"; do
      to_remove+=("$i")
    done
  else
    # Interactive mode
    echo "Enter numbers to remove (space-separated), 'all' to remove all, or 'q' to quit:"
    read -r selection

    if [[ "$selection" == "q" ]]; then
      echo "Cancelled."
      exit 0
    fi

    if [[ "$selection" == "all" ]]; then
      for i in "${!worktrees[@]}"; do
        to_remove+=("$i")
      done
    else
      for num in $selection; do
        local idx=$((num - 1))
        if [[ $idx -ge 0 && $idx -lt $worktree_count ]]; then
          to_remove+=("$idx")
        fi
      done
    fi
  fi

  # Remove selected worktrees
  for idx in "${to_remove[@]}"; do
    local wt_path="${worktrees[$idx]}"
    local wt_branch="${branches[$idx]}"

    echo "Removing worktree: ${wt_path} (${wt_branch})..."
    git worktree remove "$wt_path" --force 2>/dev/null || {
      echo "  Warning: Could not remove worktree at ${wt_path}. Trying manual cleanup..." >&2
      rm -rf "$wt_path"
      git worktree prune
    }

    # Delete the branch if it still exists
    git branch -D "$wt_branch" 2>/dev/null || true
    echo "  Done."
  done

  echo ""
  echo "Cleanup complete."
}

main "$@"
