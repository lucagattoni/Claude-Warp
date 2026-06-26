# Changelog — ClaudeWarp

Versioning follows [Semantic Versioning](https://semver.org/):
- **MAJOR** — breaking change to install flow or skill API
- **MINOR** — new skill or harness capability added
- **PATCH** — fix, doc update, or component superseded by native CC feature

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
