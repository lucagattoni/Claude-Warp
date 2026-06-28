---
name: claude-warp-retro
description: Retrospective over a loop, goal, or harness — detects the state-file schema, reads it plus git history, and surfaces what worked, what failed, and concrete improvements; produces a RETRO.md entry without modifying any loop/goal files
---

Run a retrospective on a loop or harness: `$ARGUMENTS`

Expected input: loop slug or harness slug (e.g. `daily-issues`, `refactor-auth`).
If `$ARGUMENTS` is empty: run a retrospective over all loops in this project.

## Phase 1 — Locate state files

```bash
# Find state files for the target slug (or all if no slug given)
ls *_LOG.md *-GOAL.md *-STATE.md *-features.json 2>/dev/null
```

If no state file found: print "No state file found for <slug> — has this loop or goal run yet?" and stop.

**Detect each file's schema before reading it** — a retro must not assume the loop shape:

| File looks like | Detect by | Kind | Read |
|---|---|---|---|
| Loop state log | has a `<!-- state:` header | **loop** | `runs_total`, `consecutive_fails`, `consecutive_stagnation`, `last_verdict`, `last_run` |
| doc-30 goal | `*-GOAL.md` with `## Done conditions` + `## Execution log`, no `<!-- state:` header | **goal** | done-conditions (checked vs total), execution-log milestones |
| Harness | `*-features.json` | **harness** | task statuses (done/pending/failed), waves |

Branch the rest of the retro on the detected kind. A one-shot **goal** has no per-run
verdicts — analyse its *completion* (were all done-conditions met? how many milestones / how
much rework?), not a run series.

## Phase 2 — Read git history

```bash
git log --oneline --since="30 days ago" -- '*<slug>*' '*_LOG.md' '*-STATE.md' 2>/dev/null | head -50
```

Record:
- `RUN_COMMITS` — commits matching `loop(<slug>): run` pattern (one per run)
- `FIX_COMMITS` — commits that changed loop logic files (skill SKILL.md edits)
- `FAIL_ENTRIES` — lines in state files marked FAILED, NEEDS_REVIEW, or timeout

## Phase 3 — Read recent state entries

**Loop / harness:** read the last 10 dated sections in the state file(s). For each entry, extract:
- Verdict (pass/skip/fail/handoff/timeout/stopped)
- Any error output or NEEDS_REVIEW notes
- Pattern: did the same failure recur across multiple runs?

**Goal:** read the `## Done conditions` checklist and the full `## Execution log`. Extract:
- Completion: how many done-conditions are checked vs total; is the goal COMPLETE?
- Rework: did any milestone redo earlier work, or did a `surface_condition` / handoff fire?
- Friction: anything the execution log notes as awkward, blocked, or surprising.

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

Append to `RETRO.md` (create if absent). Use the header line that matches the detected kind:

**Loop / harness:**
```markdown
## Retro: <SLUG> — <YYYY-MM-DD>

**Period:** last <N> runs (since <start_date>)
**Runs:** <total> total | <pass> pass | <fail> fail | <handoff> handoff | <skip> skip
```

**Goal:**
```markdown
## Retro: <SLUG> (goal) — <YYYY-MM-DD>

**Outcome:** <COMPLETE | INCOMPLETE> — <checked>/<total> done conditions met
**Milestones:** <N> execution-log entries | rework: <none | what was redone>
```

Then, for either kind:
```markdown
### What worked
- <finding>

### What failed / friction
- <finding> (occurred <N> times, or "structural" for one-shot goals)

### Top 3 improvements
1. Phase X — <change> — <reason>
2. Phase X — <change> — <reason>
3. Phase X — <change> — <reason>

---
```

## Phase 6 — Record to the cross-session ledger

After RETRO.md is written, append one closure event to the persistent ledger so the
retrospective is queryable across future sessions (retro already writes files, so this stays
within its remit — see `/claude-warp-ledger`):

```bash
bash scripts/ledger.sh record --kind <goal|loop|harness> --slug <SLUG> --event converged \
     --verdict "<COMPLETE|INCOMPLETE|N pass/M fail>" --note "retro: <one-line top improvement>"
```

If `scripts/ledger.sh` is absent (older checkout / partial self-host), skip this step silently —
the retro is still complete without it.

## Phase 7 — Print summary

Print the top 3 improvements directly to the conversation so the user can
act on them without reading RETRO.md. Do NOT modify any loop SKILL.md files
or state files — this skill is read-only except for RETRO.md and the ledger append in Phase 6.
