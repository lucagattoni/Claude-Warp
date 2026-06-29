# Goal: corroboration rigor + honest independence (command-verification, same-family label, read-only guard)

slug: corroboration-rigor · kind: goal · risk: R2

## Objective

Deepen the reproduction/independence axis — the project's most load-bearing reviewer discipline — with
three adapt-not-invent additions, none of which needs a second vendor wired in:
- **#1** reproduce a checkable-fact blocker by *executing* a read-only command, not just re-reading it;
- **#2** stop counting same-vendor agreement as full independence (label it honestly);
- **#3** *prove* a spawned reviewer was read-only instead of merely asserting it.

## Done conditions

- [x] **#1 Command-verification** in the pass-2 reproduction charter (`skills/claude-warp-new-harness/SKILL.md`):
      a checkable-fact blocker must be reproduced by a read-only `grep`/`cat`/`head`/`tail`/`wc` command and
      tagged `[CMD_CONFIRMED]`/`[CMD_CONTRADICTED]`; a `[CMD_CONTRADICTED]` blocker is demoted one level;
      advisory (never auto-deletes). `[STATIC-INFERENCE-CONSENSUS]` (same-lines agreement) does not compound.
- [x] **#2 Same-family caveat** in `BEHAVIOURAL-CLAIMS.md` vocabulary: `verified-live` is *same-family
      corroboration (shared blind spots possible)*, never cross-vendor independence; mirrored in
      `docs/loop-harness.md` (discipline rows + narrative). Command-verification registered as **claim #5
      (`unverified`)**; backlog stated honestly as **4/5 verified-live**.
- [x] **#3 Read-only-reviewer guard** `scripts/reviewer-guard.sh` (snapshot/verify/`--self-test`):
      `git status --porcelain` + tracked-content digest before/after a spawned pass; any mutation fails
      loud (exit 3); `working/` scratch ignored. RUNBOOK step 3 wraps the live spawn with it.
- [x] Credits land with the influence — `docs/loop-harness.md` prior-art table + inline charter credits:
      agent-review-panel (wan-huiyan), dementev-dev/adversarial-review, llm-council (karpathy),
      NABAOS/tool-receipts (arXiv 2603.10060), the find/verify framing.
- [x] `working/corroboration-rigor-verify.sh` asserts the charter rules + tags + claim #5 unverified + 4/5
      count + credits mapped (behaviour-leaning, not bare presence); PASSES.
- [x] CHANGELOG `[0.32.0]` (MINOR) + VERSION; `reviewer-guard --self-test`; `verifier-lib --self-test`;
      `dev.sh verify` 6/6; residuals R2.

## Guardrails

- Do **not** change `has`/`md_has`/`not_has`/`chk`/`md_normalize` matcher semantics.
- Do **not** relabel claims #1–#4 — only ADD the same-family caveat + claim #5.
- Do **not** touch `skills/claude-warp-converge` (correct and unrelated).
- Claim #5 ships `unverified` — do not assert command-verification as `verified-live` without a live D5.

## Verifier

`bash working/corroboration-rigor-verify.sh && bash scripts/reviewer-guard.sh --self-test && bash scripts/verifier-lib.sh --self-test && bash scripts/dev.sh verify`

## Execution log

- 2026-06-28 — Phase-2 read of the reproduction charter (`skills/claude-warp-new-harness/SKILL.md`), the
  contract Skeptic/honesty riders, `BEHAVIOURAL-CLAIMS.md` vocab + claim #4, and the docs discipline +
  prior-art tables. Added #1 (command-verification + static-inference-consensus) to the reproduction charter
  with inline credits; #2 same-family caveat to the vocabulary + docs, registered claim #5 `unverified`
  (backlog 4/5); #3 `scripts/reviewer-guard.sh` (self-test PASS, 5 cases) + RUNBOOK step-3 wrap. Credits
  added to the prior-art table now that the influence lands. CHANGELOG 0.32.0 + VERSION.
