## Retro: retro-fixture-loop — 2026-09-06

**Period:** last 10 runs (since 2026-08-03)
**Runs:** 10 total | 5 pass | 2 fail | 1 handoff | 1 skip | 1 timeout | 0 stopped

> Window note: the loop has 12 runs total. The 2 oldest (2026-08-01 `stopped`, 2026-08-02 `fail`)
> fall outside the 10-run window Phase 3 reads and are excluded from the counts above. The
> `stopped` count of 0 is a property of this window, not of the loop — a `DISALLOWED_TOOLS`
> permission gate did fire on 2026-08-01 against an attempted `git push --force`.

### What worked
- **5 clean passes**, and the two most substantive were recoveries rather than trivia: 2026-08-03
  fixed the 3 auth specs that failed the run before, and 2026-08-08 resumed and merged the
  reporting-module refactor stranded by the 2026-08-06 timeout. The loop recovers across runs.
- **Verification caught real issues, not noise.** `npm test` surfaced 3 genuinely failing auth
  specs (2026-08-02) and the lint step surfaced an environment defect (2026-08-04) that was
  invisible to the change under test. Neither was a false positive.
- **The guard prevented a double-run — observed, not inferred.** `logs/retro-fixture-loop-20260807.log`
  records a second invocation at 09:20 UTC blocked by `[guard] ... already completed on 2026-08-07
  (verdict: skip)`, after the 09:00 run had already completed. `GUARD_EVIDENCE=present`.
- **A failure was converted into a durable fix.** The 2026-08-04 root cause produced commit
  2f52522, and the lint timeout has not recurred in the 6 runs since.

### What failed / friction
- **Consecutive failures: 2** (2026-08-04 09:00 and 15:40), same root cause both times —
  `HTTPS_PROXY` unset in the cron environment, so the remote eslint config fetch timed out. The
  retry reproduced the failure and identified the cause but did not fix it, spending a whole run
  to learn nothing new.
- **The fix for it was prose, not a check.** 2f52522 changed one line of SKILL.md to *say* "set
  HTTPS_PROXY before invoking lint". Nothing asserts it. A fresh environment fails identically.
- **1 timeout (2026-08-06) that stranded work.** The `--max-turns` cap hit mid-refactor and the
  run committed nothing — logged as "change had no safe stopping point". The work sat unrecovered
  until 2026-08-08, surviving only because the next run happened to resume it.
- **Two nothing-to-do runs were recorded as `pass` (2026-08-09, 2026-08-10).** Both logged "no new
  items in SCOPE" and "no file changes" — the identical condition 2026-08-07 correctly recorded as
  `skip`. This is the direct cause of the handoff: `consecutive_stagnation` reached 3 and fired
  NEEDS_REVIEW on 2026-08-11, while the verdict column read as a healthy 3-run pass streak. The
  log disagrees with the counter that ended the window.
- **Trend: improving.** The first 4 runs of the window contain 2 fails and 1 timeout; the last 6
  contain zero failures. The window closes on a handoff, but from stagnation, not from breakage.
- **Handoffs are not input-clustered** — the single handoff is threshold-driven (stagnation ≥ 3),
  independent of what was in SCOPE.

### Removal test
- **Guard — keep.** Load-bearing on current evidence: it blocked a real duplicate invocation on
  2026-08-07. Removing it would have changed that run's outcome.
- **Test/lint verification — keep.** Caught 2 real defects in the window (auth specs, proxy).
- **Confidence pass — remove.** On 2026-08-09 and 2026-08-10 it re-ran existing checks over an
  unchanged SCOPE and found nothing both times; the checks had already been green since
  2026-08-08. Both runs would have reached the same end state without it. It is not merely
  neutral — it is what produced the two mislabeled `pass` verdicts, so removing it fixes a
  reporting defect as well as the overhead. Re-ask at the next model release.

### Top 3 improvements
1. Phase 4 — Emit `skip`, not `pass`, when a run ends with no new SCOPE items and no file changes;
   make the verdict a function of the observed change set rather than of "did the checks pass" —
   because 2026-08-09 and 2026-08-10 logged `pass` for the exact condition 2026-08-07 logged as
   `skip`, so the stagnation counter climbed to a handoff while the log read as healthy.
2. Phase 3 — Drop the confidence pass that re-runs checks when SCOPE is empty (removal test above)
   — because across 2026-08-09 and 2026-08-10 it produced zero findings over an unchanged SCOPE
   whose checks were already green, and its only measurable effect was the mislabeled verdicts.
3. Phase 3 — Checkpoint long-running work: commit at each safe boundary and, when the turn budget
   is within reach of exhaustion, stop at the next boundary and commit rather than continuing —
   because the 2026-08-06 timeout committed nothing mid-refactor and the work survived only
   because 2026-08-08 chose to resume it two days later.

---
