# ClaudeWarp — Loop Harness Reference

Architecture, skills in depth, and templates reference.

---

## The core model

A **plan** is the spec (any size); **goal / loop / harness** are the *shapes* a plan can take.
"A goal" is a small single-shot plan — not the opposite of "a plan." `/claude-warp-contract`
classifies the shape for you. The full explanation, with the aim of each shape and of the
contract command, lives in **[Concepts — Plans, Shapes, and the Contract](concepts.md)**.

> **External references.** `doc-NN` throughout this doc points to the
> [Claude-Loops knowledge base](https://github.com/lucagattoni/Claude-Loops) (the external
> companion repo) — e.g. `doc-27` =
> [`docs/27-loop-contract.md`](https://github.com/lucagattoni/Claude-Loops/blob/main/docs/27-loop-contract.md).

---

## Native vs harness

ClaudeWarp installs only what Claude Code does not already provide. This boundary
is tracked in `harness-manifest.json` and kept current by `/claude-warp-sync`.

| Capability | Where it lives | Status |
|---|---|---|
| Skill auto-loading | `.claude/skills/` | **Native** (v2.1.157) |
| Subagent fan-out | `Agent` tool, `TaskCreate` | **Native** |
| Worktree isolation | `EnterWorktree`, `isolation: "worktree"` | **Native** |
| Scheduling runtime | `~/.claude/scheduled-tasks/`, `/loop` | **Native** |
| Memory / context | `CLAUDE.md`, `/memory` | **Native** |
| Code review | `/code-review`, `/simplify` | **Native** |
| **Scheduling guards** | `scripts/guard-<name>.sh` | **Harness** |
| **External trigger** | `scripts/run-<name>.sh` + crontab snippet | **Harness** |
| **Cross-run structured state** | `<NAME>_LOG.md` + dedup logic | **Harness** |
| **Changelog monitor / self-pruner** | `/claude-warp-sync` | **Harness** |
| **Loop scaffolder** | `/claude-warp-new-loop`, `/claude-warp-new-harness` | **Harness** |
| **Agent scaffolder** | `/claude-warp-new-agent` | **Harness** |

When a harness row becomes native, `/claude-warp-sync` marks it `superseded`,
logs a migration note in `HARNESS_SYNC_LOG.md`, and adds a deprecation notice
to the affected skill.

---

## Skills

### `/claude-warp-setup`

Per-project installer. Detects project type (Node / Python / Go / Rust / generic),
fills `CLAUDE.md` with real context, creates directory structure, writes
`harness-manifest.json`, and commits.

Install path: `skills/claude-warp-setup/SKILL.md`

---

### `/claude-warp-contract "goal"` ← start here

**The single entry point.** Describe any plan; it specifies it, **auto-routes to the shape**
(single-shot / loop / harness), and hands off to the scaffolder. It absorbed the former
`/claude-warp-new` router and `spec-refine`. Phase 1–10:

1. **Branch (classify the shape)** — single-shot `goal` / `loop` / `harness` from recurrence +
   stage count + scope size (the router, folded in); resume an existing draft if present
2. **Draft-first** — a complete best-guess contract, persisted to `contract.draft.yaml`
3. **Risk classify** R0–R5 (doc-04) → sets interview rigor
4. **Interview** — dynamic, depth scales with risk *and* shape (a goal in ≤3 Qs, a harness more)
5. **Re-classify** risk against the refined contract (bounded to 2 cycles)
6. **Critical pass** — 10 checks mapped to named failure patterns (doc-17); R3+ uses an
   independent cross-model checker, not self-review
7. **Readiness gate** — LCR ≥ 5/6 (6/6 for R3+) for loops; G2+ (G3 for R3+) for goals
8. **Approve** — explicit user sign-off (doc-27 Gate 2)
9. **Materialise** `contract.yaml` (all kinds) + kind-specific projection — anchor files (loop),
   `GOAL.md` (goal), or the subplan decomposition (harness); `--no-scaffold` stops here
10. **Handoff** via `--contract` → `/claude-warp-new-loop`, `/claude-warp-new-goal`, or
    `/claude-warp-new-harness` (which decomposes a big plan into subplans)

Adaptive rigor: an R0 read-only loop clears in ≤3 questions; an R3 prod-adjacent loop is
challenged on every property and forced to define an escalation gate + independent verifier.
Sources: Claude-Loops doc-04, doc-14, doc-17, doc-24, doc-26, doc-27, doc-30.

Install path: `skills/claude-warp-contract/SKILL.md`

---

### `/claude-warp-new-goal "goal"`

Scaffolds a **one-shot bounded goal** — use when the work is non-recurring and
stops when a verifiable criterion is met. ("Loops discover work. Goals finish it.")

**G0–G3 readiness scoring** — before creating files, the skill scores the goal
across four axes (objective clarity, verifier independence, state file, budget).
G0 stops with an explanation; G1–G2 proceed with warnings in GOAL.md.

**Files created:**

| File | Purpose |
|---|---|
| `<slug>-GOAL.md` | State file: Objective, Done conditions, Guardrails, Execution log |
| `scripts/run-<slug>.sh` | Run-once script — re-invokable; GOAL.md tracks progress across context resets |

Install path: `skills/claude-warp-new-goal/SKILL.md`

---

### `/claude-warp-new-loop "goal"`

Scaffolds a complete **recurring** single-agent loop from a one-line goal description.

**Derives from the goal:**
- `SKILL_SLUG`, `SKILL_NAME`, `SKILL_DESCRIPTION`
- `STATE_FILE` — append-only tracking file
- `DEFAULT_SCHEDULE` — suggested cron expression
- `MAX_TURNS` — hard turn cap
- `MAX_BUDGET_USD` — hard cost cap (default $2.00)
- `STOP_CONDITION` — verifiable signal that the loop succeeded
- `ALLOWED_TOOLS` — minimum tool set

**Files created:**

| File | Purpose |
|---|---|
| `.claude/skills/<slug>/SKILL.md` | Loop procedure with phases: guard → state → work → verify → write → stop |
| `scripts/guard-<slug>.sh` | Prevents double-runs (once per day / weekdays only) |
| `scripts/run-<slug>.sh` | Headless runner (`run-headless.sh.tpl`) or fan-out runner (`run-fanout.sh.tpl`, uses `claude --bg --worktree`) based on goal shape |
| `<SLUG>_LOG.md` | Append-only state with IN_PROGRESS recovery |
| `scripts/trigger-<slug>.crontab` | Reference cron snippet (not installed automatically) |

Install path: `skills/claude-warp-new-loop/SKILL.md`

---

### `/claude-warp-new-harness "goal"`

Scaffolds a two-part harness for goals too large for a single loop. Based on
Anthropic Engineering's ["Effective Harnesses for Long-Running Agents"](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

**Two roles:**
- **Initializer agent** — reads the goal and scope; produces a bounded JSON task list; runs once
- **Coding agent** — executes one task at a time; commits after each; reads session-init at the start of every context window for crash recovery

**Files created:**

| File | Purpose |
|---|---|
| `.claude/agents/<slug>-initializer.md` | Planner agent definition |
| `<slug>-features.json` | Task queue: `pending` → `in_progress` → `done` / `failed` (+ optional honest-uncertainty statuses `done_with_concerns` / `needs_context` / `blocked`) |
| `<slug>-session-init.md` | Read by coding agent at every context window start |
| `VISION.md` | High-level goal and success criteria (anchor file) |
| `AGENTS.md` | Role definitions and handoff protocol (anchor file) |
| `PROMPT.md` | Current work unit — edit to re-task without changing rules (anchor file) |
| `scripts/run-<slug>.sh` | Runner: initializer once, then coding agent loop until all tasks done; `--retry` triggers Inner/Outer Dual Loop on stall |

**`--retry` flag (Inner/Outer Dual Loop):** if the coding loop hits `MAX_ITER` with tasks still pending, `--retry` clears the task list, re-invokes the initializer with failure context, and runs a final coding pass with a revised task breakdown.

**Per-task acceptance + negative scope (optional).** Beyond the global `verification` command, each
task may carry its own done-bar and guardrails — both optional, so existing feature lists keep working
unchanged:
- `acceptance` — an array of Given/When/Then prose criteria and/or `cmd:`-prefixed shell checks that
  grade **this task** specifically. A task at risk tier **R2+** must include at least one `cmd:` check
  (merge-gated work can't pass on prose alone). QA grades against these, falling back to the global
  criteria when a task has none.
- `must_not_change` — the task's **negative scope**: path/globs enforced mechanically via
  `git diff`, plus behaviours the worker must attest it preserved. Complements the positive
  `files_in_scope` allow-list.

**Honest-uncertainty statuses + mandatory R2+ qualify (optional / risk-scaled).** Beyond `done` /
`failed`, a worker may set three honest statuses instead of faking a `done` or flattening a
recoverable hold to a failure (all optional — a harness that never uses them is unchanged):
- `done_with_concerns` — acceptance met **but** with a recorded `concern`. **Completes** (the wave
  proceeds) and the runner **surfaces** the concern in its report. "Done but unsure about X."
- `needs_context` — cannot finish without missing information; a **holding** status (counts as
  not-complete, surfaced for a human). "I won't guess and mark it done."
- `blocked` — externally blocked; also a holding status, surfaced.

`needs_context` / `blocked` are Type-B holds — the runner never auto-resolves them to `done`.
Separately, the **qualify/QA re-read is mandatory and non-overridable at risk R2+** (it runs by
default, no `--no-qa`) — the structural one-level-down enforcement of constitution P2 (merge-gated
work needs an independent verifier). When a task's output isn't independently gradable, QA re-runs its
`acceptance` `cmd:` checks as the grade (a check it can't run is `not run`, never PASS).

**Converge — reconcile-and-re-ticket closure (`/claude-warp-converge`, optional `--converge`).**
After a harness runs, converge answers one question honestly: *does the actual tree satisfy the
intent, and if not, what is left?* It is **read-only of source** and judges the **present state of
the tree** against the contract + task intent (it is a reconciler, **not a diff tool**). It
classifies every gap — `missing | partial | contradicts | unrequested` — using a **hybrid**
assessment (run task `acceptance`/`stop.check` for `missing`/`partial`; LLM judgment for
`unrequested`/`contradicts`), then **append-only** re-tickets each gap as a `convergence` wave
(tasks tagged `origin: convergence` + `gap_type` + `source_ref`, so a re-run is idempotent). If
nothing is unmet it leaves `features.json` byte-for-byte unchanged and reports `converged`. A
`contradicts` on a `must_not_touch` path or an R4/R5 guardrail **Surfaces** for a human instead of
auto-running. The runner's `--converge` tail (default off) runs it once after all waves and, if it
appended tasks, runs **one** closing coding loop — no re-converge (guards the infinite-fix loop).
For a `kind: goal`, converge reports + prints a ready-to-run `/claude-warp-new-goal` follow-up
rather than mutating `GOAL.md`.

**Release gate — "PR merged" is not "release ready" (`/claude-warp-release`).** Run before cutting a
release to answer one question honestly: *is this ready to ship, or just merged?* It is **read-only**
— it never tags, commits, or pushes; it **assesses**, packages the evidence (verifier output +
diffstat since the last tag), prints the exact tag/release commands, and emits a **two-tier verdict**:

- **BLOCK** (hard, fail-closed) on the **mechanical** boundaries — VERSION not bumped vs the last tag,
  no matching dated CHANGELOG entry, the target tag already exists, a still-populated `[Unreleased]`,
  or a dirty tree. These are objective; each has one right answer, so each fails closed.
- **WARN + Surface** on the **one judgment** call — whether the bump *severity* matches the inferred
  change type (breaking→MAJOR, new capability→MINOR, fix/doc→PATCH; highest type wins). Because that
  classification is an inference, a suspected mismatch Surfaces for a human and is **never**
  auto-escalated to a BLOCK (constitution P3/P6 — a Type-B judgment is not auto-resolved).

Overall verdict is **PASS** only with zero BLOCKs and every evidence check actually run (NOT RUN ≠
pass). Keeping the gate read-only is deliberate: the readiness-checker stays independent of the
shipper (P2), and the act of releasing remains a Surface. Self-host safe — with no `CHANGELOG.md` /
`VERSION` it reports not-applicable and exits 0. It operationalizes the project's SemVer convention
(release per complete batch, highest-severity bump wins, never leave `[Unreleased]` populated) as a
checkable gate.

Install paths: `skills/claude-warp-new-harness/SKILL.md`, `skills/claude-warp-converge/SKILL.md`,
`skills/claude-warp-release/SKILL.md`

---

### `/claude-warp-new-agent "role"`

Scaffolds a specialized subagent definition for use inside loops and harnesses.

**Derives from the role:**
- `AGENT_NAME` — kebab-case identifier
- `AGENT_MODEL` — Opus 4.8 for deep analysis; Sonnet 4.6 for routine work; Haiku 4.5 for fast lookups
- `AGENT_TOOLS` — minimum tool set for the role
- `AGENT_PERSONA` — expertise, focus, output format, and constraints

**Files created:**

| File | Purpose |
|---|---|
| `.claude/agents/<name>.md` | Subagent definition with frontmatter and persona |

Install path: `skills/claude-warp-new-agent/SKILL.md`

---

### `/claude-warp-new-hook "description"`

Scaffolds a deterministic hook script and wires it into `.claude/settings.json`.
Hooks run shell scripts at defined lifecycle points — they are hard gates, not
LLM judgments. Use when a loop needs a guarantee (not best-effort behaviour).

**Four named patterns:**

| Pattern | Event | Behaviour |
|---|---|---|
| `verify-before-stop` | `Stop` | Blocks turn end (exit 2) until `CHECK_CMD` passes; `asyncRewake` re-enters Claude with failure output |
| `destructive-block` | `PreToolUse` | Denies Bash commands matching a regex pattern |
| `audit-log` | `PostToolUse` | Appends all tool calls to `logs/audit.log` asynchronously |
| `subagent-chain` | `SubagentStop` | Triggers follow-on work when a background agent finishes |

**Files created:**

| File | Purpose |
|---|---|
| `hooks/<slug>.sh` | Hook script; exit 2 = blocking deny, exit 0 = allow |
| `.claude/settings.json` | Updated with the new hook entry (appended, not replaced) |

**Safety:** exit code 2 blocks; exit 1 is a non-blocking warning that accidentally permits the denied action. All deny logic must be wrapped so unhandled errors exit 2.

Install path: `skills/claude-warp-new-hook/SKILL.md`

---

### `/claude-warp-inventory`

Zero-LLM self-inspection of the installed ClaudeWarp setup. All phases use Bash
and Read only — no LLM inference.

1. Reads `harness-manifest.json` for installed version
2. Scans `.claude/skills/` for missing SKILL.md files or unknown skills
3. Scans `.claude/agents/` for stale model IDs (post-deprecation)
4. Scans `.claude/settings.json` hooks for missing scripts
5. Detects state-file schema and reads accordingly: loop headers (flags `consecutive_fails >= 3`, `IN_PROGRESS`), goal `GOAL.md` (done-conditions progress; flags stalled), harness `features.json` (flags failed tasks)
6. Checks `scripts/` for non-executable runner files
7. Prints a versioned report with inline remediation commands

If `harness-manifest.json` is absent, it distinguishes a **self-hosted dev repo** (skills
symlinked via `scripts/dev.sh selfhost`, sibling `skills/` source present) from a genuine
broken install: the former reports `Mode: self-hosted dev repo` and continues; only the
latter warns and stops.

Install path: `skills/claude-warp-inventory/SKILL.md`

---

### `/claude-warp-retro "slug"`

Retrospective over a loop, goal, or harness (or all). Reads state files and git history —
does not modify any loop/goal files (RETRO.md is the only output).

1. Detects each state file's schema (loop `<!-- state:` header / doc-30 `GOAL.md` / harness
   `features.json`) and reads it accordingly — for a goal it analyses completion + rework,
   not a run series
2. Reads git log for run commits and fix commits in the past 30 days
3. Scans last 10 dated sections for verdict distribution and recurring failures
4. Analyses patterns: what worked, what failed, what caused handoffs/timeouts
5. Appends a dated entry to `RETRO.md` with top 3 concrete improvements
6. Prints improvements inline

Install path: `skills/claude-warp-retro/SKILL.md`

---

### `/claude-warp-sync`

Synchronises the harness against the current Claude Code version.

1. Fetches the Claude Code changelog (cached 24h at `~/.claude/cache/changelog.md`)
2. Scans for evidence that any active component is now native
3. Marks superseded components in `harness-manifest.json`
4. Writes migration notes to `HARNESS_SYNC_LOG.md`
5. Adds deprecation notices to affected skill files
6. Commits if anything changed

Install path: `skills/claude-warp-sync/SKILL.md`

---

### `/claude-warp-update`

Pulls the latest ClaudeWarp skills from GitHub into this project.

1. Reads `harness-manifest.json` for the current installed version
2. Fetches the skills directory listing from the ClaudeWarp GitHub repo
3. For each installed skill: fetches the remote SKILL.md and compares with local
4. Applies updates, installs new skills, and reports orphans (removed upstream)
5. Updates `harness-manifest.json` version and commits

Install path: `skills/claude-warp-update/SKILL.md`

---

### `/claude-warp-sync-research`

Developer-facing tool — scans [ClaudeLoops](https://github.com/lucagattoni/Claude-Loops)
on GitHub for patterns not yet implemented in ClaudeWarp. Run from the ClaudeWarp
source repo, not from installed projects.

1. Runs `/claude-warp-sync` as a preliminary step
2. Fetches the ClaudeLoops topic index and latest news digest from GitHub
3. Fetches the ClaudeWarp skills and templates inventory from GitHub
4. Rates each gap High / Medium / Low
5. Appends findings to `CLAUDE_WARP_UPDATE_LOG.md` and prints a summary

Does not implement anything — surfaces findings only.

Install path: `skills/claude-warp-sync-research/SKILL.md`

---

## Templates

| Template | Used by | Purpose |
|---|---|---|
| `CLAUDE.md.tpl` | `claude-warp-setup` | Base loop engineering context for a project |
| `loop.SKILL.md.tpl` | `claude-warp-new-loop` | Loop skill skeleton: guard → state → work → verify → write → stop |
| `guard.sh.tpl` | `claude-warp-new-loop` | Run-once-per-day / weekday-only guard script |
| `run-headless.sh.tpl` | `claude-warp-new-loop` | Single-agent headless runner with `--max-turns` and `--max-budget-usd` |
| `run-fanout.sh.tpl` | `claude-warp-new-loop` | Parallel fan-out runner: `claude --bg --worktree` per item, git-isolated, polled via `claude agents --json` |
| `trigger.crontab.tpl` | `claude-warp-new-loop` | Reference cron entry (not installed — paste into `crontab -e`) |
| `harness-manifest.json.tpl` | `claude-warp-setup` | Version + components registry |
| `VISION.md.tpl` | `claude-warp-new-harness` | Anchor file: high-level goal and success criteria |
| `AGENTS.md.tpl` | `claude-warp-new-harness` | Anchor file: agent roles and handoff protocol |
| `PROMPT.md.tpl` | `claude-warp-new-harness` | Anchor file: current work unit; edit to re-task the loop |

---

## Loop anatomy

Every loop scaffolded by `/claude-warp-new-loop` follows this phase sequence:

```
Phase 1   — Guard check     prevent duplicate runs
Phase 2   — Load state      read STATE header (last_verdict, consecutive_fails/stagnation,
                            acting_on); recover IN_PROGRESS; claim/skip for multi-loop coordination
Phase 2.5 — Inspect         read every file in SCOPE before editing; log unexpected state
Phase 3   — Do the work     goal-specific logic (expanded by /claude-warp-new-loop)
Phase 3a  — Stagnation       no file changes → stagnation counter; 3 in a row → handoff
Phase 3b  — Verify          self-coverage gate (every SCOPE item has a check), then weighted checks
Phase 3c  — Checker         invoke <slug>-checker agent if present (DOER/CHECKER, cross-model)
Phase 4   — Write results   update STATE header; append dated entry; commit
Stopping condition          six-state verdict: pass/skip/fail/handoff/timeout/stopped
```

Every harness scaffolded by `/claude-warp-new-harness` follows this flow:

```
Initializer (once)  →  features.json populated (tasks + wave/depends_on)
Runner loop         →  coding agent invoked per pending task (waves run in order;
                       --parallel-waves runs a wave's tasks concurrently)
Coding agent        →  reads session-init → executes one task → commits → stops
```

---

## Developing ClaudeWarp

`scripts/dev.sh` is the developer tool for working on the harness itself (not installed into
consumer projects):

| Command | What it does |
|---|---|
| `scripts/dev.sh selfhost` | Symlinks every skill into `.claude/skills/` so they run as live `/claude-warp-*` commands **in this repo** (next session). Single source of truth — editing `skills/X` updates the live command; symlinks are gitignored so the repo stays a pure distribution source. |
| `scripts/dev.sh unhost` | Removes those symlinks. |
| `scripts/dev.sh verify` | Five deterministic checks (no LLM, no tokens): source integrity, the setup-is-dynamic regression guard, the install copy contract, setup-template placeholder fill, and docs coherence. Exits non-zero on failure — suitable for CI. |
| `scripts/dev.sh verify --live` | Additionally runs the real `/claude-warp-setup` (`claude -p`) into a throwaway repo for full fidelity. Costs tokens; opt-in. |

**Self-host safety.** Every skill is safe to run in this self-hosted repo (which has no
`harness-manifest.json`): the scaffolders (`new-loop`/`new-goal`/`new-harness`/`new-agent`)
skip manifest registration when it is absent (the artifact still works; `inventory` finds it by
scanning), `/claude-warp-sync` no-ops with "nothing to sync", and `/claude-warp-update`
**refuses** to run (it would overwrite the symlinks with GitHub copies — edit `skills/` directly
instead). So you can `/claude-warp-contract` a plan and let it scaffold here without
`--no-scaffold` if you actually want the artifacts.

**Scope of `verify`:** it checks source integrity and the install *copy contract* — it cannot
reproduce the LLM behaviour of `/claude-warp-setup` itself (that is non-deterministic). Use
`--live` when you need to exercise the actual setup skill end to end.
