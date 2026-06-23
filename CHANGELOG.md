# Changelog — ClaudeWarp

Versioning follows [Semantic Versioning](https://semver.org/):
- **MAJOR** — breaking change to install flow or skill API
- **MINOR** — new skill or harness capability added
- **PATCH** — fix, doc update, or component superseded by native CC feature

---

## [Unreleased]

### Added
- `templates/loop.SKILL.md.tpl` — Loop Contract comment block (TRIGGER/SCOPE/ACTION/BUDGET/STOP/REPORT) at the top of every generated skill; aligned with ClaudeLoops doc-27
- `templates/loop.SKILL.md.tpl` — Phase 3c: optional DOER/CHECKER step; if a `<slug>-checker` agent exists it is invoked after Phase 3 to validate findings before commit
- `templates/run-headless.sh.tpl`, `run-fanout.sh.tpl`, harness runner — `--effort high` added to all `claude` invocations
- `templates/run-fanout.sh.tpl` — rewritten to use `claude --bg --worktree`; each item runs in a background agent with a git-isolated worktree; polled via `claude agents --json`; removes manual PID/MAX_PARALLEL management and the git race condition
- `skills/claude-warp-new-harness` — runner now uses `run_initializer`/`run_coding_loop` functions; `--retry` flag triggers Inner/Outer Dual Loop: on MAX_ITER stall, re-invokes initializer with failure context and tries once more with revised task breakdown
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
