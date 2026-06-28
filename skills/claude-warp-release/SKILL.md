---
name: claude-warp-release
description: Release-readiness gate distinct from "task done" / "PR merged" — assess whether a release is ready, package the evidence, and emit a two-tier verdict (hard BLOCK on mechanical boundaries, advisory WARN+Surface on the severity judgment). Read-only; never tags or pushes — it prints the commands
---

Release-readiness gate for: `$ARGUMENTS`

Run this **before** cutting a release, to answer one question honestly: *is this actually ready to
ship, or just merged?* **"PR merged" is not "release ready."** A merged change can still ship with an
un-bumped VERSION, a missing CHANGELOG entry, leftover `[Unreleased]` work, a tag that already
exists, or a bump whose size doesn't match what changed. This skill catches those at the boundary.

**This skill is READ-ONLY.** It never runs `git tag`, `git commit`, `git push`, or `gh release` — it
**assesses**, **packages the evidence**, and **prints the exact commands** for a human or agent to
run. Keeping the readiness-checker independent of the shipper is deliberate: the thing that certifies
"ready" must not also be the thing that ships (constitution P2). The act of releasing stays a Surface.

**Self-host safe.** If there is no `CHANGELOG.md` or `VERSION`, it prints
`not applicable — no CHANGELOG.md / VERSION` and **exits 0** (no behaviour change, no manifest
required).

## Inputs

Parse `$ARGUMENTS` for optional flags:
- `--changelog <path>` (default `CHANGELOG.md`)
- `--version-file <path>` (default `VERSION`)
- `--verify <cmd>` (the per-iteration verifier / `stop.check` to run as evidence; default: the
  contract's `stop.check` if a `contract.yaml` is present, else skipped with a `not run` note)

If neither `CHANGELOG.md` nor `VERSION` exists, report not-applicable and exit 0 (see above).

## The verdict model — two tiers

Every finding is one of two kinds. **Do not collapse them into one** — that is the whole point.

| Tier | Applies to | When it fires |
|---|---|---|
| **BLOCK** (hard, fail-closed) | **mechanical** boundaries — objective, zero inference | the check has a single right answer and it failed |
| **WARN** (advisory, Surface) | the **one judgment** call — bump severity vs change type | an LLM classification *suspects* a mismatch |

A BLOCK means **not release-ready** (overall verdict BLOCK). A WARN never sets the overall verdict to
BLOCK on its own — it Surfaces for the human to confirm or override (constitution P3/P6: a Type-B
judgment is never auto-resolved into a hard verdict). Overall verdict is **PASS** only when there are
zero BLOCKs **and** every evidence check actually ran and passed (a check that could not run is
`not run`, never green — NOT RUN ≠ pass).

## Phase 1 — Load the release surface (read-only)

Read, without modifying:
- `VERSION` → `NEW_VERSION`.
- The latest release tag: `git describe --tags --abbrev=0` → `LAST_TAG` (none ⇒ this is the first
  release; the "VERSION bumped vs last tag" check is satisfied vacuously).
- `CHANGELOG.md` → the top dated section and any `[Unreleased]` section.
- The commit range since the last tag: `git log --oneline ${LAST_TAG}..HEAD` (or all history if no
  tag) — the raw material for the change-type inference in Phase 3.
- `contract.yaml` `stop.check` (if present) → the evidence command, unless `--verify` overrides it.

## Phase 2 — Mechanical checks (each is a hard BLOCK)

Run each objective boundary. None of these require judgment; each has a single right answer, so each
fails closed.

| # | Check | BLOCK when |
|---|---|---|
| M1 | **VERSION bumped** | `NEW_VERSION == LAST_TAG` (stripped of a leading `v`) — nothing to release |
| M2 | **VERSION is valid SemVer** | not `MAJOR.MINOR.PATCH` |
| M3 | **CHANGELOG has a matching dated entry** | no section header for `NEW_VERSION` with a date |
| M4 | **Tag does not already exist** | `git rev-parse v$NEW_VERSION` (or `$NEW_VERSION`) resolves |
| M5 | **`[Unreleased]` not left populated** | an `[Unreleased]` section still holds entries (the "never leave Unreleased populated with complete work" rule) |
| M6 | **Working tree clean** | `git status --porcelain` is non-empty (uncommitted/untracked changes) |

For each, record `ok` / `BLOCK` with the concrete reason. Use single-line, undecorated matching when
grepping the CHANGELOG — markdown soft-wrapping and `**bold**` decoration break naive multi-word
greps (a recurring defect in this repo's own verifiers).

## Phase 3 — Severity judgment (advisory WARN + Surface)

This is the **one** check that is a judgment, not a boundary. Classify the change type from the
commit range and the CHANGELOG top section, then compare to the actual bump size:

- **MAJOR** — a breaking change to a public API, install flow, or CLI/skill contract.
- **MINOR** — a new skill, command, capability, or feature.
- **PATCH** — a fix, doc update, or dependency/component change.

When multiple types land together, the **highest** wins (MINOR beats PATCH; MAJOR beats MINOR).
Compute `EXPECTED_BUMP` from the classification and compare to the observed bump (`LAST_TAG` →
`NEW_VERSION`).

- If they match: record `ok`.
- If they differ: **WARN** — state the observed bump, the inferred change type, the evidence you
  classified from (which commits / CHANGELOG lines), and the bump you'd expect. **Surface it** for
  the human to confirm or override. **Never escalate this to a BLOCK** — the classification is an
  inference and can misread; auto-blocking a legitimate release on a guess is exactly the
  verifier-theater the constitution forbids (P3/P6). Be explicit that this is a *suspicion*, not a
  verdict.

## Phase 4 — Package the evidence

Gather, do not act:
- **Verifier output** — run the evidence command (`--verify`, or the contract `stop.check`). Record
  PASS/FAIL/`not run`. A `not run` (no command available, or it could not execute) is **not** a pass
  and downgrades the overall verdict away from PASS.
- **Residuals** — run `scripts/check-ai-residuals.sh --risk <R>` if present (R from `contract.yaml`,
  else R2). Blocking at R2+.
- **Diffstat since last tag** — `git diff --stat ${LAST_TAG}..HEAD` (a one-glance summary of what is
  being shipped).

## Phase 5 — Report

Print a single packaged report. Never write files; never run release commands.

```
Release gate: <NEW_VERSION>   (last tag: <LAST_TAG>)

  Verdict     : PASS | BLOCK            ← BLOCK if any mechanical check failed
  Mechanical  : M1..M6  <ok / BLOCK: reason each>
  Severity    : ok | ⚠ WARN — observed <bump>, inferred <type>, expected <bump> (evidence: …)
  Evidence    : verifier <PASS|FAIL|not run> · residuals <clean|blocked|n/a> · diffstat <N files>
  ⚠ Surfaced  : <severity WARN held for your decision, or "none">

Next (run only when the verdict is PASS and any WARN is resolved):
  git tag -a v<NEW_VERSION> -m "<NEW_VERSION> — <headline>"
  git push origin v<NEW_VERSION>
  gh release create v<NEW_VERSION> --title "…" --notes "…"
  bash scripts/ledger.sh record --kind goal --slug <slug> --event shipped \
       --version <NEW_VERSION> --note "<headline>"   # log the release to the cross-session ledger
```

On BLOCK, name every failing boundary and the concrete fix; do **not** print the release commands as
runnable (the gate has not passed). On a not-applicable repo, the single not-applicable line + exit 0.
The ledger line is **printed, never run** — releasing stays a Surface and the gate stays read-only (P2).

## Notes

- **Read-only.** The skill never tags, commits, or pushes — releasing is a Surface (P3). It only ever
  *prints* the commands. This keeps the gate independent of the act it gates (P2).
- **Two tiers, never merged.** Mechanical boundaries fail closed (P5: objective ⇒ hard gate); the one
  judgment Surfaces (P3/P6: a Type-B call is never auto-resolved). Collapsing them — blocking on the
  severity guess, or only warning on a missing CHANGELOG entry — is the failure mode this design
  exists to avoid.
- **NOT RUN ≠ pass.** An evidence check that could not execute is `not run`, never green; it prevents
  an overall PASS. The gate fails closed when it cannot see.
- **Self-host safe.** Runs with no `harness-manifest.json` and no `contract.yaml`. With no
  `CHANGELOG.md` / `VERSION` it is a no-op (exit 0). Invoked explicitly; nothing depends on a manifest.
- **Operationalizes the SemVer rule.** It turns the "cut a release per complete self-contained batch,
  highest-severity type wins, never leave `[Unreleased]` populated" convention into a checkable gate —
  the convention made executable, the same way the contract made plan-rigor executable.
