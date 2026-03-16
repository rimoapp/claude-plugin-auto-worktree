# claude-plugin-auto-worktree

A Claude Code plugin that automatically creates git worktrees when Claude modifies files, enabling safe parallel work without git conflicts.

## Problem

When multiple Claude Code sessions work on the same repository simultaneously, file modifications can conflict. Non-engineers who aren't familiar with git branching may lose work or encounter confusing merge conflicts.

## Solution

This plugin intercepts file-modifying tool calls (`Write`, `Edit`, `Bash`) via a `PreToolUse` hook. The moment Claude tries to modify a file, the plugin:

1. Creates a new git worktree on a unique branch
2. Blocks the modification
3. Instructs Claude to `cd` into the worktree and retry

Each Claude session gets its own isolated worktree and branch, so parallel sessions never conflict.

## Installation

### Local testing

```bash
claude --plugin-dir /path/to/claude-plugin-auto-worktree
```

### Project-level installation

Add to your project's `.claude/settings.json`:

```json
{
  "plugins": ["/path/to/claude-plugin-auto-worktree"]
}
```

## How It Works

```
User starts Claude in main repo
         │
         ▼
Claude tries to Write/Edit a file
         │
         ▼
PreToolUse hook intercepts ──────── Already in a worktree? → Allow
         │
         ▼
Creates git worktree on new branch
(worktree/<YYYYMMDD-HHMMSS>-<session_id>)
         │
         ▼
Blocks action + tells Claude to "cd <worktree_path>"
         │
         ▼
Claude retries in the worktree → All subsequent operations happen there
         │
         ▼
Session ends → Stop hook prints summary (branch, uncommitted changes)
```

### Worktree Location

Worktrees are created as siblings to the main repository:

```
parent-directory/
├── my-project/                          # Main repo
├── my-project-worktrees/
│   ├── worktree/20260316-143022-abc123/ # Session 1
│   └── worktree/20260316-143045-def456/ # Session 2
```

### Bash Command Filtering

The plugin uses a heuristic to distinguish read-only Bash commands (which are allowed) from file-modifying commands (which trigger worktree creation):

- **Allowed**: `ls`, `cat`, `grep`, `git status`, `git log`, `echo hello`, etc.
- **Intercepted**: `touch`, `mv`, `cp`, `rm`, `sed -i`, `npm install`, `>`, `>>`, etc.

## Cleanup

Remove old worktrees using the included utility:

```bash
# List all plugin worktrees
./cleanup.sh --list

# Interactive removal
./cleanup.sh

# Remove only merged worktrees
./cleanup.sh --merged

# Remove all plugin worktrees
./cleanup.sh --force
```

Or manually:

```bash
git worktree list          # See all worktrees
git worktree remove <path> # Remove a specific worktree
git worktree prune         # Clean up stale references
```

## File Structure

```
claude-plugin-auto-worktree/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── hooks/
│   ├── hooks.json           # Hook definitions
│   ├── pre-tool-use.sh      # Main hook: intercept, create worktree, redirect
│   └── stop.sh              # Session end summary
├── lib/
│   ├── worktree.sh          # Git worktree operations
│   ├── state.sh             # Session state tracking
│   └── bash-filter.sh       # Mutation detection heuristic
├── tests/
│   ├── run-tests.sh         # Test runner
│   ├── test-bash-filter.sh  # Mutation detection tests
│   ├── test-worktree.sh     # Worktree operation tests
│   ├── test-state.sh        # State management tests
│   ├── test-pre-tool-use.sh # Integration tests
│   └── test-stop.sh         # Stop hook tests
├── cleanup.sh               # Worktree cleanup utility
├── LICENSE
└── README.md
```

## Running Tests

```bash
bash tests/run-tests.sh
```

## Requirements

- `git` 2.5+ (worktree support)
- `jq` (preferred) or `python3` (fallback) for JSON parsing
- `bash` 4+

## License

MIT
