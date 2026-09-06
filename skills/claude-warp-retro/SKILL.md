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
| §2.2 goal | `*-GOAL.md` with `## Done conditions` + `## Execution log`, no `<!-- state:` header | **goal** | done-conditions (checked vs total), execution-log milestones |
| Harness | `*-features.json` | **harness** | task statuses (done/pending/failed), waves |

Branch the rest of the retro on the detected kind. A one-shot **goal** has no per-run
verdicts — analyse its *completion* (were all done-conditions met? how many milestones / how
much rework?), not a run series.

## Phase 2 — Read git history

First fix the window and the paths, because both defaults are wrong for a real loop.

**Paths — this loop's, not every loop's.** Use the `STATE_FILE` you resolved in Phase 1 plus
this loop's own skill directory. A pathspec *union* like `'*<slug>*' '*_LOG.md'` pulls in a
sibling loop's commits, and the loop template explicitly anticipates several loops per repo.
Do not narrow to `'*<slug>*'` alone either — the slug need not appear in the filename
(`daily-dep-audit` → `DEP_AUDIT_LOG.md`).

**Window — derived from the runs, not a constant.** Phase 3 analyses the last 10 dated
sections; a fixed `--since="30 days ago"` silently disagrees with that on any cadence slower
than daily (a weekly loop's last 10 runs span ~70 days, so 6 of them fall outside the window
and the retro reports on history it never saw). Derive it:

```bash
STATE_FILE="<resolved in Phase 1>"           # e.g. DEP_AUDIT_LOG.md
SKILL_DIR=".claude/skills/<slug>"

# Oldest date among the last 10 dated sections — the window Phase 3 will actually read.
SINCE="$(grep -oE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$STATE_FILE" | tail -10 | head -1 | awk '{print $2}')"
[ -n "$SINCE" ] || SINCE="30 days ago"       # no dated sections yet: fall back

git log --oneline --since="$SINCE" -- "$STATE_FILE" "$SKILL_DIR" 2>/dev/null | head -50
```

Record:
- `RUN_COMMITS` — commits matching `loop(<slug>): run` pattern (one per run)
- `FIX_COMMITS` — commits that changed loop logic files (skill SKILL.md edits)
- `FAIL_ENTRIES` — lines in state files marked FAILED, NEEDS_REVIEW, timeout, or **stopped**
  (`stopped` is a first-class verdict — a security or permission gate fired. Omitting it hides
  exactly the failures most worth reading.)

**Guard-fired skips are not in either input.** When the guard blocks a duplicate run it exits
before the loop's Phase 2 and Phase 4, so it writes neither `STATE_FILE` nor a commit. Its only
trace is `logs/<slug>-*.log`, which is gitignored. Read those logs if present:

```bash
grep -h '^\[guard\]' logs/<slug>-*.log 2>/dev/null | tail -20
```

If they are absent (rotated, or the loop ran elsewhere), record `GUARD_EVIDENCE=none` — and in
Phase 4 answer the guard question *"not observable from the available inputs"*. Do not infer
guard behaviour from the `skip` verdicts in `STATE_FILE`: those are the loop's own
nothing-to-do skips, a structurally different event.

## Phase 3 — Read recent state entries

**Loop / harness:** read the last 10 dated sections in the state file(s) — the *newest* ten.
The file is append-only and never rotated, so reading top-down returns the **oldest** ten, which
is the opposite of what this phase wants:

```bash
grep -nE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$STATE_FILE" | tail -10   # newest 10 dated sections
```

Read from the first of those line numbers to end of file. For each entry, extract:
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
- Did the guard prevent double-runs? Answer this **only** from `GUARD_EVIDENCE` (Phase 2). With
  `GUARD_EVIDENCE=none`, write *"not observable — the guard leaves no trace in `STATE_FILE` or
  git history"*. Never answer it from the `skip` verdicts in the state file, and never leave it
  silently unanswered: an unasked question reads as a passing one.

**What failed:**
- Were there consecutive failures? What caused them?
- Were there handoff verdicts? What triggered them?
- Were there timeout verdicts? Was the budget tight or was the task scope drifting?

**Patterns:**
- Is the failure rate increasing, stable, or improving?
- Are any failures systemic (same root cause repeating)?
- Are handoffs clustered around a specific type of input?

**Removal test (the harness is meant to shrink):**
- For each guard, checker, or corroboration pass this loop carries, ask: would the last N runs
  still have passed on the current model with that component removed? A component whose absence
  would have changed nothing was load-bearing for an older model and is now overhead — propose
  removing it as one of the improvements below, and name the run evidence. Re-ask at the next
  model release; the answer is not permanent. (Andrew Ng's removal test, via Claude-Loops
  [§24 When to Remove Harness](https://lucagattoni.github.io/Claude-Loops/24-harness-patterns/).)

**Concrete improvements (top 3):**
For each, specify: which phase to edit, what to change, and why.
Format: `Phase X — <what> — <why>`

## Phase 5 — Write RETRO.md

Append to `RETRO.md` (create if absent). Use the header line that matches the detected kind:

**Loop / harness:**
```markdown
## Retro: <SLUG> — <YYYY-MM-DD>

**Period:** last <N> runs (since <start_date>)
**Runs:** <total> total | <pass> pass | <fail> fail | <handoff> handoff | <skip> skip | <timeout> timeout | <stopped> stopped

All six verdicts are listed, including zeros. The buckets **must sum to the stated total** — with
`timeout` and `stopped` missing, a window containing either was short by exactly those runs and
the arithmetic silently failed to add up.
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
