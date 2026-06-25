---
name: claude-warp-retro
description: Retrospective over one loop or harness — reads state files and git history to surface what worked, what failed, and concrete improvement suggestions; produces a RETRO.md entry without modifying any loop files
---

Run a retrospective on a loop or harness: `$ARGUMENTS`

Expected input: loop slug or harness slug (e.g. `daily-issues`, `refactor-auth`).
If `$ARGUMENTS` is empty: run a retrospective over all loops in this project.

## Phase 1 — Locate state files

```bash
# Find state files for the target slug (or all if no slug given)
ls *_LOG.md *-GOAL.md *-STATE.md *-features.json 2>/dev/null
```

For each state file matching the slug:
1. Read the `<!-- state:` header to get `runs_total`, `consecutive_fails`, `last_verdict`, `last_run`
2. If no state file found: print "No state file found for <slug> — has this loop run yet?" and stop

## Phase 2 — Read git history

```bash
git log --oneline --since="30 days ago" -- '*<slug>*' '*_LOG.md' '*-STATE.md' 2>/dev/null | head -50
```

Record:
- `RUN_COMMITS` — commits matching `loop(<slug>): run` pattern (one per run)
- `FIX_COMMITS` — commits that changed loop logic files (skill SKILL.md edits)
- `FAIL_ENTRIES` — lines in state files marked FAILED, NEEDS_REVIEW, or timeout

## Phase 3 — Read recent state entries

Read the last 10 dated sections in the state file(s). For each entry, extract:
- Verdict (pass/skip/fail/handoff/timeout/stopped)
- Any error output or NEEDS_REVIEW notes
- Pattern: did the same failure recur across multiple runs?

## Phase 4 — Analyse

Answer these questions:

**What worked:**
- Which runs passed cleanly?
- Did the verification step catch real issues?
- Did the guard prevent double-runs?

**What failed:**
- Were there consecutive failures? What caused them?
- Were there handoff verdicts? What triggered them?
- Were there timeout verdicts? Was the budget tight or was the task scope drifting?

**Patterns:**
- Is the failure rate increasing, stable, or improving?
- Are any failures systemic (same root cause repeating)?
- Are handoffs clustered around a specific type of input?

**Concrete improvements (top 3):**
For each, specify: which phase to edit, what to change, and why.
Format: `Phase X — <what> — <why>`

## Phase 5 — Write RETRO.md

Append to `RETRO.md` (create if absent):

```markdown
## Retro: <SLUG> — <YYYY-MM-DD>

**Period:** last <N> runs (since <start_date>)
**Runs:** <total> total | <pass> pass | <fail> fail | <handoff> handoff | <skip> skip

### What worked
- <finding>

### What failed
- <finding> (occurred <N> times)

### Top 3 improvements
1. Phase X — <change> — <reason>
2. Phase X — <change> — <reason>
3. Phase X — <change> — <reason>

---
```

## Phase 6 — Print summary

Print the top 3 improvements directly to the conversation so the user can
act on them without reading RETRO.md. Do NOT modify any loop SKILL.md files
or state files — this skill is read-only except for RETRO.md.
