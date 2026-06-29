# Goal — Documentation restructure (Diátaxis)

**Shape:** goal (single-shot) · **Risk:** R1 · **Contract:** `contract.yaml`

## Objective

Restructure ClaudeWarp's documentation so a **beginner** with zero loop / Claude-Code-lifecycle
knowledge can get a working result in ~10 minutes, while a **senior Claude Code developer** can skip
the intro and reach a function overview + deep reference fast. Keep the GitHub-facing surface slim;
push detail into nested `docs/reference/` (expert) and `docs/guides/` (how-to) subfolders, following
the **Diátaxis** model (Daniele Procida, https://diataxis.fr).

## Done conditions

- [x] `docs/quickstart.md` exists: plain-English primer (what an autonomous loop is + the
      `claude -p` / headless-runner / scheduling lifecycle) → **Part 1** one-shot GOAL (instant win,
      no scheduling) → **Part 2** graduate to a recurring LOOP (with scheduling). One happy path.
- [x] `README.md` is a slim launcher: plain-English what/why, condensed install, two prominent paths
      (🐣 beginner→quickstart, 🚀 expert→reference), the Skills table (all 15), a docs map. Design
      essay + Plan-vs-Shape teaser reduced to one-line pointers into docs.
- [x] `docs/loop-harness.md` is split into `docs/reference/{skills.md, templates.md, architecture.md,
      developing.md}` and removed. All 15 skills have a `### `/claude-warp-<name>`` section in
      `skills.md`. Reviewer-design + behavioural-claim backlog (with the literal `5/6`) live in
      `architecture.md`. Prior-art & acknowledgements + dev.sh/verifier-lib live in `developing.md`.
- [x] `docs/usage.md` is split into `docs/guides/{scheduling.md, monitoring.md, iterating.md,
      deployment.md}` and removed.
- [x] `docs/concepts.md` keeps a plain-English on-ramp then the Plan-vs-Shape content (canonical home
      of the teaser moved from README).
- [x] `docs/install.md` + `docs/goal-readiness.md` kept; inbound/outbound links fixed.
- [x] `scripts/dev.sh` check 5 repointed to `docs/reference/skills.md`; check 7 repointed to
      `docs/reference/architecture.md`; header comment updated. Both keep their self-host `[ -f ]` guards.
- [x] All **live** cross-links repointed (README, docs/, skills/, templates/, CLAUDE.md) — nothing
      live points at `docs/loop-harness.md` or `docs/usage.md`. (CHANGELOG/RETRO/plans/archive keep
      their historical references — out of scope, and rewriting release history would break P6.)
- [x] `scripts/dev.sh verify` → **8/8 PASS**.
- [x] Every internal doc link resolves (no broken relative `*.md` links in live docs).
- [x] CHANGELOG `[Unreleased]` entry + VERSION bumped (PATCH) + `.claude-plugin/plugin.json` synced.

## Verifier

`working/docs-restructure-verify.sh` (one-shot, gitignored per the per-PR-verifier convention; pruned after merge) asserts:
the four reference files + four guide files + quickstart exist; loop-harness.md & usage.md are gone;
all 15 skill headings present in skills.md; `5/6` present in architecture.md; no live orphan refs;
every relative link in live docs resolves; then runs `scripts/dev.sh verify`.

## Guardrails

- No skill **behaviour** change — only doc-link prose inside SKILL.md files.
- No install/CLI command change — only README/doc prose around them.
- Do not edit CHANGELOG/RETRO/BEHAVIOURAL-CLAIMS content beyond what the release requires.

## Execution log

- 2026-06-29 — Contract approved (R1), artifacts materialised, branch `docs/restructure-diataxis`.
- 2026-06-29 — **COMPLETE.** Built `docs/reference/{skills,templates,architecture,developing}.md` and
  `docs/guides/{scaffolding,scheduling,deployment,monitoring,iterating}.md` from the two split
  monoliths (removed); added `docs/quickstart.md` (goal→loop); rewrote `README.md` as a slim
  launcher; on-ramped `concepts.md`; repointed `dev.sh` checks 5→`reference/skills.md`,
  7→`reference/architecture.md` + all live cross-links + `templates/CLAUDE.md.tpl`; PATCH bump to
  v0.34.3 (VERSION + plugin.json + CHANGELOG). Verifier `working/docs-restructure-verify.sh`:
  **RESULT PASS** (all 8 checks); `dev.sh verify` **8/8**; residuals HIGH=0. All done-conditions met.
