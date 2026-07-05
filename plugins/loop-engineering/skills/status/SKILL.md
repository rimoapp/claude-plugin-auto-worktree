---
name: status
description: Report the state and health of this repository's engineering loop. Use when the user asks "how is the loop doing", "loop status", "ループの状況/様子は", or invokes /loop-engineering:status.
---

# Loop Status

Give the human their morning briefing on the loop. Read-only — change nothing.

If `.loop/` does not exist, say the loop isn't set up here yet and point to
`/loop-engineering:init`. Otherwise:

## 1. State summary (from `.loop/STATE.md`)

- Counts per section: Backlog / In Progress / Awaiting Review / Done / Triage Inbox.
- **Triage Inbox first and loudest** — that's the queue that needs a human, with each
  item's FAIL reasons in one line.
- Awaiting Review: for each item with a PR, check it live if `gh` is available
  (`gh pr view <url> --json state,statusCheckRollup`) and flag merged ones that should
  move to Done (offer to move them).
- A dangling In Progress item = a crashed run; flag it clearly.

## 2. Last activity (from `.loop/journal/`)

- Most recent journal entry: when the last tick ran, what it selected, verdict, PR link.
- If the newest entry is much older than the configured cadence, say the heartbeat looks
  dead and suggest where to look (Actions run history / crontab / Routines dashboard).

## 3. Health checks (best-effort, non-fatal)

- `.loop/bin/verify.sh`, `discover.sh`, `tick-local.sh` exist and are executable.
- `.claude/skills/loop-tick/`, `.claude/skills/loop-discover/`,
  `.claude/agents/loop-builder.md`, `.claude/agents/loop-verifier.md` exist.
- `.github/workflows/loop-tick.yml` exists (if GitHub Actions was chosen) — remind that
  `ANTHROPIC_API_KEY` must be set as a repo secret (you cannot verify secrets; say so).
- `gh` CLI available and authenticated (`gh auth status`)?

## 4. Verdict

One short paragraph in the user's language: is the loop healthy, what needs the human's
attention today, and the single most valuable next action.
