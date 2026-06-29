# Archive — completed one-off artifacts

Finished work artifacts moved out of the repo root once each was done and shipped. Kept as an
audit trail; **none are referenced by any live skill or doc**. Files are grouped by **kind** into
subfolders, and each filename is **prefixed with its completion date** so every folder reads
chronologically.

Append-only **logs** are deliberately **left in the repo root** — they track ongoing history, not
one-off deliverables: `RETRO.md`, `CHANGELOG.md`, `BEHAVIOURAL-CLAIMS.md`,
`.claudewarp/ledger.jsonl`, and the gitignored `CLAUDE_WARP_UPDATE_LOG.md`.

## `GOALS/` — completed `/claude-warp-contract` goal-state files (doc-30)

| Goal file | What it was | Outcome |
|---|---|---|
| `2026-06-26-improve-planning-skills-GOAL.md` | Improve the contract + router planning skills | ✅ shipped in **v0.13.0** |
| `2026-06-26-plugin-install-GOAL.md` | Install ClaudeWarp as a Claude Code plugin | ✅ shipped in **v0.16.0** |
| `2026-06-28-honesty-riders-GOAL.md` | Honesty riders (confidence-cap, unverified-set) for the worth-it gate | ✅ shipped in **v0.28.0** |
| `2026-06-28-md-has-italic-gap-GOAL.md` | Close the `md_has` italic-matching gap in the verifier lib | ✅ shipped in **v0.28.1** |
| `2026-06-28-red-team-checker-GOAL.md` | Red-team the residuals checker | ✅ shipped in **v0.29.0** |
| `2026-06-28-reproduction-required-GOAL.md` | Reproduction-required charter for QA findings | ✅ shipped in **v0.30.0** |
| `2026-06-28-behavioural-claim-backlog-GOAL.md` | Behavioural-claim backlog + controlled vocab | ✅ shipped in **v0.31.0** |
| `2026-06-28-verifier-lib-not-has-GOAL.md` | Add `not_has` to `verifier-lib.sh` | ✅ shipped in **v0.31.2** |
| `2026-06-28-dogfood-converge-d3-GOAL.md` | Correct the `/converge` claim (#3) + live D3 dogfood | ✅ shipped in **v0.31.3** |
| `2026-06-28-dogfood-repro-d4-GOAL.md` | Live D4 dogfood of reproduction-required (claim #4) | ✅ shipped in **v0.31.4** |
| `2026-06-28-mdhas-pattern-guard-GOAL.md` | Pattern guard for `md_has` | ✅ shipped in **v0.31.5** |
| `2026-06-28-corroboration-rigor-GOAL.md` | Corroboration rigor for merge-gating PASS (Option 2.5) | ✅ shipped in **v0.32.0** |
| `2026-06-29-devsh-hardening-GOAL.md` | Harden `scripts/dev.sh verify` checks | ✅ shipped in **v0.32.1** |
| `2026-06-29-dogfood-d5-GOAL.md` | Live D5 dogfood (claim #5) | ✅ shipped in **v0.32.2** |

## `CONTRACTS/` — approved goal contracts

| Contract | What it was | Outcome |
|---|---|---|
| `2026-06-26-unified-planner-contract.yaml` | Unify the planning entry point + clarify the model | ✅ shipped in **v0.15.0** |
| `2026-06-29-dogfood-d5-contract.yaml` | Goal contract for the D5 dogfood | ✅ shipped in **v0.32.2** |

## `SCRIPTS/` — spent one-shot runners

| Script | What it was | Outcome |
|---|---|---|
| `2026-06-26-run-plugin-install.sh` | Headless runner that drove the plugin-install goal | ✅ goal shipped in **v0.16.0** |

## `FEATURES/` — spent harness decompositions

| Features file | What it was | Outcome |
|---|---|---|
| `2026-06-26-unified-planner-features.json` | 6-subplan harness decomposition for the unified planner | ✅ shipped in **v0.15.0** |
