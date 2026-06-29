# Goal: Correct the /converge claim (#3) + live D3 dogfood of its real behaviour

**Slug:** dogfood-converge-d3 · **Risk:** R1 · **Contract:** contract.yaml

## Objective

The honesty gate (Phase-2 read of `skills/claude-warp-converge/SKILL.md`) revealed that backlog
**claim #3 mischaracterizes `/converge`**: it described reconciling "two reviewer passes that
disagree", but `/converge` reconciles **actual repo state vs contract intent** and classifies gaps
(missing/partial/contradicts/unrequested). Correct the claim, then run a **live D3 dogfood** of the
*real* mechanism — flipping #3 to `verified-live` only if it honestly fires.

## Done conditions

- [x] Claim #3 rewritten to the state-reconciler framing; **no "two reviewer verdicts" language remains**.
- [x] Backlog records the correction was caught by the D3 honesty gate (not silently overwritten).
- [x] A tracked `tests/dogfood/converge-fixture/` partial-satisfaction mini-repo: stop.check passes, a
      must_not_touch path violated, a may_touch intent item missing. Hint-stripped (no answer-leak tags).
- [x] A live independent reasoning-blind agent ran `/converge` on it; **Dogfood D3** records its actual
      classification output (contradicts? missing? did it refuse "converged"?).
- [x] Claim #3 flipped to `verified-live`/`verified-on-fixture` **iff** it honestly fired; else negative recorded + stays `unverified`.
- [x] `working/dogfood-converge-d3-verify.sh` asserts the correction + the recorded D3 catch (behaviour, not presence) + fixture tracked/hint-stripped/3 conditions; PASSES.
- [x] RUNBOOK + docs updated; CHANGELOG + VERSION; verifier-lib --self-test; dev.sh 6/6; residuals R1 HIGH=0.

## Guardrails

- Do NOT edit `skills/claude-warp-converge` — the skill is correct; the backlog was wrong.
- Claim #4 (reproduction-required) is genuinely two-pass and deferred — out of scope.
- Leave historical D1/D2 log entries intact (record of what was believed then).

## Verifier

`bash working/dogfood-converge-d3-verify.sh && bash scripts/verifier-lib.sh --self-test && bash scripts/dev.sh verify`

## Execution log

- 2026-06-28 — Phase-2 honesty gate caught claim #3 mischaracterizing /converge (verdict-reconciler vs the real state-reconciler); corrected the claim, built tracked partial-satisfaction fixture (converge-fixture/), ran a live Sonnet /converge pass reasoning-blind. It independently classified the missing doc gap + the contradicts must_not_touch breach, surfaced the latter as Type-B, concluded NOT converged. Claim #3 flipped unverified -> verified-live 2026-06-28 (severity-rating caveat recorded). Verifier PASS; self-test; dev.sh 6/6; residuals R1 HIGH=0. COMPLETE 7/7.
