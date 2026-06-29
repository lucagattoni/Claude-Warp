# Goal: encode the md_has pattern-authoring rule in verifier-lib.sh (retro #2)

slug: mdhas-pattern-guard · kind: goal · risk: R1

## Objective

Stop the recurring first-run verifier FAIL where an author writes a `.` placeholder for a backtick that
`md_normalize` already strips. Document the rule where authors read it and guard it with a live
self-test — comment + test only, no matcher-semantics change.

## Done conditions

- [x] A `⚠ Writing md_has PATTERNS` note in the `verifier-lib.sh` header (surfaced by `--help`), stating:
      match the normalized text; never a `.` placeholder for a stripped backtick.
- [x] Two new `--self-test` (case 8) asserts: the normalized literal matches; the `.`-placeholder pattern
      must NOT match.
- [x] `has`/`md_has`/`not_has`/`chk`/`md_normalize` semantics unchanged; all existing self-test cases pass.
- [x] `working/mdhas-pattern-guard-verify.sh` asserts the note + both guard cases + CHANGELOG/VERSION and
      that the self-test PASSES (behaviour, not presence); PASSES.
- [x] CHANGELOG `[0.31.5]` + VERSION; verifier-lib --self-test; dev.sh 6/6; residuals R1.

## Guardrails

- Do **not** alter `md_normalize` or the matcher semantics — comment + test only.
- Do **not** touch `BEHAVIOURAL-CLAIMS.md` (the backlog is closed at 4/4).

## Verifier

`bash working/mdhas-pattern-guard-verify.sh && bash scripts/verifier-lib.sh --self-test && bash scripts/dev.sh verify`

## Execution log

- 2026-06-28 — Phase-2 read of `scripts/verifier-lib.sh`. Added the `⚠ Writing md_has PATTERNS` header
  note (rendered by `--help`) and case-8 self-test guards (literal matches; `.`-placeholder fails).
  Self-test PASS (incl. the two new asserts); `--help` renders the note; dev.sh 6/6; residuals R1.
  CHANGELOG 0.31.5 + VERSION. COMPLETE.
