---
name: {{SKILL_NAME}}
description: {{SKILL_DESCRIPTION}}
---

{{SKILL_GOAL}}

<!--
Loop Contract
  TRIGGER : {{CRON_SCHEDULE}} (cron) — or replace with: hook | on-demand | goal
  SCOPE   : {{SCOPE}}
  ACTION  : {{ACTION}}
  BUDGET  : ${{MAX_BUDGET_USD}} / run, {{MAX_TURNS}} turns max
  STOP    : {{STOP_CONDITION}}
  REPORT  : appended to {{STATE_FILE}} after each run
-->

## Phase 1 — Guard check

Run the guard to prevent double-execution:
```bash
bash scripts/guard-{{SKILL_SLUG}}.sh
```
If the guard exits non-zero, stop immediately and log "already ran today — skipping".

## Phase 2 — Load state

1. Read `{{STATE_FILE}}`. If the file doesn't exist yet, create it with the header below.
2. Read the `<!-- state:` header block at the top of the file:
   ```
   <!-- state:
   last_run: YYYY-MM-DD HH:MM TZ
   last_verdict: pass | skip | fail | handoff | timeout | stopped
   runs_total: N
   consecutive_fails: N
   -->
   ```
   These fields let you assess loop health without scanning the full log.
3. If `last_verdict` is `IN_PROGRESS`, treat that task as incomplete and restart it
   from the beginning before doing anything else.
4. Record `today` from:
   ```bash
   date '+%Y-%m-%d %H:%M %Z'
   ```

## Phase 2.5 — Inspect

Before modifying anything, read every file in SCOPE that this run will write to.
Do not edit a file you have not read in the current context window.

```bash
# Read each file you will touch this run — replace with actual paths
# Read src/target-file.ts
# Read config/relevant-config.json
```

Log what you found: any unexpected state, pre-existing issues, or constraints
that will affect Phase 3. If inspection reveals the loop is unnecessary this run
(e.g. no new items, nothing changed), log "nothing to do" and proceed to Phase 4
with a `skip` verdict.

## Phase 3 — Do the work

<!-- Replace this section with the loop's actual logic -->

## Phase 3b — Verify

Run verification checks and compute a weighted pass score.

```bash
# Define each check with a weight (weights should sum to 100).
# Replace with checks appropriate for this loop.

# Check 1 — primary correctness (weight: 60)
#   npm test 2>&1          → exit 0 = pass
#   pytest 2>&1
#   bash scripts/verify-{{SKILL_SLUG}}.sh

# Check 2 — secondary quality (weight: 30)
#   ruff check . 2>&1
#   eslint src/ 2>&1

# Check 3 — surface/format (weight: 10)
#   git diff --check 2>&1

PASS_THRESHOLD=70   # proceed if weighted score >= this value
```

For each check: run it and record pass (exit 0) or fail (non-zero).
Sum the weights of passing checks.

- `score >= PASS_THRESHOLD` — proceed to Phase 4; log score and which checks passed/failed
- `score < PASS_THRESHOLD` — fix root cause of failing checks; re-run Phase 3 and Phase 3b
- Any check with weight ≥ 50 that fails is treated as a hard fail regardless of total score

**Single-check loops:** keep weight at 100 and threshold at 70. The weighted form adds value when 2+ independent checks apply.

If no automated check exists: document why in a `# Verification` comment and describe what a human reviewer should inspect.

## Phase 3c — Checker (optional)

If a checker subagent exists at `.claude/agents/{{SKILL_SLUG}}-checker.md`, invoke
it on the Phase 3 output before committing:

"Use the {{SKILL_SLUG}}-checker agent to review the findings from Phase 3.
If the checker raises blocking issues, address them and re-run Phase 3 and
Phase 3b before proceeding."

Skip this phase if no checker agent exists. To add one:
```bash
claude -p '/claude-warp-new-agent "checker for {{SKILL_SLUG}}: validates findings, raises blocking issues only"'
```

## Phase 4 — Write results

1. Update the `<!-- state:` header block at the top of `{{STATE_FILE}}` with current values:
   - `last_run`: today's timestamp
   - `last_verdict`: the verdict from this run
   - `runs_total`: increment by 1
   - `consecutive_fails`: reset to 0 on pass/skip/handoff; increment on fail/timeout/stopped

2. Append a new dated section below the header:
   ```markdown
   ## YYYY-MM-DD HH:MM <TZ> — <verdict>
   <!-- findings -->
   ---
   ```

3. Commit changes:
   ```bash
   git add {{STATE_FILE}}
   git commit -m "loop({{SKILL_SLUG}}): run YYYY-MM-DD"
   ```

## Stopping condition

Use the six-state verdict system — log the verdict in `{{STATE_FILE}}` so the
runner and the next run can respond correctly:

| Verdict | Condition | Action |
|---|---|---|
| **pass** | Phase 4 completes; dated `DONE` entry written | Exit 0 |
| **skip** | Guard fired (already ran today) | Exit 0, log "skip" |
| **fail** | Retryable error — Phase 3 produced no output OR a command failed | Exit 1, mark `FAILED`; next run will retry |
| **handoff** | Human judgment required — ambiguous result, conflicting valid options | Exit 0, log "handoff"; write a `NEEDS_REVIEW` note in `{{STATE_FILE}}` |
| **timeout** | Budget or turn cap exhausted before completion | Exit 0, log "timeout — resume next run"; do NOT retry automatically |
| **stopped** | Security gate or permission block triggered | Exit 1, log "stopped — investigate before retrying"; do NOT auto-retry |

**Escalation:** if 3 consecutive `fail` verdicts produce no clear fix, or any
destructive or irreversible operation is needed, switch verdict to `handoff` and
stop. See the Escalation rules section in `CLAUDE.md` for the full thresholds.
