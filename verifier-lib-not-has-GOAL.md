# Goal: Add a `not_has` absence-assert helper to verifier-lib.sh

**Slug:** verifier-lib-not-has · **Risk:** R1 · **Contract:** contract.yaml

## Objective

Give ClaudeWarp verifiers a shared **absence-assert** — `not_has <pat> <file>` — that echoes rc 0
when the pattern is ABSENT and rc 1 when present, composing with `chk` exactly like `has`/`md_has`.
Formalizes the inline `[ "$(has …)" -ne 0 ] && echo 0 || echo 1` idiom repeated ~6× in the
self-test and hand-rolled in the v0.31.1 Dogfood-D2 verifier. The retro's #2 improvement, flagged
across three retros.

## Done conditions

- [ ] `not_has() { … }` added to `scripts/verifier-lib.sh` (inverse of `has`: echoes 0 absent, 1 present).
- [ ] Header usage comment lists `not_has` alongside `has`/`md_has`/`chk`, incl. the missing-file wrinkle.
- [ ] `--self-test` gains a case proving not_has = 0 on absent, 1 on present, and chk-composition.
- [ ] `docs/loop-harness.md` helper enumeration gains a `not_has` bullet.
- [ ] `working/verifier-lib-not-has-verify.sh` asserts not_has BEHAVIOUR (not mere presence) and PASSES.
- [ ] `verifier-lib --self-test` green; `dev.sh verify` 6/6; residuals R1 HIGH=0.
- [ ] CHANGELOG `[Unreleased]`/PATCH entry + VERSION bumped.

## Guardrails

- Additive only — `has`/`md_has`/`chk` semantics unchanged (regression-guarded by existing self-test cases).
- No merge-gating skill logic touched.

## Verifier

`bash scripts/verifier-lib.sh --self-test && bash working/verifier-lib-not-has-verify.sh && bash scripts/dev.sh verify`

## Execution log

- (pending implementation)
