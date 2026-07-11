---
name: loop-tick
description: Run ONE iteration of this repository's engineering loop — discover → select → build (isolated) → verify (independent) → persist. Use when asked to "run the loop", "tick", "ループを回して", or when invoked by the scheduler (/loop-tick).
---

# Loop Tick — one iteration, five phases

You are the orchestrator of this repo's loop. Policy is `.loop/LOOP.md` (binding — read it
first, every run). Memory is `.loop/STATE.md` + `.loop/journal/`. You do exactly **one item**
per tick, then stop; the scheduler is the heartbeat, not you.

Maker/checker separation is non-negotiable: the `loop-builder` agent writes the change,
the `loop-verifier` agent judges it. You (the orchestrator) never write application code
yourself and never skip the verifier.

## Phase 0 — Wake up

1. Read `.loop/LOOP.md` and `.loop/STATE.md`.
2. If `## In Progress` is non-empty, a previous run crashed: inspect its branch, journal
   what you find, then either resume it as this tick's item or move it to Triage Inbox
   with a note. Never leave it dangling.
3. Create today's journal file `.loop/journal/$(date -u +%Y-%m-%d).md` if missing; append
   a `## Tick <UTC time>` heading.

## Phase 1 — Discover & triage

1. Run `bash .loop/bin/discover.sh` and read the report.
2. Apply judgment (this is the part a cron job can't do): which signals are real, small,
   and in scope per LOOP.md? Convert those into Backlog items in the STATE.md item format
   with fresh sequential ids and **concrete acceptance criteria**. Dedupe against every
   existing item in any section.
3. If the Backlog is empty and discovery found nothing worth doing: journal
   `result: no-op (nothing to do)` and **stop cleanly**. A quiet tick is a successful tick.

## Phase 2 — Select

Pick exactly ONE Backlog item, priority order: broken CI on `{{DEFAULT_BRANCH}}` >
issues labeled `{{LOOP_LABEL}}` > TODO/FIXME cleanups. Skip anything that would violate
scope, budgets, or human gates.

## Phase 3 — Build (isolated)

1. **Persist first**: move the item to `## In Progress` in STATE.md and journal
   `selected: L-xxx <title>` — before any code changes, so a crash is always recoverable.
2. Delegate to the **loop-builder** agent (it runs in an isolated worktree). Hand it:
   the item line verbatim, the acceptance criteria, the branch name to create
   (`{{BRANCH_PREFIX}}<id>-<kebab-slug>` off `{{DEFAULT_BRANCH}}`), and the reminder that
   `.loop/bin/verify.sh` must pass before it returns.
3. The builder returns a report: branch, files changed, summary, verify tail.
   (If worktree creation fails in a constrained environment such as CI, the builder
   falls back to a plain branch — acceptable, since CI runs one tick at a time.)

## Phase 4 — Verify (independent)

1. Delegate to the **loop-verifier** agent with: the branch name, the item + acceptance
   criteria, and the builder's summary. The verifier assumes the change is broken,
   re-runs the gate itself, reads the full diff, and returns `VERDICT: PASS` or
   `VERDICT: FAIL` with reasons.
2. On FAIL: send the reasons back to loop-builder for a fix cycle. Maximum
   {{MAX_FIX_CYCLES}} cycles total. Still failing after that → **abandon**: leave the
   branch unpushed, move the item to `## Triage Inbox` with the verifier's reasons,
   journal it, and stop.

## Phase 5 — Persist & stop

On PASS:

1. Push the branch: `git push -u origin <branch>`.
2. Open a PR against `{{DEFAULT_BRANCH}}`:
   `gh pr create --base {{DEFAULT_BRANCH}} --head <branch> --title "loop(<id>): <title>" --body <body>`
   — body must include: the item + acceptance criteria, what changed and why, verifier's
   verdict summary, and the verify.sh tail. Never merge it. Never enable auto-merge.
3. STATE.md: move the item to `## Awaiting Review` with ` | pr: <url>` appended.
   Also, check whether any previous `## Awaiting Review` PRs were merged
   (`gh pr view <url> --json state,mergedAt`) and move merged ones to `## Done`.
4. Journal: discovered summary (1–2 lines), selected item, fix cycles used, verdict,
   PR URL. Keep it terse — the journal is for humans and future ticks, not a transcript.
5. Stop. One item per tick, always.

## Never (restating LOOP.md's human gates — these override everything)

Merge PRs · push to `{{DEFAULT_BRANCH}}` · force-push · deploy · add dependencies ·
delete others' branches · edit `.loop/LOOP.md` · erase STATE.md history.
