# Reference — Skills

Per-skill detail for all 15 ClaudeWarp skills. For the design rationale behind the contract's
reviewer charters and the behavioural-claim backlog, see
[Architecture](architecture.md); for the dev tooling and prior-art credits, see
[Developing](developing.md).

> **External references.** `§X.Y` throughout the reference points to a section of the
> [Claude-Loops documentation](https://lucagattoni.github.io/Claude-Loops/) (the external
> companion) — e.g. `§2.1`
> [The Loop Contract](https://lucagattoni.github.io/Claude-Loops/27-loop-contract/).

---

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
3. **Risk classify** R0–R5 (§5.1) → sets interview rigor
4. **Interview** — dynamic, depth scales with risk *and* shape (a goal in ≤3 Qs, a harness more)
5. **Re-classify** risk against the refined contract (bounded to 2 cycles)
6. **Critical pass** — 10 checks mapped to named failure patterns (§5.2), plus **5 plan-validation
   lenses** (spec-alignment, memory-reuse, product-fit, security-fit, works-in-practice) recorded as
   `validation.mode` and scaled by risk; R3+ uses an independent cross-model checker, not self-review
7. **Readiness gate** — LCR ≥ 5/6 (6/6 for R3+) for loops; G2+ (G3 for R3+) for goals
8. **Approve** — explicit user sign-off (§2.1 Gate 2)
9. **Materialise** `contract.yaml` (all kinds) + kind-specific projection — anchor files (loop),
   `GOAL.md` (goal), or the subplan decomposition (harness); `--no-scaffold` stops here
10. **Handoff** via `--contract` → `/claude-warp-new-loop`, `/claude-warp-new-goal`, or
    `/claude-warp-new-harness` (which decomposes a big plan into subplans)

Adaptive rigor: an R0 read-only loop clears in ≤3 questions; an R3 prod-adjacent loop is
challenged on every property and forced to define an escalation gate + independent verifier.
Sources: Claude-Loops §5.1, §5.3, §5.2, §2.3, §1.2, §2.1, §2.2.

The contract's verdict-emitting surfaces (the Phase 6 critical pass, the Phase 1.5 worth-it gate)
carry honesty riders and a red-team charter so a review can't become verifier theater — see
[Architecture → The reviewer system](architecture.md#the-reviewer-system) for the full design and
the behavioural-claim backlog that tracks whether each charter *fires*, not just that its text is present.

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

**Retry-with-backoff + safe-to-retry guard (v0.34.0).** The headless runner (`run-headless.sh.tpl`) wraps
each `claude -p` attempt in a bounded retry loop (`--max-retries`, default **2**, exponential backoff
30s→60s→…). A retry only fires when the failed attempt is **safe to retry** — it left **no durable trace**:
the working tree is clean **and** `HEAD` is unchanged from before the attempt. If the attempt committed or
dirtied the tree (a partial write that a re-run could double-apply), the runner does **not** retry — it
writes a loud `NOTIFY` line and exits non-zero so cron/launchd surfaces the failure. A `timeout` (the
`--max-minutes` wall-clock cap) is treated as a cap, **not** a transient drop, and is never retried. This
distinguishes a recoverable API/network blip from a real failure without ever silently re-running work that
already half-landed. Sourced from the ClaudeLoops `2.4.4` sync (§3.6, transient-failure handling).

**Worktree isolation for L3 loops (v0.39.0).** An optional `--worktree` flag runs the session in a
throwaway `git worktree` branched off `origin/<default-branch>` instead of the primary checkout, and
retargets the safe-to-retry guard from "local HEAD unchanged" to "`origin/<default-branch>` has not
advanced past the base SHA" — the worktree's local HEAD is disposable per attempt (reset to `origin`
before every retry), but a completed `git push` outlives it, so that push is what a blind retry could
double-apply. On success, if the primary checkout is on the default branch, it fast-forwards
(`git pull --ff-only`, best-effort). Intended for `AUTONOMY_LEVEL` **L3** loops (writes to production
paths or pushes unattended), keeping the cron/launchd run off the primary checkout's branch/dirty state.
Sourced from the ClaudeLoops `2.5.0`–`2.6.0` sync (§3.6.1, the `fetch-loop-news`/`integrate-loop-news`
worktree-isolated production shape).

**Configurable reasoning effort (v0.39.0).** `run-headless.sh.tpl` exposes `{{EFFORT}}` (default `high`)
instead of hardcoding it. A 90-run study found raising effort `high`→`xhigh` lifts first-try-perfect
28%→89% for +9–29% cost, while a bolted-on testing tool added 42–68% cost with no reliability gain —
reach for `xhigh` before an extra checker pass when a loop's failures are reasoning-driven. Sourced from
the ClaudeLoops `2.6.0` sync (arXiv 2607.02436).

**Two-stage search→integrate pipeline / "KB Tracker" pattern (v0.39.0).** For a loop whose work
splits into a noisy retrieval stage and a sequential reasoning/write stage that should not share
context, `claude-warp-new-loop` scaffolds **two** skills (`<slug>-search`, `<slug>-integrate`)
instead of one, plus `run-two-stage.sh.tpl` — a worktree-isolated runner that invokes both `claude
-p` sessions in sequence inside one throwaway worktree, handing off through a gitignored artifact
that survives the per-attempt `git reset`/`clean` (no `-x`, so ignored paths are untouched).
**Simplification vs. the source pattern:** both stages retry as one unit rather than
independently — a cheap whole-pipeline retry depends on the search skill itself skipping
re-search when the artifact is already fresh/complete, which is the search skill's job, not the
runner's. Always `AUTONOMY_LEVEL` L3 (the integrate stage publishes unattended). Verified against
4 scripted scenarios (full success + push, stage-A failure, stage-B failure with the artifact
surviving retry, and a direct reset/clean-survival check) in a throwaway git remote with a
stubbed `claude` binary. Sourced from the ClaudeLoops `2.6.0` sync (§3.6.1 / Loop Patterns
Catalog — "Knowledge-Base Tracker Loop", the pattern documenting Claude-Loops' own
`fetch-loop-news`/`integrate-loop-news` pipeline).

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

**Decomposition approval gate.** Between the initializer and the coding loop, the runner can pause for the operator to review the proposed task breakdown before any budget is spent executing it. It is **required at R2+** (the same threshold that makes QA non-overridable) and **opt-in below** via `--approve-plan`. When the gate fires, the runner prints the breakdown (wave / id / title / `depends_on`) and **stops with exit 0** — no coding work runs — until you re-run with `--plan-approved` (or `CLAUDEWARP_PLAN_APPROVED=1`). Because `features.json` persists, the approved re-run skips the initializer and proceeds straight to execution. The gate is non-interactive by design, so a scheduled/unattended harness never executes an unreviewed decomposition. (It fires on the initial decomposition only, not on a `--retry` re-init, which is an explicit autonomous stall-recovery mode you've already opted into.)

**`--retry` flag (Inner/Outer Dual Loop with diagnostic routing):** if the coding loop hits `MAX_ITER` with tasks still pending, `--retry` first **classifies the stall's root cause** into one of three layers and routes accordingly, instead of blindly re-decomposing every stall. The intent/spec/code routing is adapted from the diagnostic-failure-routing design in the [**PAUL** project](https://github.com/ChristopherKahler/paul) (*Plan · Apply · Unify Loop*, by Christopher Kahler) — see [`apply-phase.md`](https://github.com/ChristopherKahler/paul/blob/main/src/workflows/apply-phase.md); we adapt it critically (the classifier is non-load-bearing — see below) rather than copying it:

- **code** — the plan was correct, the implementation just doesn't match yet → re-run the coding loop **in place** (no re-decompose).
- **spec** — the plan was missing something or mis-scoped a task → clear the task list and re-invoke the initializer with failure context, then run a final coding pass with a revised breakdown (the original `--retry` behaviour).
- **intent** — the goal itself wants something *different* than what was planned → **Surface to a human** and stop (exit 3); re-planning the same goal cannot fix a wrong goal, so this is a Type-B judgment call that never auto-resolves (constitution P3).

The classifier is a small read-only agent; an uncertain or unparseable verdict falls back to **spec**, so routing is a strict, non-regressive refinement of the prior behaviour. Routing fires **once** (bounded recovery — a deliberate divergence from the PAUL project's max-3 loop, since the coding loop already iterates internally).

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

**Verdict-oscillation guard (v0.34.0).** A blocking QA finding reverts a task to `pending` so the worker
can re-work it — but if the **same blocker** keeps reverting the **same task**, the loop is *oscillating*,
not converging, and would otherwise burn iterations up to `MAX_ITER` (50) on the same wall. When QA reverts
a task it records the oscillation signal (`revert_count` + a stable `last_blocker` signature); once a task's
`revert_count` reaches `CLAUDEWARP_REPEAT_THRESHOLD` (default **2**) on the same blocker, the runner stops
re-attempting it and flips it to **`needs_context`** with an oscillation `concern`, so the existing Surface
logic escalates it to a human instead of looping. A *different* blocker resets the streak (genuine progress
is not penalised). Sourced from the ClaudeLoops `2.4.x` sync (verdict-stability guidance).

Separately, the **qualify/QA re-read is mandatory and non-overridable at risk R2+** (it runs by
default, no `--no-qa`) — the structural one-level-down enforcement of constitution P2 (merge-gated
work needs an independent verifier). When a task's output isn't independently gradable, QA re-runs its
`acceptance` `cmd:` checks as the grade (a check it can't run is `not run`, never PASS). The full
corroboration / reproduction design behind QA is in
[Architecture → The reviewer system](architecture.md#the-reviewer-system).

Install path: `skills/claude-warp-new-harness/SKILL.md`

---

### `/claude-warp-converge`

**Reconcile-and-re-ticket closure** (optional `--converge` runner tail).
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

Install path: `skills/claude-warp-converge/SKILL.md`

---

### `/claude-warp-release`

**"PR merged" is not "release ready."** Run before cutting a
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

Install path: `skills/claude-warp-release/SKILL.md`

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

**Ten named patterns:**

| Pattern | Event | Behaviour |
|---|---|---|
| `verify-before-stop` | `Stop` | Blocks turn end (exit 2) until `CHECK_CMD` passes; `asyncRewake` re-enters Claude with failure output |
| `destructive-block` | `PreToolUse` | Denies Bash commands matching a regex pattern |
| `audit-log` | `PostToolUse` | Appends all tool calls to `logs/audit.log` asynchronously |
| `subagent-chain` | `SubagentStop` | Triggers follow-on work when a background agent finishes |
| `security-scan` | `PostToolUse` | Flags secrets / git-safety bypasses / broad destructive patterns to `logs/security-scan.log` (async) |
| `evidence-gate` | `PreToolUse` | Blocks a `Write`/`Edit` to a state file when no prior `Read` of it was recorded |
| `review-gate` | `Stop` | Blocks turn end until `.claudewarp/review-result.json` is `APPROVE` with 0 open critical/major findings (fail-closed: missing/unparseable verdict blocks). Separates *review* (produces the verdict) from *enforcement* (this hook) |
| `kill-switch` | `PreToolUse` | Blocks all tool calls while an `AGENT_STOP` file exists — operator mid-run halt |
| `steer` | `UserPromptSubmit` | Injects `STEER.md` once as context, then clears the file |
| `intent-gate` (v0.39.0) | `PreToolUse` | Denies a `Write`/`Edit` whose target path matches none of the declared `SCOPE_GLOBS` — default-deny, mechanically enforcing a harness task's negative scope (`must_not_change`) *before* the write happens, rather than only detecting it after via `git diff` |

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

1. Detects each state file's schema (loop `<!-- state:` header / §2.2 `GOAL.md` / harness
   `features.json`) and reads it accordingly — for a goal it analyses completion + rework,
   not a run series
2. Reads git log for run commits and fix commits in the past 30 days
3. Scans last 10 dated sections for verdict distribution and recurring failures
4. Analyses patterns: what worked, what failed, what caused handoffs/timeouts
5. Appends a dated entry to `RETRO.md` with top 3 concrete improvements
6. Records the retrospective as a `converged` event in the cross-session ledger (see
   `/claude-warp-ledger`) so it is queryable across sessions
7. Prints improvements inline

Install path: `skills/claude-warp-retro/SKILL.md`

---

### `/claude-warp-ledger`

Persistent, cross-session **closure ledger** — the queryable "what happened, in order" half of
closure (COMPETITIVE-FINDINGS gap #3) that a single context window can't hold. A thin wrapper over
the executable `scripts/ledger.sh` (so the behaviour is deterministic and self-testable via
`bash scripts/ledger.sh --self-test`, not re-interpreted from prose).

- **`record`** appends one structured closure event — `bash scripts/ledger.sh record --kind
  <goal|loop|harness> --slug <slug> --event <shipped|surfaced|converged|parked|blocked>
  [--version X.Y.Z] [--verdict …] [--surfaced …] [--note …]`. `--kind/--slug/--event` are required
  (fails closed without them).
- **`query`** reads them back filtered by `--kind/--slug/--event/--since`, rendering a table or
  (with `--raw`) verbatim jsonl for `jq`.

Storage is `.claudewarp/ledger.jsonl` — one JSON object per line, **append-only** (mirrors
converge's ethos, git-merge-friendly). JSON-lines, not a markdown summary, so `query` filters on
structured fields and never greps markdown — the false-negative class `scripts/verifier-lib.sh`
exists to avoid. It is **gitignored by default** (local runtime data, like a log — `/claude-warp-setup`
seeds the ignore line); remove that line to commit the closure history into the repo.

It is **not** the memory system (semantic facts/preferences) and **not** native cross-run loop
state (a loop's run cursor): the ledger logs dated *closure events* across all kinds. **Self-host
safe (P4):** `record` self-creates `.claudewarp/`; `query` over a missing/empty ledger prints
`(ledger empty)` and exits 0 — no manifest required.

**Who records:** `/claude-warp-retro` records automatically after writing `RETRO.md`;
`/claude-warp-release` and `/claude-warp-converge` stay strictly read-only (P2) and only **print** a
ready-to-run `record` command — they never write the ledger themselves.

Install path: `skills/claude-warp-ledger/SKILL.md`

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

Developer-facing tool — scans [ClaudeLoops](https://lucagattoni.github.io/Claude-Loops/)
on GitHub for patterns not yet implemented in ClaudeWarp. Run from the ClaudeWarp
source repo, not from installed projects.

1. Runs `/claude-warp-sync` as a preliminary step
2. Reads the last recorded sync in `CLAUDE_WARP_UPDATE_LOG.md`, then fetches the **full
   GitHub compare delta** (every commit and every changed doc) from that baseline to the
   current ClaudeLoops HEAD — plus every news run block since the last sync, so a multi-day
   gap is never reduced to "the latest run"
3. Fetches the ClaudeWarp skills and templates inventory from GitHub
4. Rates each gap High / Medium / Low
5. Appends findings to `CLAUDE_WARP_UPDATE_LOG.md` and prints a summary

Then implements the High and Medium gaps autonomously (Phase 7, pre→implement→post review
per gap), cutting a release; Low-priority items are surfaced for the user to decide.

Install path: `skills/claude-warp-sync-research/SKILL.md`
