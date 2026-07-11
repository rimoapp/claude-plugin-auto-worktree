#!/usr/bin/env bash
# .loop/bin/tick-local.sh — run ONE loop tick headlessly on this machine.
#
# Manual:   bash .loop/bin/tick-local.sh
# Cron:     run `crontab -e` and add (weekday 06:00 example — adjust):
#           0 6 * * 1-5  cd {{REPO_ABS_PATH}} && bash .loop/bin/tick-local.sh >> .loop/journal/cron.log 2>&1
# In-session alternative (Claude Code): `/loop 24h /loop-tick` (session-scoped scheduling).
# Durable alternatives: GitHub Actions workflow (.github/workflows/loop-tick.yml)
#                       or Claude Code Routines: `/schedule` with prompt `/loop-tick`.
#
# NOTE on permissions: --allowedTools below is a least-privilege starting set.
# If a tick gets stuck asking for permission it can't receive headlessly, check the
# journal, then widen the list deliberately. `--dangerously-skip-permissions` also
# exists but removes every guardrail — not recommended for an unattended loop.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
mkdir -p .loop/journal

exec claude -p "/loop-tick" \
  --permission-mode acceptEdits \
  --allowedTools "Read,Edit,Write,Glob,Grep,Task,Bash(git:*),Bash(gh:*),Bash(bash:*),{{PM_TOOL_PATTERNS}}" \
  --max-turns 60
