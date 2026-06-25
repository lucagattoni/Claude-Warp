---
name: claude-warp-new-goal
description: Scaffold a one-shot bounded goal — GOAL.md state file, G0-G3 readiness check, and a run-once script; use when the task runs once and stops at a verifiable criterion (not a recurring loop)
---

Scaffold a one-shot goal for: `$ARGUMENTS`

If `$ARGUMENTS` is empty, stop immediately and print:
`Usage: /claude-warp-new-goal "one-sentence description of what done looks like"`

Use this skill when the work is **bounded and non-recurring** — a migration,
a refactor, a security scan, a docs update. The goal runs once and stops when
a verifiable criterion is met. For recurring work, use `/claude-warp-new-loop`.
For large multi-stage work that needs a planner, use `/claude-warp-new-harness`.

> "Loops discover work. Goals finish it."

## Phase 1 — Derive goal primitives

Parse `$ARGUMENTS` as a plain-English goal. Derive the Four Goal Primitives:

- `GOAL_NAME` — human-readable name (e.g. "Auth Module Migration")
- `GOAL_SLUG` — kebab-case (e.g. `auth-migration`)
- `OBJECTIVE` — one bounded, verifiable statement of completion
  - Bad: "Improve the auth module"
  - Good: "Migrate to lib/auth/v2; done when all /auth tests pass and zero legacy imports remain"
- `DONE_CONDITIONS` — 2–5 machine-checkable checklist items (grep match, test exit code, CI green, etc.)
- `GUARDRAILS` — paths/systems the agent must not touch
- `VERIFIER_CMD` — the command that confirms completion (e.g. `npm test`, `grep -r "old/path" src/ | wc -l`)
- `MAX_TURNS` — turn cap (default 50 for complex goals; 20 for focused ones)
- `MAX_BUDGET_USD` — hard cost cap (default 5.00)

Get local time:
```bash
date '+%Y-%m-%d %H:%M %Z'
```

## Phase 2 — G0–G3 readiness check

Score the goal across four axes before proceeding. Each axis scores 0 (unmet) or 1 (met):

| Axis | Score 0 | Score 1 |
|---|---|---|
| **Objective clarity** | Vague ("improve X") | Concrete and verifiable |
| **Verifier independence** | Same agent judges output | Separate command, CI, or subagent |
| **State file** | No GOAL.md planned | GOAL.md will be written and kept |
| **Budget defined** | No cap | Explicit `--max-turns` and `--max-budget-usd` |

- **G0** (0/4): Stop — the goal cannot be safely automated. Report the missing axes and stop.
- **G1** (1–2/4): Proceed, but write a `⚠ Readiness: G1` warning block in GOAL.md
  listing which axes score 0 and what the user should fix before running.
- **G2** (3/4): Proceed with a `⚠ Readiness: G2` note in GOAL.md.
- **G3** (4/4): Proceed normally; no warning needed.

If the goal scores G0, stop here and print which axes are missing.

## Phase 3 — Create GOAL.md

Write `<GOAL_SLUG>-GOAL.md`:

```markdown
# Goal: <GOAL_NAME>

## Objective
<OBJECTIVE>

## Done conditions
- [ ] <DONE_CONDITION_1>
- [ ] <DONE_CONDITION_2>

## Guardrails
- Must not touch: <GUARDRAILS>
- Budget: --max-turns <MAX_TURNS> --max-budget-usd $<MAX_BUDGET_USD>

## Verifier
```bash
<VERIFIER_CMD>
```
Exit 0 = done. Any non-zero = not done.

## Execution log
<!-- Append entries at meaningful milestones — do not delete entries -->
- [<LOCAL_TIMESTAMP>] Goal scaffolded
```

**Write discipline for the executing agent:** log at meaningful milestones (not every micro-step), verify done conditions before each write, never delete entries. This file must be self-explanatory to a fresh agent mid-goal.

## Phase 4 — Create run script

Create `scripts/run-<GOAL_SLUG>.sh`:

```bash
#!/usr/bin/env bash
# One-shot goal runner for: <GOAL_NAME>
# Run once — stops when done conditions are met.
# Resume a partial run by re-invoking; GOAL.md execution log prevents re-doing completed work.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

GOAL_FILE="<GOAL_SLUG>-GOAL.md"
LOG="logs/<GOAL_SLUG>-$(date '+%Y%m%d-%H%M').log"
mkdir -p logs

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Goal start: <GOAL_NAME>" | tee -a "$LOG"

claude \
  --permission-mode auto \
  --max-turns <MAX_TURNS> \
  --max-budget-usd <MAX_BUDGET_USD> \
  --effort high \
  -p "Read $GOAL_FILE. Complete the goal. Log progress in the Execution log section.
When all Done conditions are checked off, run the verifier:
  <VERIFIER_CMD>
If the verifier passes, append a final log entry and stop.
If it fails, fix and re-verify. Never mark done until the verifier exits 0." \
  >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Goal runner exited." | tee -a "$LOG"
```

Make executable:
```bash
chmod +x scripts/run-<GOAL_SLUG>.sh
```

## Phase 5 — Commit

```bash
git add <GOAL_SLUG>-GOAL.md scripts/run-<GOAL_SLUG>.sh
git commit -m "feat(goal): scaffold <GOAL_SLUG>"
```

## Phase 6 — Report

```
Goal scaffolded ✓  [G<READINESS_SCORE>/3]

  Objective : <OBJECTIVE>
  State file: <GOAL_SLUG>-GOAL.md
  Runner    : scripts/run-<GOAL_SLUG>.sh
  Verifier  : <VERIFIER_CMD>
  Budget    : $<MAX_BUDGET_USD> / <MAX_TURNS> turns

To run:
  bash scripts/run-<GOAL_SLUG>.sh

Resume a partial run by re-invoking — GOAL.md tracks progress across context resets.
```
