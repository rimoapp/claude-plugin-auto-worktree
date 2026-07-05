# STATE.md — Loop Memory

> The spine of the loop. The model forgets everything between runs; this file doesn't.
> Machine-updated by `/loop-tick`. Humans may freely edit **Backlog** and **Triage Inbox**.
>
> Item format (one line, keep it grep-able):
> `- [ ] L-000 — <title> | src: <ci|issue#N|todo:path:line|human> | accept: <criteria> | notes: <...>`
> When a PR exists, append ` | pr: <url>`.

## Backlog

<!-- Discovered + triaged work, highest priority first. Seeded by /loop-engineering:init. -->

## In Progress

<!-- At most ONE item. If a run crashed, the next tick must resolve this first. -->

## Awaiting Review

<!-- Verifier passed, PR open, waiting for a human. The loop does not merge. -->

## Done

<!-- Moved here by a human (or by the loop when it observes the PR merged). Append-only. -->

## Triage Inbox (needs a human)

<!-- Abandoned after {{MAX_FIX_CYCLES}} fix cycles, out-of-scope findings, judgment calls. -->
<!-- Each entry keeps the verifier's FAIL reasons so the human starts with context. -->
