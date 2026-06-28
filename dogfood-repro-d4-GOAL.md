# Goal: live two-pass dogfood of reproduction-required corroboration (claim #4)

slug: dogfood-repro-d4 · kind: goal · risk: R1

## Objective

Run the gold-standard live test of claim #4 (v0.30.0 reproduction-required corroboration) and flip it to
`verified-live` **iff** a live, independent pass-2 reproduction agent honestly reproduces a true blocker
(keeps it blocking) and fails to reproduce a false one (downgrades it to a non-blocking minor). With this,
take the behavioural-claim backlog to **4/4 `verified-live`**.

## Done conditions

- [x] Claim #4 flipped to `verified-live 2026-06-28` in `BEHAVIOURAL-CLAIMS.md`, gated on the honest live result.
- [x] A tracked `tests/dogfood/repro-fixture/` — the `contract-under-review.yaml` twin + a constructed,
      hint-stripped `pass1-findings.md` with two `critical` blockers (A true-by-fixture, B false-by-fixture).
- [x] A live independent reasoning-blind pass-2 (Sonnet, different model) ran on it; **Dogfood D4** records
      its actual output: A reproduced/kept blocking, B not-reproduced/downgraded to minor, `[pass-2/sonnet]`.
- [x] Contamination caught + corrected: the first pass-1 artifact's setup hint was caught by the verifier's
      `not_has`, stripped, and pass-2 re-spawned clean; the clean run is what is recorded.
- [x] `working/dogfood-repro-d4-verify.sh` asserts the recorded two-directional catch (behaviour, not
      presence) + fixture tracked/hint-stripped/true-false-by-construction + backlog 4/4; PASSES.
- [x] RUNBOOK step 5c + docs updated; CHANGELOG 0.31.4 + VERSION; verifier-lib --self-test; dev.sh 6/6; residuals R1 HIGH=0.

## Guardrails

- Do **not** edit `skills/claude-warp-new-harness` (the reproduction charter is correct, the claim was unverified).
- Do **not** touch `has`/`md_has`/`chk`/`not_has` semantics.
- Leave the D1/D2/D3 dogfood logs intact (record of what was believed/done then).

## Verifier

`bash working/dogfood-repro-d4-verify.sh && bash scripts/verifier-lib.sh --self-test && bash scripts/dev.sh verify`

## Execution log

- 2026-06-28 — Phase-2 read of the v0.30.0 charter (`skills/claude-warp-new-harness/SKILL.md`), claim #4,
  the twin, and CHANGELOG. Built `repro-fixture/` (twin + constructed pass-1 with A true / B false).
  Spawned a live Sonnet pass-2 reasoning-blind: it reproduced A (kept blocking, quoting `check: "true"`)
  and did **not** reproduce B (downgraded to minor, quoting `loop_max_usd: 5` present), `[pass-2/sonnet]`,
  `qa_status: pending`. The first pass-1 artifact carried a setup hint ("one is true/false-by-fixture");
  the verifier's `not_has` caught it → stripped → pass-2 re-spawned clean (same outcome, no hint). Claim
  #4 flipped `unverified → verified-live 2026-06-28`; backlog now **4/4 verified-live**. Verifier PASS;
  self-test; dev.sh 6/6; residuals R1 HIGH=0. COMPLETE 6/6.
