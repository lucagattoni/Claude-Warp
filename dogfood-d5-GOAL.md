# Goal: Dogfood D5 — flip command-verification (claim #5) to verified-live

slug: dogfood-d5 · kind: goal · risk: R1

## Objective

Record the live Dogfood D5 result and flip the last open behavioural claim — #5
(command-verification, v0.32.0) — from `unverified` to `verified-live`, **only because it honestly
fired** under genuine independence, taking the backlog to **5/5 `verified-live`**. Evidence-only: no
charter, matcher, or tooling change; the v0.32.0 rule and the v0.32.1 count-coherence guard are exercised,
not edited.

## Done conditions

- [x] Live pass run: a spawned **Sonnet** pass-2 (different in-house model, reasoning-blind, fresh context,
      no hint which finding was true), wrapped by `scripts/reviewer-guard.sh` (snapshot before / verify after).
- [x] Catch fired two-directionally on `tests/dogfood/repro-fixture/`: Finding A `grep -n 'check'` →
      `check: "true"` → `[CMD_CONFIRMED]`, kept `critical`; Finding B `grep -n 'loop_max_usd'` →
      `loop_max_usd: 5` → `[CMD_CONTRADICTED]`, **demoted `critical` → `major`**; verdict `[pass-2 / sonnet]`.
- [x] Integrity: `reviewer-guard.sh verify` returned **tree unchanged (reviewer was read-only)** (exit 0) —
      the v0.32.0 guard's first **live** exercise; the D5 evidence is integrity-clean.
- [x] `BEHAVIOURAL-CLAIMS.md`: claim #5 STATUS `unverified` → `verified-live 2026-06-29`; "Why still
      unverified" replaced by a "Live evidence (Dogfood D5)" bullet quoting the actual output; a Dogfood D5
      log entry added; intro count `4/5` → `5/5`.
- [x] `docs/loop-harness.md`: v0.32.2 narrative recording the D5 catch; backlog `4/5` → `5/5` (required —
      dev.sh step-7 asserts the `M/N` literal is identical in both files).
- [x] `working/dogfood-d5-verify.sh` asserts the flip + the recorded evidence (CMD tags, demotion,
      `[pass-2 / sonnet]`, tree-unchanged) + 5/5 parity + no stale `4/5`/`unverified #5`; PASSES.
- [x] CHANGELOG `[0.32.2]` (PATCH — evidence) + VERSION; `dev.sh verify` 7/7 (count check: 5/5);
      `reviewer-guard --self-test`; `verifier-lib --self-test`; residuals R1 (HIGH=0).

## Guardrails

- Flip **only** claim #5 — claims #1–#4 untouched; registry stays 5 total headings.
- Evidence-only: do **not** edit `skills/**`, `scripts/**`, or the `repro-fixture/**` (reused as-is).
- `verified-live` requires the REAL spawned independent pass already run — never conflate with an
  in-context reasoning pass (P6). Pass-1 was a constructed input; only pass-2 was the live agent.
- Cross-vendor independence remains a future, weaker-until-proven claim — out of scope.

## Verifier

`bash working/dogfood-d5-verify.sh && bash scripts/dev.sh verify`

## Execution log

- 2026-06-29 — Ran the live D5 pass (spawned Sonnet, reasoning-blind, reviewer-guard-wrapped); it produced
  the predicted two-directional catch and the guard confirmed read-only. Recorded the evidence + flipped
  claim #5 → `verified-live 2026-06-29` (backlog 5/5) in BEHAVIOURAL-CLAIMS.md + docs; CHANGELOG 0.32.2 +
  VERSION. `working/dogfood-d5-verify.sh` PASS; `dev.sh verify` 7/7 (5/5); self-tests PASS; residuals R1
  HIGH=0. COMPLETE.
