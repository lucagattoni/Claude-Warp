---
name: {{SKILL_NAME}}
description: {{SKILL_DESCRIPTION}}
---

{{SKILL_GOAL}}

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

## Phase 4 — Write results

1. Append a new dated section to `{{STATE_FILE}}`:
   ```markdown
   ## YYYY-MM-DD HH:MM <TZ> (run)
   <!-- findings -->
   ---
   ```
2. Update `harness-manifest.json` last_run field:
   ```bash
   date '+%Y-%m-%dT%H:%M:%S%z'
   ```
3. Commit changes:
   ```bash
   git add {{STATE_FILE}} harness-manifest.json
   git commit -m "loop({{SKILL_SLUG}}): run YYYY-MM-DD"
   ```

## Stopping condition

**Success:** Phase 4 completes and `{{STATE_FILE}}` contains a dated entry marked
`DONE` for today's run.

**Skip:** Guard script fires (already ran today) — exit 0, log "skipping".

**Failure:** Phase 3 produces no actionable output after exhausting all sources,
OR any required command exits non-zero — exit 1, mark entry `FAILED` in
`{{STATE_FILE}}` so the next run does not treat it as IN_PROGRESS.
