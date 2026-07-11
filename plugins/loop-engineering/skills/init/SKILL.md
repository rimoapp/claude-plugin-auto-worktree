---
name: init
description: Scaffold a complete self-running agent loop into the current repository (Loop Engineering setup). Use when the user asks to "set up the loop", "initialize loop engineering", "ループを構築/導入/セットアップ", "make this repo loop-ready", or invokes /loop-engineering:init. Creates .loop/ state & scripts, repo-local loop-tick/loop-discover skills, builder & verifier subagents, and a scheduler (GitHub Actions / cron / Routines).
---

# Loop Engineering: Init

You are scaffolding the loop architecture from Addy Osmani's "Loop Engineering"
(https://addyosmani.com/blog/loop-engineering/) into the **current repository**.
The result must be **fully self-contained**: after this skill finishes, the repo
runs its loop without this plugin being installed (important for CI).

The architecture you are installing (5 primitives + memory):

1. **Automations** — a scheduler fires one "tick" per cadence (heartbeat).
2. **Worktrees** — the builder works in an isolated worktree/branch so parallel work never collides.
3. **Skills** — project knowledge and the tick algorithm live in repo-local skills, not in anyone's head.
4. **Connectors** — `gh` CLI (and any MCP the repo already has) lets the loop open PRs and read issues/CI.
5. **Sub-agents** — the **maker** (`loop-builder`) is never the one who grades the work; an adversarial **checker** (`loop-verifier`) is.
6. **Memory** — `.loop/STATE.md` + `.loop/journal/` on disk. The agent forgets between runs; the repo doesn't.

Templates live at: `${CLAUDE_PLUGIN_ROOT}/skills/init/templates/`

## Hard rules

- Interact with the user in **their language** (mirror the language they used).
- Never push, never merge, never touch branch protections, never enable auto-merge.
- Do not overwrite an existing `.loop/` silently — see "Update mode" below.
- Do not invent verify commands. Only include commands that verifiably exist in this repo.
- Keep the whole setup reviewable: at the end, list every file you created so the user can `git diff` before committing. Do NOT commit or push yourself unless the user explicitly asks.

## Procedure

### Step 0 — Preconditions

1. `git rev-parse --show-toplevel` — must be inside a git repo; if not, stop and say so.
2. Detect default branch: `git symbolic-ref refs/remotes/origin/HEAD` (fallback: `main`).
3. If `.loop/` already exists → **Update mode**: show what exists, ask whether to
   (a) regenerate scripts/skills/agents only (preserve `LOOP.md` + `STATE.md` + journal), or
   (b) abort. Never delete `STATE.md` or `journal/`.

### Step 1 — Detect the stack (do not ask what you can detect)

Inspect the repo and derive:

- **Package manager / toolchain**: `pnpm-lock.yaml` → pnpm; `yarn.lock` → yarn; `package-lock.json` → npm; `go.mod` → go; `Cargo.toml` → cargo; `pyproject.toml`/`requirements.txt` → python (uv/poetry/pip + pytest/ruff if configured); `Makefile` → note useful targets.
- **Verify commands**, ordered fast → slow, from real sources only:
  - JS/TS: `package.json` scripts (`lint`, `typecheck`/`tsc`, `test`, `build` — use what exists).
  - Go: `go vet ./...`, `go build ./...`, `go test ./...`.
  - Rust: `cargo clippy -- -D warnings` (if clippy configured), `cargo test`.
  - Python: `ruff check .` (if ruff present), `pytest` (if tests exist).
  - Monorepo: prefer root-level scripts (e.g. `pnpm -r lint`) if that is the repo convention.
- **CI presence**: `.github/workflows/` exists? `gh` CLI available (`command -v gh`)?
- **Existing Claude assets**: `.claude/skills/`, `.claude/agents/`, `CLAUDE.md` — the loop must respect existing conventions; mention them in generated files where relevant.

### Step 2 — Ask only the judgment questions (max ~4, with defaults)

1. **Standing goal** of the loop (one or two sentences). Default:
   "Keep CI green; burn down issues labeled `loop` and high-signal TODO/FIXMEs with small, reviewable PRs."
2. **Scheduler**: GitHub Actions (default, survives laptop close) / local cron via `.loop/bin/tick-local.sh` / Claude Code Routines (`/schedule`, cloud) / none for now (manual `/loop-tick`).
3. **Cadence**: default weekday mornings. If the user gives local time (e.g. JST), convert to UTC for cron and write both in a comment.
4. **Discovery sources** (defaults all on): recent CI runs, open issues labeled `loop`, TODO/FIXME grep, recent commits.

Also confirm the **issue label** (default `loop`) and **branch prefix** (default `loop/`).

### Step 3 — Generate files from templates

Copy each template, substitute `{{PLACEHOLDERS}}`, and adapt intelligently to this repo
(e.g. real verify commands, real setup steps in the workflow, correct package-manager
tool patterns in allowed tools). Target map:

| Template (in `${CLAUDE_PLUGIN_ROOT}/skills/init/templates/`) | Destination in repo |
|---|---|
| `LOOP.md` | `.loop/LOOP.md` |
| `STATE.md` | `.loop/STATE.md` |
| `verify.sh` | `.loop/bin/verify.sh` |
| `discover.sh` | `.loop/bin/discover.sh` |
| `tick-local.sh` | `.loop/bin/tick-local.sh` |
| `skill-loop-tick.md` | `.claude/skills/loop-tick/SKILL.md` |
| `skill-loop-discover.md` | `.claude/skills/loop-discover/SKILL.md` |
| `agent-loop-builder.md` | `.claude/agents/loop-builder.md` |
| `agent-loop-verifier.md` | `.claude/agents/loop-verifier.md` |
| `workflow-loop-tick.yml` | `.github/workflows/loop-tick.yml` (only if scheduler = GitHub Actions) |

Placeholders you must fill everywhere they appear:

- `{{GOAL}}` — the standing goal from Step 2.
- `{{DEFAULT_BRANCH}}`, `{{BRANCH_PREFIX}}` (e.g. `loop/`), `{{LOOP_LABEL}}`.
- `{{VERIFY_STEPS}}` — `step "name"; <command>` lines in verify.sh (real commands only; if a category is missing, omit it and note it in LOOP.md under "Known gaps").
- `{{VERIFY_CMD_SUMMARY}}` — one-line human summary of the gate.
- `{{PM_TOOL_PATTERNS}}` — extra allowed-tool patterns for the toolchain, e.g. `Bash(pnpm:*)` or `Bash(go:*),Bash(gofmt:*)`.
- `{{SETUP_STEPS}}` — real CI setup steps (e.g. pnpm/action-setup + actions/setup-node with the repo's Node version + install). For Go: actions/setup-go. Keep minimal but sufficient for verify.sh to pass in CI.
- `{{CRON}}` / `{{CRON_HUMAN}}` — cron in UTC + human-readable comment incl. local time.
- `{{MAX_FIX_CYCLES}}` — default `3`.
- `{{TODO_PATHS}}` — sensible grep scope (e.g. `":(exclude)node_modules" src` style pathspecs or just `.` for small repos).
- `{{DISCOVERY_SOURCES}}` — comma-separated list of the sources chosen in Step 2.
- `{{KNOWN_GAPS}}` — honest notes on what the gate can't catch here (e.g. "no typecheck script exists"), or "none".
- `{{REPO_ABS_PATH}}` — absolute repo path (used only in tick-local.sh's crontab example comment).

Then `chmod +x .loop/bin/*.sh`.

### Step 4 — Seed the loop so the first tick has work

1. Run `bash .loop/bin/discover.sh` and show the report.
2. Triage it yourself: pick 1–3 genuinely worthwhile items and write them into
   `.loop/STATE.md` → `## Backlog` in the specified item format, each with a stable id
   (`L-001`, `L-002`, …), source, and concrete acceptance criteria.
3. Offer to run `bash .loop/bin/verify.sh` once now so the user sees the gate pass
   (or learns immediately that it doesn't — fix the script, not the repo, in that case).

### Step 5 — Hand off

Print, in the user's language:

1. The list of created files (tree).
2. Next steps:
   - Review with `git diff` / `git status`, then commit.
   - **First tick supervised**: run `/loop-tick` interactively once and watch it end-to-end before enabling the schedule. (Osmani: verification stays your job — "done" is a claim, not a proof.)
   - If GitHub Actions: add repo secret `ANTHROPIC_API_KEY`, push, then trigger once via `workflow_dispatch`. Note: PRs opened with the default `github.token` do not trigger other workflows; use a PAT/GitHub App token in the workflow if loop PRs must run CI.
   - If cron: show the crontab line from `tick-local.sh`'s header comment.
   - If Routines: suggest `/schedule` with prompt `/loop-tick` on the chosen cadence (cloud-side; repo must be pushed).
3. Budget reminder: the loop does **one item per tick** and at most `{{MAX_FIX_CYCLES}}` fix cycles by design — widen budgets in `.loop/LOOP.md` only after several clean weeks.
