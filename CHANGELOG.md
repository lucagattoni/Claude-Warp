# Changelog — ClaudeWarp

Versioning follows [Semantic Versioning](https://semver.org/):
- **MAJOR** — breaking change to install flow or skill API
- **MINOR** — new skill or harness capability added
- **PATCH** — fix, doc update, or component superseded by native CC feature

## [Unreleased]

## [0.30.0] — 2026-06-28

### Added
- **Reproduction-required corroboration on the merge-gating reviewers (Option 2.5 of the
  multi-lens-review design — the cheapest real-independence proxy).** The red-team charter (v0.29.0)
  made each reviewer sharper, but every reviewer is still same-model. Option 2.5 adds independence
  without a second vendor or a panel: a finding only counts if it **reproduces**, and a merge-gating
  PASS must be **corroborated**, not solo. Additive to the v0.28.0 honesty riders + v0.29.0 charter:
  - **`skills/claude-warp-new-harness/SKILL.md`** — the QA evaluator persona gains a
    **Reproduction-required corroboration** section: when invoked as the reproduction pass, a blocking
    (critical/major) finding reverts the task **only if it independently reproduces**; an unreproduced
    finding is **downgraded** to a recorded non-blocking minor. A merge-gating PASS is
    `approved (corroborated)` only if the second pass agrees; if the second pass can't run, the verdict
    is marked `uncorroborated — single-pass` **loudly** (P6: NOT corroborated ≠ corroborated). The
    runner Phase 6 gains a **`--corroborate`** flag — **auto-on at R3+**, opt-in at R2 and below —
    that runs ONE reproduction pass on a **different in-house model** via `CLAUDEWARP_QA_MODEL`
    (Opus↔Sonnet, near-free diversity). Every finding/verdict carries a `[pass-N / model]` **provenance
    tag** so agreement is N traceable data points, not headcount.
  - **`skills/claude-warp-contract/SKILL.md`** — the `stop.evidence` rule gains a corroboration clause
    (at R2+, a merge-gating PASS should be reproduced/corroborated; a solo green is labeled
    `uncorroborated`, never silently counted as full evidence) plus a Phase 6 critical-pass row.

  `--corroborate` rides **behind** the existing `--with-qa` gate (no first pass ⇒ nothing to corroborate
  ⇒ no-op). It is **one sequential second pass**, not a panel (Option 3, held), on a different *in-house*
  model, not cross-vendor (Decision 3a, held). A downgrade or `uncorroborated` mark **Surfaces** a
  Type-B call; it never silently downgrades a human-gated decision. Prototype-grade (analysis verdict:
  *iterate*) — the verifier asserts each mechanism is present; the end-to-end false-positive-drop is
  confirmable only in live dogfooding.

### Credits
- Adapts external prior art, credited where each mechanism lives (the skills, `docs/loop-harness.md`):
  **/ultrareview** (Anthropic — `/code-review ultra`) — reproduction-required (a finding counts only if
  a second pass reproduces it); **alecnielsen/adversarial-review** + the **ng** fork — consensus-gating
  (a finding needs corroboration to count; solo ≠ confirmed); **robertoecf/adversarial-review** —
  provenance tags + graceful-degradation-loud. The different-in-house-model reproduction is Decision-3
  b.5 (cross-model same-vendor) from the analysis.

### Docs
- `docs/loop-harness.md` documents Option 2.5 (element × seam × source table) and extends the prior-art
  credit table with the **/ultrareview**, **alecnielsen/ng**, and **robertoecf** rows.

## [0.29.0] — 2026-06-28

### Added
- **Red-team / Skeptic charter on the independent reviewers (Option 2 of the multi-lens-review design).**
  The two places ClaudeWarp spawns an independent reviewer now carry a "try to **break** it, not confirm
  it" charter, additive to the v0.28.0 honesty riders:
  - **`skills/claude-warp-contract/SKILL.md` Phase 6** — the R3+ checker spawn charter is upgraded from
    "raises blocking findings" to a red-team brief (which acceptance criteria / `stop.check` admit a
    trivially-passing implementation — empty stub, hardcoded value, a check that always exits 0? which
    load-bearing claim was assumed, not verified?), made explicitly **reasoning-blind** (judges
    `contract.yaml` + repo, not the drafting conversation's reasoning) and a **single fresh-context
    pass** (no debate loop). Two red-team rows are added to the critical-pass checklist.
  - **`skills/claude-warp-new-harness/SKILL.md`** — the QA evaluator persona gains the same Skeptic
    charter including **control-validation** (a passing `cmd:` must be confirmed to FAIL on a broken
    implementation — *a check that can't fail proves nothing*), and the optional DOER/CHECKER spawn
    prompt gains the red-team brief.

  A clean red-team result is valid (anti-fabrication still binds — no manufactured breaks); a
  "trivially-passing AC" that is actually a deliberate human-gated decision **Surfaces** as a Type-B
  call, never auto-fails. Same-model reasoning-blind neutralizes author-bias, not a shared model-family
  blind spot (that is Option 2.5, held). Strengthens the reviewers already spawned — it does **not** add
  a parallel review panel (Option 3, held).

### Credits
- Adapts external prior art, credited where each mechanism lives (the skills, `docs/loop-harness.md`):
  **CCH TeamAgent Debate** (Chachamaru127) — the Skeptic / try-to-break charter + trivially-passing-AC
  check; **brandonsimpson/devils-advocate** (MIT) — reasoning-blind grading; **agent-review-panel**
  (wan-huiyan) — control-validation; **Karpathy LLM Council** → **/council** — the single fresh-context
  pass.

### Docs
- `docs/loop-harness.md` documents the red-team charter (element × seam × source table) and extends the
  prior-art acknowledgements table with the **agent-review-panel** (wan-huiyan) row plus the v0.29.0
  influence on the CCH, devils-advocate, and llm-council rows.

## [0.28.1] — 2026-06-28

### Fixed
- **`scripts/verifier-lib.sh` — closed the `_italic_` / underscore-emphasis gap in `md_has`.** The
  markdown-aware matcher now strips single-underscore `_italic_` emphasis **boundary-aware** (only a
  complete `_word_` pair flanked by non-word chars), so a prose phrase split by underscore emphasis is
  reunited and found — the gap that had taxed verifier authors on four consecutive PRs (each
  hand-anchoring assertions on single-line tokens to dodge it). `snake_case` (`must_not_touch`),
  leading-underscore identifiers (`_phase`, used by contract drafts), and `__dunder__` / `mcp__tool__`
  runs are all provably preserved. Raw `has()` is unchanged. The `--self-test` flips its two former
  KNOWN-GAP asserts to expect the gap **closed** and adds regression asserts for the preserved-identifier
  cases. Surfaced by the honesty-riders retro (improvement #1). Chosen as a direct fix to `md_has`
  rather than an opt-in `md_has_loose` — an opt-in would perpetuate the "author must remember to use
  it" fragility the retro flagged.

## [0.28.0] — 2026-06-28

### Added
- **Honesty riders on ClaudeWarp's verdict outputs** (Option 1 of the multi-lens-review design space):
  five riders that keep a review from becoming verifier theater, added to the three existing
  verdict-emitting surfaces — the contract critical pass (`claude-warp-contract` Phase 6), the contract
  worth-it verdict (Phase 1.5), and the harness QA evaluator (`claude-warp-new-harness` Phase 5b). They
  **extend** the seams ClaudeWarp already owns — no review panel, no parallel subsystem, no new runtime.
  Two riders bind at **every risk tier**; three bind at **R2+** (advisory below, so small R0/R1 goals
  are not taxed with ceremony):
  - **Anti-fabrication** (all tiers) — "no blockers" is a valid result; never manufacture findings to
    look thorough. Adapted from [devils-advocate](https://github.com/brandonsimpson/devils-advocate)
    (brandonsimpson, MIT).
  - **Anonymized-author** (all tiers) — judge the artifact on its merits with author identity/reasoning
    set aside first, to remove self-preference bias; works even same-model. Adapted from
    [llm-council](https://github.com/karpathy/llm-council) (Andrej Karpathy) → `/council`.
  - **Severity→verdict gating** (R2+) — findings carry `critical | major | minor | recommendation`; only
    critical/major block, minor/recommendation are recorded and never stall the loop (the QA evaluator
    gains an `approved_with_notes` status). Adapted from
    [claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) (Chachamaru127, *CCH
    TeamAgent Debate*).
  - **Confidence-capped-by-verified-ratio** (R2+) — verdicts end with a `confidence: N/10` line + a
    "M of K load-bearing claims actually verified; confidence capped by that ratio" tally. Adapted from
    [idea-to-ship-skills](https://github.com/nelsonwerd/idea-to-ship-skills) (nelsonwerd).
  - **"Unverified" set** (R2+) — every verdict lists what it did **not** check, making P6 (NOT RUN ≠
    pass) visible in the output rather than implicit. Adapted from devils-advocate (linked above).

  Adapted **critically**: severity gating still routes a Type-B judgment call to Surface (it never
  auto-resolves a `minor` that is actually a hidden decision — constitution P3); the anonymized-author
  rider is same-model, so it neutralizes author-bias, not a shared-model-family blind spot.

### Docs
- **`docs/loop-harness.md`** — new "Honesty riders (verdict outputs)" subsection under the contract
  skill, with the rider × tier × source table; prior-art table extended to credit
  [devils-advocate](https://github.com/brandonsimpson/devils-advocate) (brandonsimpson) and
  [llm-council](https://github.com/karpathy/llm-council) (Andrej Karpathy), and the new riders mapped
  onto the existing CCH and idea-to-ship-skills rows.

## [0.27.0] — 2026-06-28

### Added
- **Attribution check in the contract critical pass** (`claude-warp-contract` Phase 6): a new
  "External prior art credited?" row that flags uncredited borrowing — any contract adapting an
  external project/resource must credit it by full name + author + link (and the specific source
  artifact) where the mechanism lives, and adapt it critically. Makes crediting external sources a
  **general, enforced rule** of the negotiation, not a per-PR habit.

### Docs
- **Credit the prior-art projects** that shaped ClaudeWarp's design, by full name, author, and link.
  Adds a **Prior art & acknowledgements** section to `docs/loop-harness.md` crediting
  [PAUL](https://github.com/ChristopherKahler/paul) (Christopher Kahler),
  [claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) (Chachamaru127),
  [idea-to-ship-skills](https://github.com/nelsonwerd/idea-to-ship-skills) (nelsonwerd), and
  [spec-kit](https://github.com/github/spec-kit) (GitHub), mapped to the features each influenced.
  Also credits PAUL inline (full name + `apply-phase.md` link) in the `claude-warp-new-harness`
  runner comment and the 0.26.0 changelog entry, rather than a bare "PAUL".

## [0.26.0] — 2026-06-28

### Added
- **Diagnostic failure routing** in the harness runner's `--retry` path (`claude-warp-new-harness`),
  adapted from the diagnostic-failure-routing design in the [PAUL project](https://github.com/ChristopherKahler/paul)
  (*Plan · Apply · Unify Loop*, by Christopher Kahler). On a `MAX_ITER` stall, the runner now **classifies the root
  cause** into one of three layers via a small read-only classifier agent and routes accordingly,
  instead of blindly re-decomposing every stall:
  - **code** ("plan was correct, implementation doesn't match") → re-run the coding loop **in place**, no re-decompose;
  - **spec** ("plan was missing something or mis-scoped a task") → clear tasks and re-invoke the initializer with stall context (the prior `--retry` behaviour);
  - **intent** ("the goal wants something *different* than planned") → **Surface to a human and stop (exit 3)** — re-planning the same goal cannot fix a wrong goal, so this is a Type-B judgment call that never auto-resolves (constitution P3).
  An uncertain/unparseable verdict falls back to **spec**, making the change a strict, non-regressive
  refinement of the prior `--retry`. Routing fires **once** (bounded recovery; a deliberate divergence
  from PAUL's max-3 loop, since the coding loop already iterates internally).

## [0.25.0] — 2026-06-28

### Added
- **Decomposition approval gate** in the harness runner (`claude-warp-new-harness` Phase 6). Between
  the initializer and the coding loop, the runner surfaces the proposed task breakdown
  (wave / id / title / `depends_on`) and **stops for operator review before any budget is spent
  executing it**. Risk-scaled by the same threshold that makes QA non-overridable: **required at
  R2+**, opt-in below via `--approve-plan`. Approve by re-running with `--plan-approved` (or
  `CLAUDEWARP_PLAN_APPROVED=1`); `features.json` persists so the re-run skips the initializer and
  proceeds. Non-interactive by design — a scheduled/unattended harness never auto-executes an
  unreviewed decomposition. Fires on the initial decomposition only, not on a `--retry` re-init.

### CI
- **`.github/workflows/verify.yml`** — run `scripts/dev.sh verify` (the deterministic, non-`--live`
  path) on every pull request and on push to `main`, so the six checks gate merges automatically
  instead of relying on the operator. README gains a `verify` status badge.
- **`actionlint` job** in the same workflow — lints every workflow file (first-party
  `docker://rhysd/actionlint`, pinned by tag) on each PR and push, catching malformed expressions,
  bad keys, and `run:`-script shellcheck issues that GitHub's runtime parser accepts silently.

## [0.24.2] — 2026-06-28

**Retro-hardening batch** (PR12) — four accumulated retro improvements (PR9 + PR10) that sharpen the
planning spine, the release gate, and the dev-gate. No new skill/verb/capability — this *refines* how
existing jobs are done, so per the very rule it codifies (below) it is a **PATCH**, not a MINOR.

### Changed
- **`skills/claude-warp-contract/SKILL.md`** — two hardenings:
  - **Phase 6 critical-pass** gains a "Verifier asserts only tracked paths in git-diff checks?" row.
    A `git diff` against a gitignored/untracked path is always empty — it passes even if the file was
    rewritten (the vacuous-assertion trap caught mid-build in PR9).
  - **Phase 4 interview** now requires that a plan introducing a new persisted file settle its
    **lifecycle** (tracked vs gitignored), not just its format — the gap that surfaced post-ship as
    the v0.24.0 ledger git near-miss.
- **`skills/claude-warp-release/SKILL.md` Phase 3** — sharpened the recurring MINOR/PATCH crux:
  *modifying* an existing skill's behaviour without adding a new skill/verb/capability is **PATCH**;
  *adding* one is **MINOR**; a new internal dev/CI check is not user-facing, so it is a PATCH.
- **`scripts/dev.sh verify`** — new check `[6/6]`: the shared executables (`verifier-lib.sh`,
  `ledger.sh`) each run their own `--self-test`, so a regression in either is caught by the repo's own
  gate, not only when a per-PR verifier happens to source one. (Existing checks renumbered `/5`→`/6`.)

### Docs
- **`docs/loop-harness.md`** — `dev.sh verify` now documents six checks incl. the executable self-tests.

### Process (not code — recorded as memory)
- The two operator-discipline retro items (seeds ride in a PR never direct-to-main; run
  `git status`/`reflog` before any corrective `reset`) were captured as `feedback` memories rather
  than contrived skill edits — they govern how the operator works, not any skill's behaviour.

## [0.24.1] — 2026-06-28

**Ledger is gitignored by default** (PR11; from the v0.24.0 retro). The cross-session closure ledger
is local runtime data — per-checkout persistence, like a log — so it stays out of version control by
default. This settles the storage *lifecycle* the v0.24.0 contract left open (it decided the format,
not whether the file is tracked), which only surfaced post-ship when a seed commit was blocked.

### Changed
- **`.gitignore`** — ignores `.claudewarp/ledger.jsonl` in this repo.
- **`skills/claude-warp-setup/SKILL.md`** — setup now seeds the same ignore line in consuming repos,
  alongside `logs/`, so the default propagates on install.

### Docs
- **`skills/claude-warp-ledger/SKILL.md`** and **`docs/loop-harness.md`** — document that the ledger
  is gitignored by default (append-only entries would otherwise collide on the file tail across
  branches), and how to opt into committing the history.

## [0.24.0] — 2026-06-28

**Persistent cross-session ledger — `/claude-warp-ledger`** (PR10; gap #3's unbuilt half). Closure
events used to die with the context window: once a session ended, "what shipped / what was surfaced /
what a converge pass reconciled" was gone. This adds a queryable, append-only ledger that survives
across sessions — the "what happened, in order" complement to the memory system (which holds semantic
facts, not dated events) and to native cross-run loop state (a loop's own run cursor).

Negotiated as a `kind: goal` (R2): the naive "wire writes into every closure skill" design was partly
unconstitutional — `/claude-warp-release` and `/claude-warp-converge` are read-only (P2) and cannot
acquire side write-paths — so the write is centralized in one skill and the read-only skills only
*print* a record command.

### Added
- **`scripts/ledger.sh`** — the executable core (`record` / `query` / `--self-test`). Append-only
  `.claudewarp/ledger.jsonl`, one JSON object per line. `query` filters by `--kind/--slug/--event/--since`
  and renders a table or (`--raw`) jsonl for `jq`. **Logic lives in the script, not in prose**, so it is
  deterministic and self-testable — a 12-assert `--self-test` exercises the record→query round-trip,
  append-only preservation, self-init, empty-query-no-error, fail-closed required args, and quote/newline
  injection safety. **Self-host safe (P4):** `record` self-creates `.claudewarp/`; `query` over a
  missing/empty ledger prints `(ledger empty)` and exits 0 — no manifest required.
- **`skills/claude-warp-ledger/SKILL.md`** — thin wrapper documenting the verbs and delegating to the
  script; states the boundary against the memory system and native cross-run state.

### Changed
- **`skills/claude-warp-retro/SKILL.md`** — after writing `RETRO.md`, retro now records a `converged`
  closure event to the ledger (retro already writes files, so this stays within its remit). New Phase 6;
  the old summary print is now Phase 7.
- **`skills/claude-warp-release/SKILL.md`** — the PASS "Next" block now prints a ready-to-run
  `ledger record … --event shipped` command. **Printed, never run** — releasing stays a Surface and the
  gate stays read-only (P2).
- **`skills/claude-warp-converge/SKILL.md`** — the report now prints a ready-to-run
  `ledger record … --event converged` command. **Printed, never run** — converge only writes the feature
  list; appending to the ledger is a separate write it does not take (P2).

### Docs
- **`docs/loop-harness.md`** — new `### /claude-warp-ledger` section (storage, verbs, the
  memory/cross-run-state boundary, who records); retro's step list gains the ledger-record step.
- **`README.md`** — Skills-table row for `/claude-warp-ledger`.

## [0.23.1] — 2026-06-28

**Contract-hardening — draft from the code, not from memory of it** (PR9; from PR8's retro). Fixes a
negotiation defect that just cost real work: `/claude-warp-contract` Phase 2 drafted "a complete
contract from the goal alone", with no step to read the current source of files the contract would
*modify* — which is how PR8 came to spec an already-done residuals retrofit, caught only mid-build.

### Changed
- **`skills/claude-warp-contract/SKILL.md` Phase 2** — added a **mandatory pre-draft read step**: for
  every `may_touch` file that already exists (a *modify*, not a new file), read its current source
  before drafting `action`/`scope`, at **any** risk level. New files are exempt. The cost is trivial
  (you read the file to edit it anyway) and it is the cheapest guard against drafting from a stale
  assumption. Risk-independent on purpose — the blind-draft defect is not risk-correlated.

### Added
- **`scripts/verifier-lib.sh` — `_italic_` known-gap self-test.** Two new asserts prove the documented
  limit: because `_`/`__` are deliberately left intact (snake_case safety), a phrase split by
  underscore emphasis is missed by **both** `has` and `md_has`. The boundary is now tested, not just
  commented — if a future change starts stripping `_`, the asserts flip. Self-test: 9 → 11 checks.

### Docs
- **`docs/loop-harness.md`** — documented the forward convention (new per-PR verifiers
  `source scripts/verifier-lib.sh`; `working/pr7-verify.sh` is the reference template) and the
  `_italic_` known gap. Explicitly did **not** migrate the dead `pr1`–`pr6` verifiers (gitignored
  scratch for merged PRs — churn for no value).

## [0.23.0] — 2026-06-28

**Shared markdown-aware verifier matcher** (tooling-debt PR7). Retires a false-negative that bit four
consecutive PRs' per-PR verifiers: a phrase the verifier correctly asserted was present, but raw
`grep` missed because markdown had split or decorated it (`**bold**` markers between words, an
`` `inline code` `` span, or a prose line **soft-wrapped** across two physical lines). Flagged by four
consecutive retros (PR3–PR6) and the `project-markdown-grep-verifier-defect` finding.

### Added
- **`scripts/verifier-lib.sh` — sourceable, markdown-aware matcher for verifiers.** Exposes
  `md_normalize <file>` (strip `` `inline code` ``/`**bold**`/`*italic*` decoration, then join
  soft-wrapped lines into one whitespace-collapsed stream), `md_has <pat> <file>` (markdown-aware
  match for **prose** phrases), the original raw `has <pat> <file>` (for structural/line-anchored
  patterns), and the `chk` assertion printer — so per-PR `working/` verifiers source **one**
  definition instead of redefining raw-grep asserts. Underscores/`__` are left intact so
  `snake_case` identifiers survive. Both matchers **fail closed** (a match over a missing file is
  non-zero — NOT RUN ≠ pass). Carries a `--self-test` that plants each historical defect as a
  fixture and proves `md_has` finds the phrase **while raw `grep` misses it**.

### Changed
- **`docs/loop-harness.md`** and **`README.md`** — document the matcher, the `has` vs `md_has`
  split, and how per-PR verifiers source it (P8).
- **`docs/loop-harness.md`** — promoted `/claude-warp-converge` and `/claude-warp-release` from
  inline `**bold**` subsections to proper `###` sections, clearing a pre-existing
  `scripts/dev.sh verify` docs-coherence failure (both skills had README rows but no matching
  section heading). `verify` is green again.

### Notes
- **Scope narrowed mid-flight (honest):** the contracted "make `check-ai-residuals.sh`
  markdown-aware" half was found **already done** — the residuals gate already skips code-construct
  HIGH patterns for `.md`/`.markdown`/`.txt` (so quoted sample code in docs doesn't false-*positive*).
  Claiming a fix there would have been fake-done (constitution **P6**); the residuals scanner was left
  untouched. This PR addresses only the complementary false-*negative* class in the per-PR verifiers.

## [0.22.0] — 2026-06-28

**Release-readiness gate — "PR merged" is not "release ready"** (follow-up PR6; COMPETITIVE-FINDINGS
gap #4). Adds a release-gate *verb* distinct from "task done" / "PR merged": it assesses whether a
release is actually ready, packages the evidence, and emits a verdict — turning the project's SemVer
convention into a checkable gate. Read-only and self-host safe.

### Added
- **`/claude-warp-release` — new release-readiness gate skill.** Run before cutting a release. It is
  **read-only** (never tags, commits, or pushes — it prints the commands; releasing stays a Surface,
  keeping the readiness-checker independent of the shipper, constitution **P2**) and emits a
  **two-tier verdict**:
  - **BLOCK** (hard, fail-closed) on the **mechanical** boundaries — VERSION not bumped vs the last
    tag, no matching dated CHANGELOG entry, target tag already exists, a still-populated
    `[Unreleased]`, or a dirty tree. Objective checks, each fails closed.
  - **WARN + Surface** on the **one judgment** call — whether the bump *severity* matches the inferred
    change type (breaking→MAJOR, new capability→MINOR, fix/doc→PATCH; highest type wins). A suspected
    mismatch Surfaces for a human and is **never** auto-escalated to a BLOCK (constitution **P3/P6** —
    a Type-B judgment is not auto-resolved into a hard verdict).
  Packages evidence (verifier output + residuals + diffstat since last tag); overall **PASS** requires
  zero BLOCKs and every evidence check actually run (NOT RUN ≠ pass).

### Changed
- **`docs/loop-harness.md`** and **`README.md`** — document the release-gate verb (P8).

### Notes
- **Self-host safe / backwards-compatible:** with no `CHANGELOG.md` / `VERSION` the gate reports
  not-applicable and exits 0; it requires no manifest and changes no existing behaviour. Closes
  competitive-study gap #4 (release gate distinct from "done").

## [0.21.0] — 2026-06-27

**Honest-uncertainty task statuses + mandatory R2+ qualify** (second-batch PR5). Closes the two
execution-side gaps the first shortlist skipped — including the one the competitive study named its
*biggest* gap. Extends ClaudeWarp's anti-verifier-theater identity from plan-time into task-level
reporting. Both additive: an R0/R1 harness that never uses the new statuses behaves exactly as today.

### Added
- **`/claude-warp-new-harness` — honest-uncertainty task statuses** (all optional). Beyond
  `done | failed`, a worker may report:
  - `done_with_concerns` — acceptance met but with a recorded one-line `concern`; **completes** (the
    wave proceeds) and the runner **surfaces** the concern. Replaces a falsely-clean `done`.
  - `needs_context` — cannot finish without missing information; a **holding** status (counts as
    not-complete, surfaced for a human) — the worker won't guess and mark done.
  - `blocked` — externally blocked; also a holding status, surfaced.
  The optional `concern` field carries the reason. `needs_context` / `blocked` are Type-B holds the
  runner never auto-resolves (constitution P3). The QA agent re-reads `done_with_concerns` tasks with
  extra scrutiny; `/claude-warp-converge` consumes the statuses as gap inputs.
- **`/claude-warp-new-harness` — mandatory qualify at R2+.** The QA/qualify evaluator is now generated
  and run by default for risk **R2+** harnesses (a `RISK` runner variable auto-enables it;
  **non-overridable** — there is deliberately no `--no-qa`). The structural one-level-down enforcement
  of constitution **P2** (merge-gated work needs an independent verifier), consistent with the R2+
  `cmd:` rule. When output isn't independently gradable, QA re-runs each task's `acceptance` `cmd:`
  checks as its grade (a check it can't run is `not run`, never PASS). R0/R1 harnesses keep QA opt-in.

### Changed
- **`docs/loop-harness.md`** — documents the honest-uncertainty statuses and the mandatory R2+ qualify.

### Notes
- **Backwards-compatible / self-host safe:** the new statuses are optional and the mandatory qualify is
  gated on R2+ — an existing R0/R1 `features.json` and runner behave exactly as before. Closes
  competitive-study gaps #1 (honest-uncertainty statuses — its named "biggest gap") and #2 (qualify was
  previously opt-in only).

## [0.20.0] — 2026-06-27

**Worth-it gate — success metric + kill criterion before scope** (shortlist PR4, the final item;
builds on PR3). `/claude-warp-contract` gains a front-half it lacked: for genuinely fuzzy/greenfield
plans it now pressure-tests *whether the idea is worth building* before negotiating *how*. Concrete
changes are untouched — additive and backwards-compatible.

### Added
- **`/claude-warp-contract` Phase 1.5 — worth-it gate** (fuzzy/greenfield plans only). Detects
  fuzziness (vague verb + no target code + exploratory framing), runs a two-sided honest-advisor
  pass, and forces a measurable `success_metric` + a `kill_criterion` before any drafting. Lands a
  `go | iterate | park` verdict:
  - **go** → proceed to Phase 2 as normal.
  - **iterate** → metric/scope not sharp enough; refine with the user, re-judge.
  - **park** → not worth building now: write a `steelman` + `flip_evidence`, **stop before Phase 2,
    scaffold nothing**. Park is an **overridable recommendation** — surfaced with its reasoning, but
    the user keeps the last word and may say build-anyway (recorded in `decision_log`).
- When fuzzy-vs-concrete is genuinely ambiguous, the gate **asks one question** ("exploratory or
  settled-scope?") rather than guessing — fuzziness is itself a Type-B call.
- **Contract schema** gains an **optional `worth_it` block** (`success_metric`, `kill_criterion`,
  `verdict`, `steelman`, `flip_evidence`) — populated only for plans that entered the gate.
- **Phase 7 readiness gate** gains a worth-it point: a gated plan cannot reach Approve unless
  `success_metric` + `kill_criterion` are non-empty and `verdict == go` (or the park was overridden).

### Notes
- **Backwards-compatible / self-host safe:** a concrete change never sees the gate and carries no
  `worth_it` block — identical to pre-0.20.0 behaviour. The gate scores *worth*, independent of the
  R0–R5 risk class. Embodies constitution **P3** (a `park` is Type-B → surfaced, never auto-resolved)
  and **P6** (the advisor pass is two-sided, not a cheerlead).

## [0.19.0] — 2026-06-27

**Reconcile-and-re-ticket (converge) closure step** (shortlist PR3, the headline feature; builds on
PR2). A read-only step that assesses *actual repo state* against contract + task intent, classifies
every gap, and **append-only** re-tickets the unmet pieces — instead of silently retrying or
declaring done. Additive and self-host safe: optional fields + a default-off runner flag.

### Added
- **`/claude-warp-converge`** (new skill) — reconciles the present tree against `contract.yaml`
  intent + each task's `acceptance`, classifies gaps `missing | partial | contradicts | unrequested`
  with R0–R5 severity (**hybrid**: mechanical re-run for missing/partial, judgment for
  unrequested/contradicts), and **appends** a `convergence` wave to `<slug>-features.json` — never
  renumbering existing tasks. Idempotent: nothing unmet ⇒ file byte-for-byte unchanged, reports
  `converged`. A `contradicts` on a `must_not_touch` path or R4/R5 guardrail **Surfaces** instead of
  auto-running. For `kind: goal` it reports + prints a ready-to-run `/claude-warp-new-goal` follow-up
  rather than mutating `GOAL.md`. Read-only of source; runs with no manifest.
- **`/claude-warp-new-harness` — convergence provenance fields** — tasks gain optional
  `origin` (`initial`/`convergence`/`retry`), `gap_type`, and `source_ref` so re-ticketing is
  traceable and idempotent. All optional; existing feature lists need no migration.
- **`/claude-warp-new-harness` — `--converge` runner tail** (default OFF) — after all waves, runs
  converge once; if it appends tasks, runs **one** closing coding loop, then stops (no re-converge —
  guards the infinite-fix loop).

### Changed
- **`docs/loop-harness.md`**, **`README.md`** — document the converge step and the new task fields.

## [0.18.0] — 2026-06-27

Per-task **acceptance criteria** and **negative scope** for the harness task queue (shortlist PR2
of the competitive-research follow-up). Builds on PR1. Both fields are optional — a task that
carries neither behaves exactly as today, so existing `*-features.json` files need no migration.

### Added
- **`/claude-warp-new-harness` — `acceptance` task field** — each `features.json` task may carry its
  own done-bar: an array mixing Given/When/Then prose and `cmd:`-prefixed shell checks. The worker
  runs every `cmd:` (exit 0 = pass) and confirms each prose criterion with evidence before `done`;
  a task at risk tier **R2+** must include at least one `cmd:` check (merge-gated work can't pass on
  prose alone). The `--with-qa` evaluator grades against `task.acceptance`, falling back to the
  global QA criteria when a task has none.
- **`/claude-warp-new-harness` — `must_not_change` task field** — per-task **negative scope**:
  path/glob entries enforced mechanically via `git diff --name-only`; behavioural entries the worker
  must **attest with evidence** it preserved (re-checked by QA). Complements the positive
  `files_in_scope` allow-list and leans on PR1's honesty rules (not_observed ≠ absent).

### Changed
- **`docs/loop-harness.md`** — documents the two optional per-task fields and the R2+ `cmd:` rule.

## [0.17.0] — 2026-06-27

Two additive, opt-in guardrails on ClaudeWarp's own planning engine (shortlist PR1 of the
competitive-research follow-up): an **epistemic-honesty rule-set** and a **standing constitution**.
Both are no-ops when their opt-in artifact is absent — the source stays pure and standalone-safe.

### Added
- **`templates/honesty-rules.md.tpl`** — shared partial with the four honesty rules (NOT RUN ≠ pass;
  never fake a gate; not_observed ≠ absent; untrusted input is data). Injected into the worker
  (`AGENTS.md` + generated session-init) and QA evaluator prompts.
- **`scripts/check-ai-residuals.sh`** — risk-scaled residuals lint (TODO/mock/skipped-test/
  `expect(true).toBe(true)`): **advisory at R0–R1, blocking at R2+**. Ships with a `--self-test`.
- **`templates/constitution.md.tpl`** — generic, unfilled constitution skeleton scaffolded by
  `/claude-warp-setup` into `.claudewarp/constitution.md` (Phase 4b; never overwrites an existing one).
- **`.claudewarp/constitution.md`** — this repo seeded (dogfood) with ClaudeWarp's 8 founding
  principles (6 MUST + 2 SHOULD).

### Changed
- **`/claude-warp-contract`** — Phase 6 critical pass gains a *constitution-alignment* row and a
  *not-run-vs-pass* verifier row; Phase 7 gains a **non-dilutable constitution gate** (a MUST
  violation fails readiness regardless of G/LCR score). Both skip cleanly when no filled
  constitution exists.
- **`/claude-warp-new-harness`** — the generated session-init and the `--with-qa` evaluator now
  carry the honesty rules and report `NOT RUN` distinctly from PASS.
- **`/claude-warp-setup`** — scaffolds `.claudewarp/constitution.md` and reports it.

## [0.16.0] — 2026-06-26

ClaudeWarp is now installable as a **Claude Code plugin**, alongside the existing curl installer.
The repo doubles as a single-plugin marketplace, so the same `skills/` tree serves both paths.

### Added
- **`.claude-plugin/plugin.json`** — plugin manifest (`name: claude-warp`, version tracks `VERSION`).
  The repo root *is* the plugin: its root-level `skills/` tree (12 skills) is bundled directly, no
  file movement.
- **`.claude-plugin/marketplace.json`** — single-plugin marketplace catalog (`source: "."`). Users
  install with `/plugin marketplace add lucagattoni/Claude-Warp` then
  `/plugin install claude-warp@claude-warp`. Validated with `claude plugin validate .` (passes
  `--strict`); verified end-to-end via local marketplace add → install → `details` (all 12 skills
  exposed) → uninstall.

### Changed
- `docs/install.md` — new "Install as a Claude Code plugin" section plus a curl-vs-plugin
  comparison table and a **Namespacing** note: plugin skills are namespaced
  (`/claude-warp:claude-warp-<skill>`), bare-slug hand-offs in skill bodies still resolve in both
  modes, and the plugin path does not auto-run `/claude-warp-setup`.
- `README.md` — Install section now documents both options (curl + plugin).

### Notes
- **Additive, not a replacement** — the curl `install.sh` path is untouched. It still runs
  `/claude-warp-setup` (per-project `CLAUDE.md` + `harness-manifest.json` + commit); the plugin path
  only exposes the skills, so users run setup themselves afterwards.
- Skill bodies were **not** rewritten for the namespace (that would break the bare-name standalone
  path); cross-skill chaining relies on Claude resolving bare-slug instructions to the installed
  skill in either mode.

---

## [0.15.2] — 2026-06-26

Self-host robustness — every manifest-touching skill is now safe to run in a repo without a
`harness-manifest.json` (a self-hosted source repo, or any project not set up via
`/claude-warp-setup`). Closes the last self-host edge.

### Fixed
- **Scaffolders register gracefully.** `new-loop`, `new-harness`, and `new-agent` now register
  in `harness-manifest.json` only **if it exists** (creating the relevant array if the manifest
  lacks one); if absent they **skip registration** with a note — the scaffolded artifact works
  regardless (`inventory` finds it by scanning). Their commit step adds the manifest only if
  present. (`new-goal` already had no manifest dependency.) This unblocks letting
  `/claude-warp-contract` scaffold in a self-hosted repo without `--no-scaffold`.
- **`/claude-warp-update` refuses in a self-hosted repo** — it now detects symlinked
  `.claude/skills/` and stops, instead of overwriting the symlinks (and local source edits) with
  GitHub copies. A real footgun, now guarded.
- **`/claude-warp-sync` no-ops** when there is no manifest ("nothing to sync") instead of erroring.

### Changed
- `templates/harness-manifest.json.tpl` — added `harnesses[]` and `agents[]` arrays alongside
  `loops[]`, so a fresh manifest tracks all three registries symmetrically.
- `docs/loop-harness.md` — documented the self-host safety guarantees in the Developing section.

---

## [0.15.1] — 2026-06-26

### Changed
- `docs/concepts.md` — **new canonical concepts doc**: explains what a *plan* is, the three
  *shapes* (goal/loop/harness) and each one's aim, what `/claude-warp-contract` is and its aims,
  and how they connect. The conceptual content was **moved** here (not duplicated) — `loop-harness.md`
  now keeps a short pointer (it stays the architecture/reference doc), and `goal-readiness.md` +
  README point here. Net consolidation: one home for "what it is and why," not a 5th scattered doc.
- External `doc-NN` references are now **stated and clickable** — a note in `concepts.md` and
  `loop-harness.md` clarifies that `doc-NN` is the external [Claude-Loops](https://github.com/lucagattoni/Claude-Loops)
  knowledge base, with links to the specific docs (e.g. `doc-27` → `27-loop-contract.md`).
- Fixed the README "plan" link (was mis-pointed at the readiness scale) and a stale anchor in
  `goal-readiness.md`; added `concepts.md` to the README docs table as "read first".

---

## [0.15.0] — 2026-06-26

Unified the planning entry point and clarified the core model. Specified via
`/claude-warp-contract` itself (harness `unified-planner`, decomposed into 6 subplans) —
the tool even misclassified its own large spec as a "goal", demonstrating live the exact
gap this release fixes.

### Added
- **Plan vs Shape model** (`docs/loop-harness.md`, README, `goal-readiness.md`) — one
  unambiguous model resolving the goal-vs-plan confusion: a **plan** is the spec (any size);
  **goal / loop / harness** are the *shapes* a plan takes ("a goal" = a small single-shot plan).
- `skills/claude-warp-contract` — **single-entry router**: Phase 1 now classifies the execution
  shape **single-shot / loop / harness** (recurrence + stage count + scope size), absorbing the
  former `/claude-warp-new`. Explicitly warns not to classify on recurrence alone.
- `skills/claude-warp-contract` — **harness shape**: Phase 9 materialise + Phase 10 handoff handle
  `kind: harness`, delegating subplan decomposition to `/claude-warp-new-harness`; Phase 4 documents
  that question depth scales with shape (a goal in ≤3 Qs, a harness needs subplan elicitation).

### Removed (breaking)
- `skills/claude-warp-new` — the complexity router is **deleted**; its routing is now done by
  `/claude-warp-contract` (the single entry / "start here"). All references repointed.
  Breaking CLI change; MINOR under SemVer 0.x initial-development. Migration: `/claude-warp-new "X"`
  → `/claude-warp-contract "X"`.

---

## [0.14.2] — 2026-06-26

### Changed
- `skills/claude-warp-contract` — renumbered phases **Phase 0–9 → Phase 1–10** (the
  `loop-harness.md` description already listed them 1–10; the skill and label now agree).
  Rationale: across ClaudeWarp `Phase 0` denotes an *optional preamble* (as in `new`,
  `new-loop`, `new-goal`, `sync-research`); the contract command's first step (Branch) is
  mandatory, so it is `Phase 1`. Internal cross-references, the `_phase` resume field, and the
  `--no-scaffold` stop point updated accordingly.

---

## [0.14.1] — 2026-06-26

### Fixed
- `skills/claude-warp-setup` — **install idempotency / non-greenfield safety** (3 fixes):
  - **Manifest no longer clobbered on re-install** (was data loss): if `harness-manifest.json`
    exists, setup preserves `loops[]`, component `status` values, `claude_code.last_sync`, and
    `last_update`, updating only the version fields. Previously it overwrote the file from the
    template, wiping every registered loop and all sync state.
  - **CLAUDE.md append fixed**: an existing `CLAUDE.md` gets only the operating sections (Skills,
    Loop conventions, Escalation, Scheduling, Token discipline) under a `## ClaudeWarp` heading
    with demoted sub-headings — the H1 title, tagline, and `## Project` identity block are omitted
    (the host file owns those). Previously it appended the whole standalone-document template.
  - **Commit hygiene**: the install commit stages only the files setup writes
    (`.claude/skills/`, `CLAUDE.md`, `harness-manifest.json`, `.gitignore`) — no longer blanket-adds
    `plans/`/`docs/`, which in an existing repo swept the user's unrelated work into the commit.
- `docs/install.md` — documents the non-empty-repo behavior.

---

## [0.14.0] — 2026-06-26

Acts on the `/claude-warp-retro` findings (RETRO.md) — a goal-coherence sweep across the
loop-centric state readers, the same root cause fixed in the contract command in v0.13.0.

### Fixed
- `skills/claude-warp-retro` — now **schema-aware**: Phase 1 detects whether each state file is a
  loop (`<!-- state:` header), a doc-30 **goal** (`*-GOAL.md`), or a harness (`features.json`) and
  branches accordingly. A one-shot goal is analysed by completion + rework, not a run series;
  Phases 3 and 5 gain a goal variant. (Previously assumed a loop state header every goal lacks.)
- `skills/claude-warp-inventory` — Phase 5 likewise detects schema: reports done-conditions progress
  for goals and task counts for harnesses, instead of trying to read a loop state header from them.

---

## [0.13.0] — 2026-06-26

Specified via `/claude-warp-contract` and executed as a goal (`improve-planning-skills-GOAL.md`)
— the first end-to-end dogfood of the contract → implement → verify → ship loop, including a
live `surface_condition` gate on item #1.

### Changed
- `skills/claude-warp-contract` — **goal-branch coherence**: materialises a neutral `contract.yaml`
  for both kinds (the `--contract` handoff artifact); `kind: loop` projects anchor files,
  `kind: goal` projects `<slug>-GOAL.md`. Removes the Phase 8 contradiction (goals were told to
  write `loop-contract.yaml` *and* `GOAL.md`) and the loop-naming of goal artifacts.
- `skills/claude-warp-contract` — **generalized subjective-STOP handling** (Phase 5): now elicits a
  concrete deficiency checklist as the primary path for any vibe goal; the UI four-dimension grading
  (Quality/Originality/Craft/Functionality) is a documented special case rather than the only path.
- `skills/claude-warp-contract` — **interview batching** (Phase 3): the 1–2 most-blocking questions
  (done-condition + scope) may be asked up front, then one property at a time.
- `skills/claude-warp-new` — **explicit handoff contract** (Phase 2): forward `$ARGUMENTS` verbatim,
  hand off to exactly one target, interactive-invoke vs headless-recommend.

---

## [0.12.3] — 2026-06-26

### Fixed
- `skills/claude-warp-inventory` — Phase 1 no longer false-alarms on the ClaudeWarp source
  repo running self-hosted via symlinks. A missing `harness-manifest.json` now distinguishes
  a **self-hosted dev repo** (symlinked skills + sibling `skills/` source) from a genuine
  broken install: the former reports `Mode: self-hosted dev repo` and continues the scan;
  only the latter warns and stops. Found by dogfooding `/claude-warp-inventory` in this repo.

---

## [0.12.2] — 2026-06-26

### Changed
- `docs/loop-harness.md` — documented `scripts/dev.sh` (new "Developing ClaudeWarp" section:
  selfhost / unhost / verify / verify --live) which shipped undocumented in v0.12.1; also
  **fixed the Loop anatomy diagram**, which was garbled (duplicated phases, `Phase 2.5` out of
  order) and stale — now reflects the real sequence including Phase 3a stagnation, the Phase 3b
  self-coverage gate, `acting_on` coordination, and the harness wave/`--parallel-waves` flow.
- `README.md` — added a "Developing" section pointing at `scripts/dev.sh`.

---

## [0.12.1] — 2026-06-26

### Added
- `scripts/dev.sh` — reproducible developer tooling for self-hosting and verification:
  - `selfhost` symlinks skills into `.claude/skills/` (single source of truth — editing
    `skills/X` updates the live `/X` command; symlinks gitignored to keep the repo a pure source).
  - `verify` runs 5 deterministic checks (no LLM, no tokens): source integrity, a
    setup-is-dynamic regression guard (catches the v0.11.1 hardcoded-list class of bug),
    the install copy contract, setup-template placeholder fill, and docs coherence.
  - `verify --live` (opt-in) exercises the real `/claude-warp-setup` via `claude -p` into a
    throwaway repo for full fidelity. `verify` passes clean on the current repo (13/13 skills).

---

## [0.12.0] — 2026-06-26

`/claude-warp-sync-research` run against Claude-Loops `5378f9e` (v2.4.0).

### Added
- `templates/loop.SKILL.md.tpl` — **Self-Coverage Gate** in Phase 3b: every SCOPE item
  must have a verification artifact before the loop can pass. A scope item with no check is
  a coverage gap (incomplete verification layer), distinct from a failing check (wrong
  implementation); on a gap the loop adds the check or writes `handoff`, never `pass`.
  Source: Claude-Loops doc-04 Self-Coverage Gate (eugenelim/agent-ready-repo RFC-0051).
- `templates/loop.SKILL.md.tpl` — **multi-loop `acting_on` coordination**: new `acting_on`
  field in the STATE header plus a claim/skip rule — a loop reads every sibling `*_LOG.md`
  header and skips items another loop already claims (one owner per item), resetting its
  claim on completion. Opt-in; prevents two loops fixing the same PR in one window.
  Source: Claude-Loops doc-34 Multi-Loop STATE.md (ryanjkelly/harnery).

### Changed
- `docs/usage.md` — **Deployment posture** section mapping autonomy levels to deployment
  patterns: L1→Approval-First, L2→Curated Allow-list, L3→Sandboxed Full-Auto; distinguishes
  in-process controls (hooks, permission-mode) from out-of-process (container, OS user, network).
  Source: Claude-Loops doc-24 Harness vs Environment Engineering.

### Surfaced (not implemented — see CLAUDE_WARP_UPDATE_LOG.md)
- Traceability-lint (doc-04) — subsumed by the Self-Coverage Gate for ClaudeWarp's model.
- `--resume` / compaction persistence (doc-24) — already covered by loop IN_PROGRESS recovery
  and contract draft resume.

---

## [0.11.1] — 2026-06-26

Coherence and structure review against the latest loop-engineering news
([Claude-Loops/LOOP_ENGINEERING_NEWS.md](https://github.com/lucagattoni/Claude-Loops/blob/main/LOOP_ENGINEERING_NEWS.md)).

### Fixed
- `skills/claude-warp-setup` — installed only 7 of 13 skills: the list was hardcoded in
  three places, silently omitting `new`, `new-goal`, `new-hook`, `contract`, `inventory`,
  and `retro` from every fresh install. Now iterates `$WARP_ROOT/skills/*/` so it copies
  whatever the source contains and can never go stale again.
- `.gitignore` coherence — `CLAUDE_WARP_UPDATE_LOG.md` was gitignored yet tracked in git;
  untracked it (it is per-run sync output, kept locally).

### Changed
- `docs/usage.md` — added a "Start here" section pointing at the `/claude-warp-new` router
  and `/claude-warp-contract`, plus a one-shot Goal row and pointers to `/claude-warp-inventory`
  and `/claude-warp-retro`; these entry points were undocumented in the usage guide.
- `README.md` — resolved the "designed to shrink over time" claim against the repo's 7→13
  skill growth: split Design into native-replaceable *components* (shrink) vs loop-engineering
  *workflow skills* (grow with the discipline).
- `docs/guide.md` — removed (orphaned redirect stub; both targets are in the README docs table).

---

## [0.11.0] — 2026-06-26

### Added
- `skills/claude-warp-contract` — interactive Loop Contract negotiation: a draft-first,
  dynamically-questioned, risk-adaptive interview (Phase 0–9) that produces a complete,
  coherence-checked `loop-contract.yaml` + anchor files, then hands off to `new-loop`/`new-goal`.
  Branches loop vs goal (doc-30); classifies R0–R5 (doc-04); runs a 10-check critical pass
  mapped to named failure patterns (doc-17); gates on readiness (LCR 6-pt for loops, G0–G3
  for goals); R3+ uses an independent cross-model checker. `--no-scaffold` stops at the
  contract. Sources: Claude-Loops doc-04/14/17/27/30.
- `skills/claude-warp-new-loop`, `skills/claude-warp-new-goal` — optional `--contract <file>`
  input (Phase 0): consume a negotiated contract and skip their own derivation/readiness phases.
- `skills/claude-warp-new` — Phase 0 routes vague or high-risk goals to `/claude-warp-contract`
  before complexity routing.
- `plans/contract-command.md`, `plans/contract-fixtures.md`, `plans/validate-contracts.py` —
  the plan (refined by applying the command's own methodology to it across 5 passes) plus an
  executable fixture validator; all 6 golden fixtures pass.

### Removed
- `skills/claude-warp-spec-refine` — superseded by `/claude-warp-contract`, which is a strict
  superset (adds risk classification, Type A/B routing, anchor files, adaptive rigor, and loop
  coverage). Breaking change to the skill set; bumped as MINOR under SemVer 0.x
  initial-development semantics. References repointed in README, docs, and `CLAUDE.md.tpl`.

---

## [0.10.0] — 2026-06-25

### Added
- `skills/claude-warp-spec-refine` — iterative spec refinement: runs up to 3 rounds of targeted clarifying questions to lift a vague goal from G0/G1 to G3; produces `<slug>-spec.md`; run before `/claude-warp-new` when the goal is underspecified (source: li0nel/claude-loop)
- `skills/claude-warp-new-hook` — three new hook patterns: **evidence-gate** (PreToolUse blocks writes to state file unless a Read occurred first), **kill-switch** (PreToolUse blocks all tool calls when `AGENT_STOP` exists), **steer** (UserPromptSubmit injects `STEER.md` once as context then clears it); hook count 5 → 8 (source: anthropics/cwc-long-running-agents)
- `skills/claude-warp-new-loop` — **L1/L2/L3 autonomy classification** at scaffold time: Phase 1b classifies new loops by scope of change and verifier type; L3 mandatory checker + stagnation guard; classification emitted in Loop Contract block (source: cobusgreyling/loop-engineering)
- `skills/claude-warp-new-loop` — **Bug Fix Loop** as 8th named pattern in Patterns Catalog: Report → Analyze → Fix → Verify; on-demand trigger; L2 autonomy; 3-attempt cap before handoff (source: Pimzino/claude-code-spec-workflow)
- `skills/claude-warp-new-loop` — **cross-model checker**: generated checker agents use a different model from the loop agent (Sonnet→Haiku, Opus→Sonnet) to prevent self-evaluation bias (source: Looper)

### Changed
- `templates/loop.SKILL.md.tpl` — **stagnation circuit breaker**: Phase 3a checks `git diff --name-only` after work; `consecutive_stagnation` counter added to state header; 3 consecutive no-change runs → `handoff` verdict (source: frankbria/ralph-claude-code)
- `templates/loop.SKILL.md.tpl` — **validation-model decoupling**: Phase 3b now documents the option of delegating expensive verification to a separate cheap-model `claude` invocation, keeping main context clean (source: nizos/tdd-guard)
- `skills/claude-warp-new-harness` — **wave scheduling**: initializer assigns `wave` and `depends_on` to each task; runner processes waves sequentially; `--parallel-waves` flag runs within-wave tasks concurrently via `--bg --worktree` (source: barkain/claude-code-workflow-orchestration)
- `templates/run-headless.sh.tpl` — `--max-minutes N` flag wraps `claude` with `timeout`; exit 124 logged as timeout verdict; default 60 minutes (source: li0nel/claude-loop)
- `templates/run-fanout.sh.tpl` — `--max-minutes N` deadline tracked via epoch; polling loop exits with timeout log if exceeded; default 120 minutes

---

## [0.9.0] — 2026-06-25

### Added
- `skills/claude-warp-new` — complexity router meta-skill: assesses goal across recurrence, stage count, and scope size; routes to `new-goal`, `new-loop`, or `new-harness` automatically; removes the user decision of which scaffold to use (source: The Startup three-tier decomposition)
- `skills/claude-warp-inventory` — zero-LLM self-inspection: scans installed skills, agents, hooks, state files, and scripts; flags missing SKILL.md, stale model IDs, missing hook scripts, `consecutive_fails >= 3`, non-executable runners; prints versioned report with inline remediation
- `skills/claude-warp-retro` — loop retrospective: reads state headers and git history; surfaces what worked, what failed, recurring patterns; writes dated `RETRO.md` entry with top 3 concrete improvements (source: GStack sprint retrospective)
- `skills/claude-warp-new-hook` — security-scan as 5th hook pattern: PostToolUse async hook detecting hardcoded secrets, git safety bypasses (`--no-verify`, `--force`), and broad destructive commands; logs to `logs/security-scan.log`
- `skills/claude-warp-new-loop` — DO_NOT boundary: Phase 1b derives explicit constraints on what the loop must never touch; embedded into generated Phase 3 as a hard constraint line before sub-steps

### Changed
- `templates/loop.SKILL.md.tpl` — Phase 2.5 (Inspect): every generated loop now reads all files it will touch before modifying anything; logs unexpected state; early-exit to `skip` verdict if nothing to do (source: Claude Loop Engineering Skill / AiLabDev)
- `templates/loop.SKILL.md.tpl` — structured `<!-- state: -->` header: Phase 2 reads `last_run`, `last_verdict`, `runs_total`, `consecutive_fails` for fast loop health assessment; Phase 4 updates header after each run
- `templates/loop.SKILL.md.tpl` — Phase 3b weighted multi-behavior verification: checks carry weights (sum 100), pass threshold defaults to 70; any check with weight >= 50 is a hard fail; single-check loops reduce to the original binary model
- `templates/CLAUDE.md.tpl` — skills list updated with new router, inventory, and retro

---

## [0.8.0] — 2026-06-25

### Added
- `skills/claude-warp-new-goal` — new skill: scaffold one-shot bounded goals with GOAL.md state file, G0–G3 readiness scoring, and a run-once script; distinct from `new-loop` (recurring) and `new-harness` (multi-stage planner)
- `skills/claude-warp-new-hook` — new skill: scaffold deterministic hook scripts (verify-before-stop circuit breaker, destructive-block, audit-log); wired into `.claude/settings.json`; replaces LLM-judged Phase 3b retry with a hard exit-code gate
- `skills/claude-warp-new-harness` — Phase 5b: optional QA/Evaluator agent (three-agent harness); `--with-qa` flag on runner invokes QA after each task and reverts task to pending if it fails, with feedback written into features.json
- `skills/claude-warp-new-loop` — Phase 1 recipe lookup: matches goal against seven named Loop Patterns Catalog entries (Daily Triage, PR Babysitter, CI Sweeper, etc.); uses pattern's pre-defined schedule/budget/safety rules as defaults; pattern safety rules embedded into generated SKILL.md Phase 3
- `templates/CLAUDE.md.tpl` — Escalation rules section: concrete thresholds for stopping and surfacing to the user (3 consecutive failures, 3 consecutive blocks, $10 cost, destructive operations, decision ambiguity)
- `skills/claude-warp-sync-research` — Phase 7: auto-implements all High and Medium gaps after research completes; pre/post review loop per gap (overlap audit → scope → devil's advocate → convention fit; user journey trace → regression → devil's advocate → reference audit → fresh reader); gap interaction scan before starting

### Changed
- `templates/loop.SKILL.md.tpl` — stopping condition extended to six-state verdict system (pass/skip/fail/handoff/timeout/stopped); escalation pointer links to project-level rules in CLAUDE.md
- `README.md` — Skills table updated with new-goal and new-hook

---

## [0.7.0] — 2026-06-23

### Added
- `templates/loop.SKILL.md.tpl` — Loop Contract comment block (TRIGGER/SCOPE/ACTION/BUDGET/STOP/REPORT) at the top of every generated skill; aligned with ClaudeLoops doc-27
- `templates/loop.SKILL.md.tpl` — Phase 3c: optional DOER/CHECKER step; if a `<slug>-checker` agent exists it is invoked after Phase 3 to validate findings before commit
- `templates/run-headless.sh.tpl`, `run-fanout.sh.tpl`, harness runner — `--effort high` added to all `claude` invocations
- `templates/run-fanout.sh.tpl` — rewritten to use `claude --bg --worktree`; each item runs in a background agent with a git-isolated worktree; polled via `claude agents --json`; removes manual PID/MAX_PARALLEL management and the git race condition
- `skills/claude-warp-new-harness` — runner refactored with `run_initializer`/`run_coding_loop` functions; `--retry` flag triggers Inner/Outer Dual Loop: on MAX_ITER stall, re-invokes initializer with failure context and tries once more with revised task breakdown
- `docs/usage.md` — Routines section under Scheduling: cloud-hosted execution via `/schedule` (cron/API/GitHub triggers, no local machine needed)
- `docs/usage.md` — Monitoring running loops section: `claude agents`, `claude logs`, `claude attach`, `claude respawn`
- `templates/harness-manifest.json.tpl` — `external-trigger` component now notes Routines as the cloud-hosted alternative

### Fixed
- `skills/claude-warp-setup` — Phase 3 now resolves the ClaudeWarp source by checking for `.claudewarp-skills/` and `.claudewarp-templates/` first (placed by `install.sh`), then falling back to the global-install path; fixes template resolution failure on curl-pipe installs
- `skills/claude-warp-setup` Phase 6 — commit message now uses the literal resolved version string, not the `{{HARNESS_VERSION}}` placeholder
- `skills/claude-warp-new-harness` — initializer exit code now checked; aborts with error if initializer fails instead of silently proceeding with an empty task list
- `skills/claude-warp-new-loop` — Phase 1 now derives `SCOPE`, `ACTION`, and `CRON_SCHEDULE` to fill the new Loop Contract block; fan-out instructions updated for `--bg --worktree` (no MAX_PARALLEL)

---

## [0.6.0] — 2026-06-22

### Added
- `docs/install.md` — full installation guide: prerequisites, what gets created, verify, global install, update, uninstall
- `docs/usage.md` — full usage guide: loop type selection, single-agent, fan-out, two-part harness, subagents, scheduling, iterating
- `VERSION` — authoritative version source; `claude-warp-setup` now reads from here instead of the manifest template placeholder
- `harness-manifest.json.tpl` — added `last_update` field (populated by `/claude-warp-update`)

### Changed
- `README.md` — added Install section (prerequisites + one command) and Quick start section (4 key commands); Docs table now covers all three docs
- `docs/guide.md` — now redirects to `install.md` and `usage.md`

### Fixed
- `install.sh` — all `setup-loop-harness` references updated to `claude-warp-setup` (was broken since v0.5.0 rename)
- `skills/claude-warp-setup` — Phase 2 now creates all 7 skill directories; Phase 3 now includes self-copy of `claude-warp-setup`
- `skills/claude-warp-new-harness` — harness runner now has `MAX_ITER=50` guard and JSON parse failure detection; stale `setup-loop-harness` reference fixed
- `skills/claude-warp-sync-research` — all `harness-sync` references updated to `claude-warp-sync`; report header fixed
- `skills/claude-warp-sync` — report header updated; Phase 3 now specifies semver-aware comparison
- `skills/claude-warp-update` — Phase 3 now guards against 404/network errors before overwriting local skills
- `templates/harness-manifest.json.tpl` — stale `harness-sync` description corrected to `claude-warp-sync`
- `templates/loop.SKILL.md.tpl` — removed phantom `harness-manifest.json last_run` step (field does not exist in manifest schema)
- `templates/CLAUDE.md.tpl` — scheduling section now links to `docs/usage.md` instead of removed `docs/guide.md`
- `templates/trigger.crontab.tpl` — `/new-loop` reference updated to `/claude-warp-new-loop`
- `templates/run-fanout.sh.tpl` — added git concurrency warning with worktree guidance for tasks that write shared files
- `.gitignore` — `CLAUDE_WARP_UPDATE_LOG.md` added (runtime artifact, not source)

---

## [0.5.0] — 2026-06-22

### Added
- `skills/claude-warp-update/SKILL.md` — pulls the latest ClaudeWarp skills from GitHub into an installed project; uses GitHub API + raw content URLs, no local path dependency

### Changed
- All skills renamed with `claude-warp-` prefix for consistent namespacing:
  - `setup-loop-harness` → `claude-warp-setup`
  - `new-loop` → `claude-warp-new-loop`
  - `new-harness` → `claude-warp-new-harness`
  - `new-agent` → `claude-warp-new-agent`
  - `harness-sync` → `claude-warp-sync`
  - `claude-warp-update` (gap analysis) → `claude-warp-sync-research`
- `claude-warp-sync-research` now fetches Claude-Loops content and the ClaudeWarp inventory from GitHub instead of local paths — works on any machine
- `README.md` — restructured as a lean overview with links to docs
- `docs/guide.md` — updated for all current skills and loop types
- `docs/loop-harness.md` — full skills and templates reference updated to v0.5.0

---

## [0.4.0] — 2026-06-22

### Added
- `templates/run-fanout.sh.tpl` — parallel fan-out runner: generates a task list then dispatches one `claude` process per item with a configurable concurrency cap, per-item log files, and a pass/fail summary; `new-loop` now selects this template over `run-headless.sh.tpl` for batch/multi-item goals
- `templates/VISION.md.tpl` — Anchor File Pattern: high-level goal and success criteria
- `templates/AGENTS.md.tpl` — Anchor File Pattern: role definitions and handoff protocol for multi-agent setups
- `templates/PROMPT.md.tpl` — Anchor File Pattern: current work unit; edit to re-task the loop without touching rules or goal; `new-harness` now scaffolds all three anchor files alongside the session-init

---

## [0.3.0] — 2026-06-22

### Added
- `skills/new-agent/SKILL.md` — scaffold a specialized subagent in `.claude/agents/` with persona, model selection, and tool constraints derived from a one-line role description
- `skills/new-harness/SKILL.md` — scaffold the two-part harness pattern: an initializer agent that produces a bounded JSON task list, and a coding agent that executes tasks one at a time with git-based recovery and cross-context-window session-init resumption

### Fixed
- `templates/loop.SKILL.md.tpl` — added Phase 3b (Verify) as a non-skippable gate between "Do the work" and "Write results"; `new-loop` now expands this with the concrete check command for the goal

---

## [0.2.0] — 2026-06-22

### Added
- `skills/claude-warp-update/SKILL.md` — runs `/harness-sync` then scans Claude-Loops for patterns not yet in ClaudeWarp; surfaces prioritised (High/Medium/Low) feature gaps without auto-implementing anything

### Fixed
- `templates/run-headless.sh.tpl` — added `--max-budget-usd` to every unattended `claude` invocation; without it a runaway loop has no hard cost ceiling
- `templates/loop.SKILL.md.tpl` — Phase 2 now checks for an `IN_PROGRESS` entry and restarts the interrupted task before doing anything else; stopping condition replaced with explicit SUCCESS / SKIP / FAILURE states
- `skills/new-loop/SKILL.md` — Phase 1 now derives `MAX_BUDGET_USD` and a verifiable `STOP_CONDITION`; both are wired into the generated runner and SKILL.md
- All timestamps now use local system time (`date '+%Y-%m-%d %H:%M %Z'`) consistently across skills and templates
- `templates/CLAUDE.md.tpl` — added Claude-Loops companion reference for loop design guidance

---

## [0.1.0] — 2026-06-22

### Added
- `skills/setup-loop-harness/SKILL.md` — per-project configurator
- `skills/new-loop/SKILL.md` — scaffold a loop from a one-line goal
- `skills/harness-sync/SKILL.md` — Claude Code changelog monitor + self-pruner
- `templates/CLAUDE.md.tpl` — base loop engineering context with placeholders
- `templates/loop.SKILL.md.tpl` — loop skill skeleton
- `templates/guard.sh.tpl` — run-once-per-day / weekday guard
- `templates/run-headless.sh.tpl` — parameterised headless runner
- `templates/trigger.crontab.tpl` — cron trigger snippet
- `templates/harness-manifest.json.tpl` — version + components registry
- `install.sh` — bootstrap: copies skills + runs `/setup-loop-harness` autonomously
- `docs/loop-harness.md` — living native-vs-harness reference
- `docs/guide.md` — 6-step human guide
- `README.md`
