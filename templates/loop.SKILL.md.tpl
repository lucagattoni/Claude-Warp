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

1. Read `{{STATE_FILE}}` to find the most recent run entry.
2. If the most recent entry is marked `IN_PROGRESS`, treat that task as incomplete
   and restart it from the beginning before doing anything else.
3. Record `last_run` (ISO date) and `today` from:
   ```bash
   date '+%Y-%m-%d %H:%M %Z'
   ```

## Phase 3 — Do the work

<!-- Replace this section with the loop's actual logic -->

## Phase 3b — Verify

Run the verification check and read its exit code:
```bash
# Replace with the appropriate check for this loop, e.g.:
#   npm test
#   pytest
#   ruff check .
#   bash scripts/verify-{{SKILL_SLUG}}.sh
```

- If the check **passes** (exit 0): proceed to Phase 4.
- If the check **fails**: read the output, fix the root cause, re-run Phase 3 and
  Phase 3b. Do not proceed to Phase 4 until the check passes.
- If no automated check exists for this loop: document why in a `# Verification`
  comment here, and describe what a human reviewer should inspect.

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

1. Append a new dated section to `{{STATE_FILE}}`:
   ```markdown
   ## YYYY-MM-DD HH:MM <TZ> (run)
   <!-- findings -->
   ---
   ```
2. Commit changes:
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
