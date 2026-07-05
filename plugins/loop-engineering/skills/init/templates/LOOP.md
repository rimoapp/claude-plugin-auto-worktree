# LOOP.md — Loop Policy (the constitution of this repo's loop)

> Read by every loop run before doing anything. Humans edit this file; the loop never does.
> Architecture: Addy Osmani, "Loop Engineering" — https://addyosmani.com/blog/loop-engineering/

## Goal

{{GOAL}}

## Scope

- Discovery sources: {{DISCOVERY_SOURCES}}
- Issue label the loop may pick up: `{{LOOP_LABEL}}`
- Areas the loop may touch: application code, tests, docs, CI config for the loop itself.
- Areas the loop must NOT touch: secrets, infrastructure/deploy config, dependency major upgrades,
  database migrations, license files, `.loop/LOOP.md` (this file), human-authored sections of README.

## Definition of Done (per item)

1. `.loop/bin/verify.sh` exits 0 — this is the only gate that counts. ({{VERIFY_CMD_SUMMARY}})
2. The diff is minimal and does only what the item's acceptance criteria say.
3. `loop-verifier` (an agent that did NOT write the change) returns `VERDICT: PASS`.
4. A PR is opened against `{{DEFAULT_BRANCH}}` from a `{{BRANCH_PREFIX}}` branch.
5. `.loop/STATE.md` and `.loop/journal/` are updated.

"Done" is a claim, not a proof — a human reviews and merges every PR.

## Budgets (safety rails; widen only after weeks of clean runs)

| Budget | Value |
|---|---|
| Items per tick | 1 |
| Verify→fix cycles per item | {{MAX_FIX_CYCLES}} (then abandon → Triage Inbox) |
| Diff size guidance | prefer < ~300 changed lines; split larger work into follow-up backlog items |
| New dependencies | 0 without human approval (put in Triage Inbox instead) |

## Human gates (the loop must NEVER)

- Merge any PR, or enable auto-merge.
- Push to `{{DEFAULT_BRANCH}}` or any non-`{{BRANCH_PREFIX}}` branch. No force-push anywhere.
- Deploy, tag releases, or modify branch protections / repo settings.
- Delete branches it did not create in the current tick.
- Rewrite history in `.loop/STATE.md` (append/move items; never erase the record).

## Escalation

Anything the loop cannot finish within budget, or anything requiring judgment outside scope,
goes to `## Triage Inbox` in `.loop/STATE.md` with the verifier's reasons. That inbox is the
human's morning reading — the loop surfaces work; humans stay the engineers.

## Known gaps

{{KNOWN_GAPS}}
