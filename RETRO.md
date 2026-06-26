# Retrospectives

Produced by `/claude-warp-retro`. Read-only analysis — findings here are not auto-applied.

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
