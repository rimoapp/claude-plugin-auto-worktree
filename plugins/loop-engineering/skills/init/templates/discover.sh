#!/usr/bin/env bash
# .loop/bin/discover.sh — cheap, deterministic signal collection for the Discover phase.
# Prints a markdown report to stdout. Judgment/triage happens in the loop-discover /
# loop-tick skills, not here. Every section is best-effort; missing tools never fail the run.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "# Loop discovery report — $(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo
echo "## Recent commits"
git log --oneline -n 10 || true

echo
echo "## CI — latest runs"
if command -v gh >/dev/null 2>&1; then
  gh run list --limit 10 2>/dev/null || echo "(gh run list unavailable — no auth or no Actions)"
else
  echo "(gh not installed)"
fi

echo
echo "## Open issues labeled '{{LOOP_LABEL}}'"
if command -v gh >/dev/null 2>&1; then
  gh issue list --label "{{LOOP_LABEL}}" --limit 20 2>/dev/null || echo "(gh issue list unavailable)"
else
  echo "(gh not installed)"
fi

echo
echo "## TODO / FIXME (top 30)"
git grep -nE "TODO|FIXME" -- {{TODO_PATHS}} 2>/dev/null | head -30 || echo "(none found)"

echo
echo "## Working tree"
git status --short || true
