---
name: loop-discover
description: Discovery + triage only — refresh this repository's loop Backlog without building anything. Use for a cheap, more frequent cadence than full ticks, or when asked "what should the loop work on", "バックログを更新して", or invoked as /loop-discover.
---

# Loop Discover — surface the work, don't do it

Cheap half of the loop: read signals, apply judgment, update memory. **Never build,
never branch, never open PRs** — that's `/loop-tick`'s job.

1. Read `.loop/LOOP.md` (scope) and `.loop/STATE.md` (what's already tracked).
2. Run `bash .loop/bin/discover.sh` and read the report.
3. Triage: for each signal that is real, small, and in scope, add a Backlog item in the
   STATE.md item format (fresh sequential id, source, **concrete acceptance criteria**).
   Dedupe against all existing items in every section. Re-order Backlog by priority:
   broken CI > `{{LOOP_LABEL}}` issues > TODO/FIXME.
4. Anything interesting but out of scope / needing judgment → `## Triage Inbox` instead.
5. Append a short entry to today's `.loop/journal/` file: `discover: +N items, top: L-xxx`.
6. Report to the user (or, headlessly, to the journal): what was added, what was skipped
   and why, and what the next `/loop-tick` will most likely pick up.
