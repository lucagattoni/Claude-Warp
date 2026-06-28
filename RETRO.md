# Retrospectives

Produced by `/claude-warp-retro`. Read-only analysis — findings here are not auto-applied.

---

## Retro: honesty-riders (goal) — 2026-06-28

**Outcome:** ✅ COMPLETE — 9/9 done conditions met; verifier 24/24, `dev.sh verify` 6/6, residuals R2 clean (HIGH=0).
**Milestones:** 2 execution-log entries (contract+materialise → implement+verify) | rework: none — zero mid-build surprises.

### What worked
- **Phase-2 pre-draft source read paid off.** Reading all three seams (contract Phase 6 + 1.5, harness QA evaluator) *before* drafting meant the contract `action`/`scope` matched reality — no "already present / differently shaped" surprise mid-build. The mandatory-read rule earned its keep on a 3-file change.
- **Type-B routing stayed honest.** The one judgment call (tier-scoping) was surfaced as a `surface_condition` and resolved by the user before any code — not auto-picked. The feature itself encodes the same discipline (severity gating never auto-resolves a hidden Type-B).
- **Worth-it gate correctly skipped.** A concrete settled-scope change went straight to Phase 2; the gate did not tax it with a fuzzy-intent interview.
- **Verifier dodged the known md_has gap on purpose.** Assertions were hand-anchored on single-line tokens + snake_case (`approved_with_notes`) so the recurring `_italic_`/soft-wrap false-negative never fired. 24/24 first run.

### What failed / friction
- **The md_has italic/soft-wrap gap is now a recurring tax** (structural — 4th consecutive PR where the verifier author had to hand-anchor tokens to avoid a known false-negative: PR1 residuals, PR2 bold, PR3 soft-wrap, here pre-empted). It keeps working *because* the author remembers — a fragile guarantee.
- **The instruction-file verifier ceiling recurs** (structural — same note as the converge PR3 retro): the three edited files are LLM-instruction files, so the verifier can only assert each rider's instruction is *present*, not that the rider *behaves*. Re-flagged by hand each time instead of being a named, accepted limitation class.
- **Phase 1.5 rider framing is slightly miscoupled** (minor): the worth-it riders were documented under an "R2+" mental model, but Phase 1.5 runs *before* risk classification — so the R2+ label doesn't cleanly apply to the worth-it verdict (it applies to the post-classification surfaces). The implementation handles it correctly (fuzzy plans always get the riders), but the framing could mislead a future editor.

### Top 3 improvements
1. **`scripts/verifier-lib.sh` — close (or wrap) the `_italic_`/soft-wrap gap** — add an opt-in `md_has_loose` that also strips single-underscore emphasis when not snake_case-adjacent, so verifier authors stop hand-dodging a known defect that has now taxed 4 PRs. Carry the `--self-test` boundary case forward. (Recurring → fix the lib, dedicated PATCH.)
2. **`claude-warp-contract` Phase 6 — name the "instruction-file change" limitation class explicitly** — when a contract's targets are LLM-instruction files, the critical pass should state once that the verifier asserts *presence, not behaviour*, and record it in `decision_log` — so it's a known accepted ceiling, not rediscovered and re-noted every retro.
3. **`claude-warp-contract` Phase 1.5 — decouple the worth-it riders from the R2+ tier label** — clarify that the confidence-cap + Unverified riders apply to *every* worth-it verdict (fuzzy plans are inherently the high-uncertainty case), independent of the R0–R5 class that is only assigned later in Phase 3.

---

## Retro: improve-planning-skills (all goals/loops) — 2026-06-26

**Subject:** one completed **goal** (no recurring loops scaffolded in this repo).
**Period:** the goal's full lifecycle (3 commits: approve → items 2–4 → item 1).
**Outcome:** ✅ COMPLETE — 5/5 done conditions met; `scripts/dev.sh verify` green at every step.

### What worked
- **Vibe → checklist conversion.** "Improve the planning skills" had no checkable done
  condition; the contract's "help me define it" path turned it into 4 concrete, verifiable
  items elicited from observed deficiencies. The goal became gradable.
- **The `surface_condition` gate fired correctly.** Item #1 (artifact rename = external-contract
  change) was auto-detected as a human gate and routed for approval instead of being silently
  applied — maker/checker + human-in-the-loop working on the tool itself.
- **Scope discipline held.** Only `contract` + `new` + `docs/loop-harness.md` were touched, exactly
  the contract's `may_touch`. No drift.
- **Verifier caught regressions early.** `dev.sh verify` ran after each item; green throughout.

### What failed / friction
- **No execution failures.** The friction was structural, not operational: the tooling is
  **loop-centric and strains for one-shot goals.**
  - `/claude-warp-retro` Phase 1 expects a `<!-- state:` header; a doc-30 `GOAL.md` has none, so
    this retro had to adapt by hand.
  - The retro frame (`runs_total`, `consecutive_fails`, per-run verdicts) does not map to a
    one-shot goal that runs once to completion.

### Pattern (systemic)
This is the **second instance** of the same root cause in one session: ClaudeWarp's machinery is
loop-first, and goals are a bolted-on branch. We fixed one instance in v0.13.0 (contract goal-branch
coherence); the retro skill has the identical class of issue. Expect more loop-centric skills to
share it.

### Top 3 improvements
1. **`claude-warp-retro` Phase 1 — add a goal mode — why:** when the state file is a doc-30 `GOAL.md`
   (no loop state header), read done-conditions + execution log and report completion status, instead
   of assuming runs/verdicts. Same goal-vs-loop split just fixed in the contract command.
2. **`claude-warp-retro` Phase 1 — detect schema before reading — why:** don't assume a `<!-- state:`
   header exists; branch on loop-state-header vs goal-schema first, so the skill never silently
   misreads a goal.
3. **Cross-skill goal-coherence sweep — why:** audit the remaining loop-centric skills (retro,
   `inventory` Phase 5 reads state headers, any other) and generalize the goal/loop split once —
   this root cause has now recurred twice and will keep surfacing piecemeal otherwise.

---
