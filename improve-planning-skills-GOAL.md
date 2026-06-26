# Goal: Improve ClaudeWarp planning & interactive-spec skills

Negotiated via `/claude-warp-contract` (kind: goal, risk R1, readiness G3).
This is the clean goal artifact — written as `GOAL.md`, not `loop-contract.yaml`
(itself a demonstration of done-condition #1).

## Objective
Implement four concrete improvements to the contract negotiator and the `new` router —
no behavioural change outside that surface.

## Done conditions
- [ ] **goal-branch-coherence** — `/claude-warp-contract` for `kind: goal` produces a clean
      goal artifact (`GOAL.md`), not `loop-contract.yaml` with loop-only fields; goal vs loop
      schema + readiness are clearly separated in the skill.
- [ ] **generalize-subjective-stop** — Phase 5's subjective-STOP handling elicits a concrete
      deficiency checklist as the primary path; the UI four-dimension grading becomes one case.
- [ ] **relax-interview-batching** — Phase 3 guidance allows the 1–2 most-blocking questions up
      front, then one at a time.
- [ ] **router-chaining-clarity** — `/claude-warp-new` states its handoff contract explicitly
      (auto-chain vs recommend; forwards the goal/contract).
- [ ] **no regression** — `bash scripts/dev.sh verify` exits 0.

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
