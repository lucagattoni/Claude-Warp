# Goal: dev.sh hardening — reviewer-guard in CI + claim-count coherence (v0.32.0 retro)

slug: devsh-hardening · kind: goal · risk: R1

## Objective

Close the two improvements the corroboration-rigor retro held out of v0.32.0: get the new shared
executable (`reviewer-guard.sh`) under the CI self-test net, and make the `M/N` verified-live backlog
count impossible to half-land across files by computing it from the registry and cross-checking the prose.

## Done conditions

- [x] `scripts/reviewer-guard.sh --self-test` is run by `dev.sh verify` step 6, alongside `verifier-lib.sh`
      + `ledger.sh` (header updated; absent-file branch handled).
- [x] New `dev.sh verify` **step 7 — behavioural-claim count coherence**: computes `verified/total` from
      `BEHAVIOURAL-CLAIMS.md` claim headings and asserts the literal appears in **both** the backlog and
      `docs/loop-harness.md`; fails on drift in either file or the registry.
- [x] Check labels renumbered `[N/6]` → `[N/7]`; `docs/loop-harness.md` description updated
      "six → seven deterministic checks" (both occurrences).
- [x] `working/devsh-hardening-verify.sh` asserts step-7 fn present + reviewer-guard wired into step 6 +
      `/7` renumber + docs "seven" + that `dev.sh verify` actually reports 7/7 and the count check fires
      (computes 4/5); PASSES.
- [x] CHANGELOG `[0.32.1]` (PATCH) + VERSION; `dev.sh verify` 7/7; residuals R1.

## Guardrails

- Additive only: dev.sh checks may get **stricter**, never looser; no charter, matcher, or claim change.
- Step 7 READS `BEHAVIOURAL-CLAIMS.md` — it must not edit it; the count stays 4/5 (claim #5 unverified).
- Do not change `reviewer-guard.sh` internals — only add it to the CI net.

## Verifier

`bash working/devsh-hardening-verify.sh && bash scripts/dev.sh verify`

## Execution log

- 2026-06-29 — Phase-2 read of `dev.sh` step 6 + the run() invocation list + the docs "Six deterministic
  checks" description. Folded `reviewer-guard.sh` into step 6; added `check_claim_count_coherence` (step 7,
  computes the count from the registry and cross-checks both files); renumbered `/6 → /7`; updated docs.
  `dev.sh verify` reports 7/7 (count check: 4/5 verified-live, registry == prose). CHANGELOG 0.32.1 +
  VERSION. COMPLETE.
