# Ground truth for RETRO_FIXTURE_LOG.md (12 runs, slug retro-fixture-loop)

Build with: `bash build.sh <scratch-dir>` (pure shell + git, zero LLM tokens).

## All 12 runs, in file order (oldest -> newest, matches append-only Phase 4 behavior)

| # | Date/time (UTC) | Verdict | File changed? | cf after | cs after |
|---|---|---|---|---|---|
| 1 | 2026-08-01 09:00 | stopped | no | 1 | 1 |
| 2 | 2026-08-02 09:00 | fail | no | 2 | 2 |
| 3 | 2026-08-03 09:00 | pass | yes | 0 | 0 |
| 4 | 2026-08-04 09:00 | fail | no | 1 | 1 |
| 5 | 2026-08-04 15:40 | fail (same-day retry) | no | 2 | 2 |
| 6 | 2026-08-05 09:00 | pass | yes | 0 | 0 |
| 7 | 2026-08-06 09:00 | timeout | no | 1 | 1 |
| 8 | 2026-08-07 09:00 | skip (nothing-to-do) | no | 0 | 2 |
| 9 | 2026-08-08 09:00 | pass | yes | 0 | 0 |
| 10 | 2026-08-09 09:00 | pass | no | 0 | 1 |
| 11 | 2026-08-10 09:00 | pass | no | 0 | 2 |
| 12 | 2026-08-11 09:00 | handoff (stagnation escalation) | no | 0 | 3 |

Final header (what a correct Phase 4 leaves behind, and what the fixture's header literally says):
`last_run: 2026-08-11 09:00 UTC | last_verdict: handoff | runs_total: 12 | consecutive_fails: 0 | consecutive_stagnation: 3 | acting_on: null`

## Full-history (12-run) verdict distribution
pass=5, fail=3, skip=1, handoff=1, timeout=1, stopped=1. Sum = 12.

## "Last 10 dated sections" (SKILL.md Phase 3) = runs #3-#12
Excludes run #1 (stopped) and run #2 (fail) — the two OLDEST.
Distribution within the last 10: pass=5, fail=2, skip=1, handoff=1, timeout=1. Sum = 10.

## What CORRECT retro output looks like (evidence the skill worked)
- RETRO.md's "Runs:" line sums to the same total it states, e.g. for the last-10 window:
  `10 total | 5 pass | 2 fail | 1 handoff | 1 skip | 1 timeout` (a 6th column, not in the
  current template) — 5+2+1+1+1 = 10. ✓
- The retro's "what failed" narrative separately calls out run #1 (stopped, 2026-08-01) as a
  security/permission event, distinct from the 3 plain `fail` runs.
- The retro notes TWO structurally different `skip` runs existed in this loop's life: one
  visible in the file (run #8, nothing-to-do) and it should flag that a guard-fired skip
  (2026-08-07 09:20 UTC, see logs/retro-fixture-loop-20260807.log) is NOT visible in the state
  file or git history at all — i.e. the retro should either say "cannot assess guard
  effectiveness from available inputs" or actually go read logs/*.log (which SKILL.md never
  instructs it to do).
- "Did the guard prevent double-runs?" is answered honestly as "unknown / not observable from
  STATE_FILE or git log" rather than silently answered from the 1 visible (non-guard) skip.

## What output PROVES a defect (checkable, mechanical)
1. Run the exact Phase 2 command from SKILL.md:35 with `--since` anchored so "today" is
   shortly after the fixture's last commit. It returns runs from an unrelated slug too if one
   exists in the repo (see `logs`-of-build showing "other-loop" polluting the query) —
   proves the pathspec-union defect (Finding E).
2. `grep -cE 'FAILED|NEEDS_REVIEW|timeout' RETRO_FIXTURE_LOG.md` == 6, and none of those 6
   lines is the "stopped" run's text — proves the FAIL_ENTRIES vocabulary gap (Finding A).
3. A RETRO.md entry produced against this fixture whose stated "total" does not equal the sum
   of the listed pass/fail/handoff/skip counts (short by exactly the timeout+stopped runs
   folded into the window) proves the verdict-breakdown template gap (Finding B).
4. A retro run that reports a clean 0-friction "guard worked" narrative, or that is simply
   silent on the guard, without ever reading `logs/*.log`, demonstrates Finding D — it had no
   way to know the guard fired on 2026-08-07 09:20 UTC because nothing in its declared inputs
   (STATE_FILE, git log) records that event.
5. Re-run Phase 2's literal `--since="30 days ago"` command against the companion
   `weekly-repo` fixture (10 runs, 7 days apart): it returns 4 of the 10 runs Phase 3 wants
   analysed — proves the fixed-window-vs-cadence defect (Finding F).
