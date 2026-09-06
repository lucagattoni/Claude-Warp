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

## Template resolution (read this before any "Read `templates/...`" step below)

Resolve every `templates/<name>.tpl` referenced in this skill, in order:

1. `.claudewarp/templates/<name>.tpl` — an installed project (written by `/claude-warp-setup`).
2. `templates/<name>.tpl` — you are running inside the ClaudeWarp source repo.

**If neither exists, STOP.** Print:
`Template <name>.tpl not found — run /claude-warp-setup first (it installs templates into .claudewarp/templates/).`
Do **not** improvise the file from memory. The templates carry the runner hardening that is the
entire reason to use ClaudeWarp rather than hand-writing a script — the binary preflights, the
fail-closed permission flags and deny-lists, the unknown-command guard, the safe-to-retry logic. A
plausible-looking runner written from scratch has none of it and looks identical to one that does.

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

# ── Preflight: resolve the claude binary ──────────────────────────────────────
# cron and launchd run with a minimal PATH that omits ~/.local/bin, where the native installer puts
# claude. CLAUDE_BIN is prepended LAST so it actually outranks an existing install.
PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
if [ -n "${CLAUDE_BIN:-}" ]; then
  [ -x "$CLAUDE_BIN" ] || { echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: CLAUDE_BIN=$CLAUDE_BIN is not executable." | tee -a "$LOG" >&2; exit 127; }
  PATH="$(cd "$(dirname "$CLAUDE_BIN")" && pwd):$PATH"
fi
export PATH
command -v claude >/dev/null 2>&1 || { echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: \`claude\` not found on PATH ($PATH) — a scheduled run cannot start. Set CLAUDE_BIN=/full/path/to/claude." | tee -a "$LOG" >&2; exit 127; }

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Goal start: <GOAL_NAME>" | tee -a "$LOG"

# Fail-closed: `--permission-prompts none` (Claude Code v2.1.259+) denies anything the auto-mode
# classifier would have asked a human about — nobody is at the terminal. Probed once so an
# older CLI (which rejects unknown flags) still runs; ${arr[@]+...} is the bash-3.2-safe splice.
PERM_PROMPTS=()
claude --help 2>/dev/null | grep -q -- '--permission-prompts' && PERM_PROMPTS=(--permission-prompts none)

# `claude -p "/goal ..."` exits 0 even when the slash command does not resolve, printing
# "Unknown command:" — and budget exhaustion is a CAP, not a transient failure. Both are checked
# against THIS run's own output below, exactly as the loop runners do.
UNKNOWN_CMD_MARKER="Unknown command:"
BUDGET_MARKER="Exceeded USD budget"
before_bytes=$(wc -c < "$LOG" 2>/dev/null || echo 0)

claude \
  --permission-mode auto \
  ${PERM_PROMPTS[@]+"${PERM_PROMPTS[@]}"} \
  --max-turns <MAX_TURNS> \
  --max-budget-usd <MAX_BUDGET_USD> \
  --effort high \
  --disallowedTools "<DISALLOWED_TOOLS>" \
  -p "/goal Every Done condition in $GOAL_FILE is checked off, the verifier command
\`<VERIFIER_CMD>\` has been run with its output shown and exit code 0, and a final entry has
been appended to the Execution log in $GOAL_FILE — or stop after <MAX_TURNS> turns.
Constraint: read $GOAL_FILE first and never touch what its Guardrails section forbids." \
  >> "$LOG" 2>&1
RC=$?

# Inspect only what THIS run appended.
NEW_OUTPUT=$(tail -c "+$((before_bytes + 1))" "$LOG" 2>/dev/null || true)
if printf '%s' "$NEW_OUTPUT" | grep -q "$UNKNOWN_CMD_MARKER"; then
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: the CLI printed '$UNKNOWN_CMD_MARKER' and exited $RC — /goal did not resolve. This is deterministic; not retrying." | tee -a "$LOG" >&2
  exit 4
fi
if printf '%s' "$NEW_OUTPUT" | grep -q "$BUDGET_MARKER"; then
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: exhausted the --max-budget-usd cap. Each run gets a fresh cap, so re-running spends the same to fail the same way. Raise MAX_BUDGET_USD or narrow the goal. Check $GOAL_FILE — partial work may have landed." | tee -a "$LOG" >&2
  exit 6
fi

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Goal runner exited (rc=$RC)." | tee -a "$LOG"
exit $RC
```

**Derive `DISALLOWED_TOOLS` in Phase 1** alongside the other parameters — the same hard deny-list the
loop runners carry, because `--allowedTools` is pre-approval the auto-mode classifier can expand
beyond while `--disallowedTools` holds. Always include the destructive floor
`Bash(git push --force*),Bash(git reset --hard*),Bash(git clean*),Bash(rm -rf *)`, plus anything the
goal's Guardrails section forbids that maps to a tool pattern.

> A goal runner carries the same environment hardening as a loop runner — binary preflight,
> `CLAUDE_BIN` override, fail-closed prompts, a hard deny-list, and guards for the two failures that
> otherwise read as success (an unresolved slash command exits 0; budget exhaustion is a cap, not a
> transient). `scripts/dev.sh verify` asserts that parity, because this runner is written inline here
> rather than filled from `templates/`, and it drifted out of parity once already.

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
