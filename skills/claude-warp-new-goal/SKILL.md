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

**Native `/goal` is the runtime; this scaffold is the specification around it.** Claude Code's
[`/goal`](https://code.claude.com/docs/en/goal) (v2.1.139+) already keeps a session working until a
condition is met, judged after every turn by an independent small-model evaluator. If the user is
present, the goal is already G3-specified in their head, and no durable state/budget/audit trail is
needed, plain `/goal <condition>` in their session is enough — say so and stop. Scaffold when the
goal needs what `/goal` alone does not give: a **GOAL.md state file** that survives context resets,
a **G0–G3 readiness gate** before anything runs, **hard budget/turn caps**, explicit **guardrails**,
and a logged **runner** that cron/CI can invoke. The generated runner *delegates* the until-done
loop to native `/goal` (Phase 4) rather than reimplementing it.

## Phase 0 — Contract input (optional)

If `$ARGUMENTS` contains `--contract <file>`, read that `loop-contract.yaml`
(produced by `/claude-warp-contract`) and map its fields directly instead of deriving
from a string — it is already negotiated, risk-classified, and readiness-checked:

| Contract field | Goal primitive |
|---|---|
| `name` / `slug` | `GOAL_NAME` / `GOAL_SLUG` |
| `action` (+ `stop.check`) | `OBJECTIVE` |
| `stop.check`, `verifier.mechanism` | `DONE_CONDITIONS` / `VERIFIER_CMD` |
| `scope.must_not_touch` | `GUARDRAILS` |
| `budget.max_turns`, `budget.loop_max_usd` | `MAX_TURNS`, `MAX_BUDGET_USD` |

When a contract is supplied, **skip Phase 1 derivation and Phase 2 readiness scoring**
(the contract already passed the G-gate) — go straight to Phase 3. Otherwise continue below.

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

Note on **Verifier independence**: the native `/goal` evaluator the runner uses (Phase 4) adds
turn-level independence for free — a fresh small model judges the condition, not the working
agent — but it only reads what the transcript shows. A real `VERIFIER_CMD` whose output lands in
the transcript is still what scores this axis; the evaluator cannot run commands itself.

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

The runner delegates the until-done loop to **native `/goal`**: after every turn an independent
small-model evaluator judges the condition against the transcript, so completion is decided by a
fresh model rather than the agent doing the work — the harness does not reimplement this loop.
The CLI budget/turn caps remain as the hard outer bound (`/goal` itself has none).

At scaffold time check the environment supports it: `claude --version` must be **≥ 2.1.139** and
hooks must not be disabled (`disableAllHooks` — `/goal` is a session-scoped Stop hook). If either
fails, generate the **legacy variant** noted below instead.

Create `scripts/run-<GOAL_SLUG>.sh`:

```bash
#!/usr/bin/env bash
# One-shot goal runner for: <GOAL_NAME>
# Run once — native /goal keeps the session working until the done condition holds
# (independent per-turn evaluator); --max-turns/--max-budget-usd stay as the hard outer caps.
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
  -p "/goal Every Done condition in $GOAL_FILE is checked off, the verifier command
\`<VERIFIER_CMD>\` has been run with its output shown and exit code 0, and a final entry has
been appended to the Execution log in $GOAL_FILE — or stop after <MAX_TURNS> turns.
Constraint: read $GOAL_FILE first and never touch what its Guardrails section forbids." \
  >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Goal runner exited." | tee -a "$LOG"
```

**Legacy variant** (Claude Code < 2.1.139, or hooks disabled): replace the `-p "/goal …"` prompt
with the self-judged instruction — weaker, because the working agent grades its own doneness:

```
-p "Read $GOAL_FILE. Complete the goal. Log progress in the Execution log section.
When all Done conditions are checked off, run the verifier: <VERIFIER_CMD>
If the verifier passes, append a final log entry and stop.
If it fails, fix and re-verify. Never mark done until the verifier exits 0."
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
