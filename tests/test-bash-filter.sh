#!/usr/bin/env bash
# Tests for lib/bash-filter.sh — mutation detection heuristic.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PLUGIN_ROOT}/lib/bash-filter.sh"

PASS=0
FAIL=0

assert_mutating() {
  local cmd="$1"
  local desc="${2:-$cmd}"
  if is_mutating_command "$cmd"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: Expected mutating: ${desc}" >&2
  fi
}

assert_readonly() {
  local cmd="$1"
  local desc="${2:-$cmd}"
  if ! is_mutating_command "$cmd"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: Expected read-only: ${desc}" >&2
  fi
}

# --- Mutating commands ---
assert_mutating 'echo "hello" > file.txt' "redirect to file"
assert_mutating 'echo "hello" >> file.txt' "append to file"
assert_mutating 'cat data | tee output.txt' "tee command"
assert_mutating 'sed -i "s/foo/bar/" file.txt' "sed in-place"
assert_mutating 'perl -i -pe "s/foo/bar/" file.txt' "perl in-place"
assert_mutating 'mv old.txt new.txt' "mv command"
assert_mutating 'cp src.txt dst.txt' "cp command"
assert_mutating 'rm file.txt' "rm command"
assert_mutating 'rm -rf /tmp/test' "rm -rf command"
assert_mutating 'mkdir -p /tmp/newdir' "mkdir command"
assert_mutating 'touch newfile.txt' "touch command"
assert_mutating 'chmod +x script.sh' "chmod command"
assert_mutating 'chown user:group file.txt' "chown command"
assert_mutating 'git add .' "git add"
assert_mutating 'git commit -m "test"' "git commit"
assert_mutating 'git push origin main' "git push"
assert_mutating 'npm install express' "npm install"
assert_mutating 'npm i lodash' "npm i"
assert_mutating 'pip install requests' "pip install"
assert_mutating 'yarn add react' "yarn add"
assert_mutating 'ln -s /src /dst' "ln symlink"
assert_mutating 'patch -p1 < fix.patch' "patch command"
assert_mutating 'truncate -s 0 logfile.txt' "truncate command"
assert_mutating 'install -m 755 mybin /usr/local/bin/' "install command"
assert_mutating 'git checkout feature-branch' "git checkout"
assert_mutating 'git reset --hard HEAD~1' "git reset"
assert_mutating 'git merge main' "git merge"
assert_mutating 'git rebase main' "git rebase"
assert_mutating 'git stash' "git stash"
assert_mutating 'pip3 install flask' "pip3 install"
assert_mutating 'npm ci' "npm ci"
assert_mutating 'npm uninstall express' "npm uninstall"
assert_mutating 'yarn install' "yarn install"
assert_mutating 'yarn remove react' "yarn remove"
assert_mutating 'cargo install ripgrep' "cargo install"
assert_mutating 'go install golang.org/x/tools/gopls@latest' "go install"
assert_mutating 'brew install jq' "brew command"
assert_mutating 'apt-get install -y curl' "apt-get install"

# --- Chained/piped commands with mutating parts ---
assert_mutating 'ls -la && touch newfile.txt' "chained with mutating"
assert_mutating 'cat file.txt | tee output.log' "pipe to tee"
assert_mutating 'echo "data" > result.txt' "echo with redirect to file"

# --- Read-only commands ---
assert_readonly 'ls -la' "ls"
assert_readonly 'cat file.txt' "cat"
assert_readonly 'grep -r "pattern" .' "grep"
assert_readonly 'git status' "git status"
assert_readonly 'git log --oneline' "git log"
assert_readonly 'git diff' "git diff"
assert_readonly 'echo hello' "echo without redirect"
assert_readonly 'pwd' "pwd"
assert_readonly 'whoami' "whoami"
assert_readonly 'head -10 file.txt' "head"
assert_readonly 'tail -20 file.txt' "tail"
assert_readonly 'wc -l file.txt' "wc"
assert_readonly 'find . -name "*.txt"' "find"
assert_readonly 'git branch -a' "git branch list"
assert_readonly 'npm list' "npm list"
assert_readonly 'node -e "console.log(1)"' "node eval"
assert_readonly 'diff file1.txt file2.txt' "diff command"
assert_readonly 'git show HEAD' "git show"
assert_readonly 'git remote -v' "git remote list"
assert_readonly 'python3 -c "print(1)"' "python3 eval"
assert_readonly 'which jq' "which command"
assert_readonly 'env' "env command"
assert_readonly 'tree src/' "tree command"

# --- Edge cases ---
assert_readonly 'echo "test" > /dev/null' "redirect to /dev/null"
assert_readonly 'command 2>&1' "stderr redirect only"
assert_readonly '  ls -la' "leading whitespace preserved as read-only"
assert_mutating '  touch foo.txt' "leading whitespace with mutating command"

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
