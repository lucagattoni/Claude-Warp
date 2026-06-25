# Changelog — ClaudeWarp

Versioning follows [Semantic Versioning](https://semver.org/):
- **MAJOR** — breaking change to install flow or skill API
- **MINOR** — new skill or harness capability added
- **PATCH** — fix, doc update, or component superseded by native CC feature

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
