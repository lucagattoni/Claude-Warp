# Goal: Improve ClaudeWarp planning & interactive-spec skills

Negotiated via `/claude-warp-contract` (kind: goal, risk R1, readiness G3).
This is the clean goal artifact — written as `GOAL.md`, not `loop-contract.yaml`
(itself a demonstration of done-condition #1).

## Objective
Implement four concrete improvements to the contract negotiator and the `new` router —
no behavioural change outside that surface.

## Done conditions
- [x] **goal-branch-coherence** — `/claude-warp-contract` writes a neutral `contract.yaml`
      (both kinds), goal projects `<slug>-GOAL.md`, loop projects anchor files; Phase 8
      contradiction removed and the loop/goal split made explicit.
- [x] **generalize-subjective-stop** — Phase 5 now elicits a concrete deficiency checklist as
      the primary path; UI four-dimension grading is a documented special case.
- [x] **relax-interview-batching** — Phase 3 allows the 1–2 most-blocking questions up front,
      then one at a time.
- [x] **router-chaining-clarity** — `/claude-warp-new` Phase 2 states an explicit handoff
      contract (forward $ARGUMENTS verbatim, hand off once, interactive-invoke vs headless-recommend).
- [x] **no regression** — `bash scripts/dev.sh verify` exits 0.

## Guardrails
- Must touch only: `skills/claude-warp-contract/`, `skills/claude-warp-new/`, `docs/loop-harness.md`
- Must not touch: `templates/`, `install.sh`, other skills
- Surface before commit: any change to a skill's external contract (a flag, the handoff
  interface, or the materialised artifact's name/shape)
- Budget: --max-turns 50, --max-budget-usd 5

## Verifier
```bash
bash scripts/dev.sh verify        # deterministic, must exit 0
# + re-run /claude-warp-contract on a kind:goal to confirm the goal artifact is clean
```

## Execution log
<!-- append at milestones; do not delete entries -->
- [2026-06-26 IST] Goal negotiated and materialised from contract draft.
- [2026-06-26 IST] Items 2–4 implemented (contract Phase 3/5, new Phase 2); verify green.
- [2026-06-26 IST] Item 1 surfaced (artifact-naming = external-contract change) → user
  approved neutral `contract.yaml`; implemented across contract skill + docs. All done
  conditions met; verify green. GOAL COMPLETE.
