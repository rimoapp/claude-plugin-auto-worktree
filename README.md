# claude-plugin-auto-worktree

A Claude Code plugin that automatically redirects Claude into a git worktree before modifying files, enabling safe parallel work without git conflicts.

## Problem

When multiple Claude Code sessions work on the same repository simultaneously, file modifications can conflict. Non-engineers who aren't familiar with git branching may lose work or encounter confusing merge conflicts.

## Solution

This plugin intercepts file-modifying tool calls (`Write`, `Edit`, `Bash`) via a `PreToolUse` hook. The moment Claude tries to modify a file in the main repository, the plugin:

1. Blocks the modification (exit code 2)
2. Instructs Claude to call the built-in `EnterWorktree` tool
3. Claude creates an isolated worktree and retries the action there

Each Claude session gets its own isolated worktree and branch, so parallel sessions never conflict.

## Installation

### From GitHub (recommended)

In Claude Code, run:

```
/plugin marketplace add github:rimoapp/claude-plugin-auto-worktree
/plugin install auto-worktree@rimoapp-plugins
```

Once installed, the plugin persists across sessions. You can enable/disable it anytime:

```
/plugin disable auto-worktree@rimoapp-plugins
/plugin enable auto-worktree@rimoapp-plugins
```

### From local directory

For development or testing:

```bash
claude --plugin-dir /path/to/claude-plugin-auto-worktree
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
Blocks action (exit 2) + tells Claude to call EnterWorktree
         │
         ▼
Claude calls EnterWorktree → creates .claude/worktrees/<name>/
         │
         ▼
Claude retries in the worktree → All subsequent operations happen there
         │
         ▼
Session ends → Stop hook prints summary (branch, uncommitted changes)
```

### Worktree Location

Worktrees are created by Claude Code's built-in `EnterWorktree` tool inside the repository:

```
my-project/
├── .claude/
│   └── worktrees/
│       ├── humble-prancing-conway/    # Session 1
│       └── brave-dancing-turing/      # Session 2
├── src/
└── ...
```

Each worktree gets a branch named `worktree-<session-name>`.

### Bash Command Filtering

The plugin uses a heuristic to distinguish read-only Bash commands (which are allowed) from file-modifying commands (which trigger worktree redirection):

- **Allowed**: `ls`, `cat`, `grep`, `git status`, `git log`, `echo hello`, etc.
- **Intercepted**: `touch`, `mv`, `cp`, `rm`, `sed -i`, `npm install`, `>`, `>>`, etc.

## Cleanup

Worktree cleanup is handled by Claude Code's built-in `ExitWorktree` tool. When a session ends while in a worktree, the user is prompted to keep or remove it.

For manual cleanup:

```bash
git worktree list          # See all worktrees
git worktree remove <path> # Remove a specific worktree
git worktree prune         # Clean up stale references
```

## File Structure

```
claude-plugin-auto-worktree/
├── .claude-plugin/
│   ├── marketplace.json     # Marketplace definition
│   └── plugin.json          # Plugin manifest
├── hooks/
│   ├── hooks.json           # Hook definitions
│   ├── pre-tool-use.sh      # Main hook: block and redirect to EnterWorktree
│   └── stop.sh              # Session end summary
├── lib/
│   ├── worktree.sh          # Git worktree detection helpers
│   └── bash-filter.sh       # Mutation detection heuristic
├── tests/
│   ├── run-tests.sh         # Test runner
│   ├── test-bash-filter.sh  # Mutation detection tests
│   ├── test-worktree.sh     # Worktree detection tests
│   ├── test-pre-tool-use.sh # Integration tests
│   └── test-stop.sh         # Stop hook tests
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
- `perl` (for regex matching in bash-filter)

## License

MIT
