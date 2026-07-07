# Reference — Architecture

The model ClaudeWarp is built on, the boundary between what it ships and what Claude Code provides
natively, the anatomy of a running loop/harness, and the design of the reviewer system that keeps its
verdicts honest. For the per-skill reference see [Skills](skills.md); for dev tooling and prior-art
credits see [Developing](developing.md).

> **External references.** `§X.Y` points to a section of the
> [Claude-Loops documentation](https://lucagattoni.github.io/Claude-Loops/) — e.g. `§2.1`
> [The Loop Contract](https://lucagattoni.github.io/Claude-Loops/27-loop-contract/).

---

## The core model

A **plan** is the spec (any size); **goal / loop / harness** are the *shapes* a plan can take.
"A goal" is a small single-shot plan — not the opposite of "a plan." `/claude-warp-contract`
classifies the shape for you. The full explanation, with the aim of each shape and of the
contract command, lives in **[Concepts — Plans, Shapes, and the Contract](../concepts.md)**.

---

## Native vs harness

ClaudeWarp installs only what Claude Code does not already provide. This boundary
is tracked in `harness-manifest.json` and kept current by `/claude-warp-sync`.

| Capability | Where it lives | Status |
|---|---|---|
| Skill auto-loading | `.claude/skills/` | **Native** (v2.1.157) |
| Subagent fan-out | `Agent` tool, `TaskCreate` | **Native** |
| Worktree isolation | `EnterWorktree`, `isolation: "worktree"` | **Native** |
| Scheduling runtime | `/loop`, `/schedule`, `CronCreate`, `claude --bg` / `claude agents`, `RemoteTrigger` | **Native** |
| Until-condition goal runtime | `/goal` — per-turn Stop-hook evaluator on an independent small model | **Native** (v2.1.139) |
| Interactive planning | `/plan` (plan mode), Ultraplan | **Native** |
| Independent-unit fan-out with PRs | `/batch` — decompose, approve, one worktree+PR per unit | **Native** |
| Large-scale scripted orchestration | Dynamic workflows (`ultracode`, `/workflows`) | **Native** (v2.1.154) |
| Local unattended scheduling (Desktop) | Desktop scheduled tasks | **Native** |
| Event-pushed-into-session triggers | Channels (research preview) | **Native** |
| Memory / context | `CLAUDE.md`, `/memory` | **Native** |
| Code review | `/code-review`, `/simplify` | **Native** |
| **Scheduling guards** | `scripts/guard-<name>.sh` | **Harness** |
| **External trigger** | `scripts/run-<name>.sh` + crontab snippet | **Harness** — CLI-only/headless; Desktop tasks and Channels above cover it when either applies |
| **Cross-run structured state** | `<NAME>_LOG.md` + dedup logic | **Harness** |
| **Changelog monitor / self-pruner** | `/claude-warp-sync` | **Harness** |
| **Loop scaffolder** | `/claude-warp-new-loop`, `/claude-warp-new-harness` | **Harness** — routes to `/loop`/`/batch`/workflows first when native fits |
| **Agent scaffolder** | `/claude-warp-new-agent` | **Harness** |

When a harness row becomes native, `/claude-warp-sync` marks it `superseded`,
logs a migration note in `HARNESS_SYNC_LOG.md`, and adds a deprecation notice
to the affected skill.

The native rows are not just "not reimplemented" — the harness **delegates into them** where it
can. The goal runner scaffolded by `/claude-warp-new-goal` drives its until-done loop with native
`/goal` (independent per-turn evaluation for free) instead of a self-judged prompt; the scaffolders
route users to native `/loop` (in-session recurring, ≤ 7 days), `/plan` (interactive supervised
change), `/batch` (independent-unit fan-out with a PR per unit), and dynamic workflows (scripted
orchestration up to 1,000 agents) outright when no harness value — guards, cross-run state,
budgets, readiness gates, daemon-free triggers — is needed on top.

**Why `/claude-warp-new-harness` isn't superseded by dynamic workflows.** They look similar —
both fan work across many agents — but a workflow's state lives in the runtime process: "if you
exit Claude Code while a workflow is running, the next session starts the workflow fresh"
([docs](https://code.claude.com/docs/en/workflows)). The harness's `features.json` + git-based
recovery is durable specifically *because* it's a file on disk a fresh agent re-reads — a crash,
a reboot, or a different machine picking up the queue all resume from it. That is the harness's
reason to exist even as `/batch` and workflows absorb more of the in-session fan-out case.

**Boundary last verified against Claude Code v2.1.199 (2026-07-03).** `/claude-warp-sync` read every
release in the window **v2.1.196 → v2.1.199** (full notes, not a keyword grep). No Harness row has
become fully native; the window mainly deepened background-agent/subagent maturity (subagents now
background by default, background agents auto-commit/push/open a draft PR from a worktree, agent
notifications on completion/needs-input) — reinforcing the already-native *Scheduling runtime* and
*Subagent fan-out* rows without closing *External trigger* (still no daemon-free, OS-level guard
primitive). One item cuts the other way: v2.1.198 **removed** the native `/agents` wizard ("ask
Claude to create or manage subagents, or edit `.claude/agents/` directly"), which if anything
reinforces the case for keeping **Agent scaffolder** (`/claude-warp-new-agent`) as a Harness row
rather than a candidate for supersession. This line is the source-repo record of the last-scanned
version (the install equivalent is `claude_code.last_sync_version` in `harness-manifest.json`).

**The two directions.** ClaudeWarp separates two kinds of thing, and they move in opposite directions:

- **Native-replaceable components** (skill distribution, scheduling guards, cross-run state) are
  *meant to shrink*. Each tracks a `native_since` field in `harness-manifest.json`; when
  `/claude-warp-sync` confirms Claude Code covers it natively, the component is marked superseded and
  retired.
- **Loop-engineering workflow skills** (scaffolding, the contract negotiator, checkers, hooks,
  retrospectives) are the durable value. These track the *practice* of loop engineering, not gaps in
  Claude Code — as the discipline matures ("the harness now matters more than the model"), this layer
  grows.

So the harness as plumbing shrinks toward zero, while the harness as method deepens. Conflating the
two is the easy mistake; `/claude-warp-sync` only ever retires the former.

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
Approval gate       →  print breakdown → STOP for review (R2+, or --approve-plan);
                       proceeds once --plan-approved
Runner loop         →  coding agent invoked per pending task (waves run in order;
                       --parallel-waves runs a wave's tasks concurrently)
Coding agent        →  reads session-init → executes one task → commits → stops
```

---

## The reviewer system

ClaudeWarp's verdict-emitting surfaces — the contract critical pass (Phase 6), the contract worth-it
verdict (Phase 1.5), and the harness QA evaluator (`new-harness` Phase 5b) — carry a layered set of
honesty disciplines so a review can't become *verifier theater*. The design spans more than one skill
(it binds `/claude-warp-contract` and `/claude-warp-new-harness`), so it is documented here as
cross-cutting architecture rather than under any single skill. The external prior art behind each
element is credited in [Developing → Prior art and acknowledgements](developing.md#prior-art-and-acknowledgements).

### Honesty riders (verdict outputs, v0.28.0)

Five riders keep a review honest. Two bind at **every risk tier** (free instruction text, no
ceremony); three bind at **R2+** (advisory below, so small R0/R1 goals are not taxed):

| Rider | Tier | What it forces |
|---|---|---|
| **Anti-fabrication** | all | "No blockers" is a valid result — never manufacture findings to look thorough |
| **Anonymized-author** | all | Judge the artifact on its merits, author identity/reasoning set aside first |
| **Severity→verdict gating** | R2+ | `critical/major` block; `minor/recommendation` are recorded, never stall the loop |
| **Confidence-capped-by-verified-ratio** | R2+ | `confidence: N/10` + "M of K load-bearing claims verified; capped by that ratio" |
| **"Unverified" set** | R2+ | Every verdict lists what it did **not** check — P6 (NOT RUN ≠ pass) made visible |

Adapted **critically**: severity gating still routes a Type-B judgment call to Surface (it never
auto-resolves a `minor` that is actually a hidden decision); anonymized-author is same-model here, so
it neutralizes author-bias, not a shared-model-family blind spot.

### Red-team / Skeptic charter on the reviewers (v0.29.0)

The two places ClaudeWarp spawns an *independent reviewer* — the contract Phase 6 R3+ checker and the
`new-harness` QA evaluator (plus the optional DOER/CHECKER) — carry a **red-team charter**: try to
*break* the work, not confirm it. Additive to the v0.28.0 riders.

| Element | Where | What it forces |
|---|---|---|
| **Try-to-break (Skeptic) charter** | both reviewers | Assume it's wrong; find the way it passes *without doing the work* |
| **Trivially-passing-AC check** | both reviewers | Flag any acceptance criterion / `stop.check` an empty stub, hardcoded value, or always-0 check satisfies |
| **Control-validation** | QA evaluator | A passing `cmd:` must be confirmed to **FAIL** on a broken impl — *a check that can't fail proves nothing* |
| **Reasoning-blind grading** | both reviewers | Judge the artifact + repo, not the author's defence of it |
| **Single fresh-context pass** | R3+ checker | One pass, no debate loop (conformity drift) |

Adapted **critically**: a "trivially-passing AC" that is actually a deliberate human-gated decision
**Surfaces** as a Type-B call, never auto-fails; a clean red-team result is valid (anti-fabrication
still binds — no invented breaks).

### Reproduction-required corroboration (v0.30.0–v0.32.0)

Every reviewer is still **same-model** — they share a family blind spot. The cheapest *independence*
proxy without a second vendor or a panel: a finding only counts if it **reproduces**, and a
merge-gating PASS must be **corroborated**, not solo. It attaches to the `new-harness` QA loop and the
contract `stop.evidence` rule.

| Element | Where | What it forces |
|---|---|---|
| **Reproduce-before-block** | QA evaluator (`--corroborate`) | A blocking finding reverts a task only if a **second pass reproduces it**; an unreproduced finding is downgraded to a recorded non-blocking minor |
| **Corroborated PASS** | QA evaluator + contract `stop.evidence` | A merge-gating PASS is `corroborated` only if a second pass agrees; a solo green is one data point, not confirmation |
| **Provenance tags** | both | Every finding/verdict carries `[pass-N / model]` so agreement is **N traceable data points, not headcount** |
| **Graceful degradation (loud)** | runner + `stop.evidence` | If the second pass can't run, mark `uncorroborated — single-pass` **loudly**; never silently treat a solo pass as corroborated (P6) |
| **Different in-house model** | runner (`CLAUDEWARP_QA_MODEL`) | The reproduction pass runs on Opus↔Sonnet for near-free diversity; same-model still filters non-reproducible findings |
| **Command-verification** | QA evaluator (reproduction pass) | A checkable-fact blocker must be reproduced by a **read-only command** (`grep`/`cat`/`head`/`tail`/`wc`) and tagged `[CMD_CONFIRMED]`/`[CMD_CONTRADICTED]`; a contradicted blocker is demoted one level — advisory, never auto-deletes |
| **Provenance-binding (cited git artifacts)** | QA evaluator (reproduction pass) | A finding that **cites a git object** has its citation re-checked against the object store — `git cat-file -e <sha>^{object}` / `git rev-parse --verify` (read-only) — and tagged `[SHA_CONFIRMED]`/`[SHA_MISSING]`; a `[SHA_MISSING]` citation is rejected (cannot gate **or** clear a merge), demoted like `[CMD_CONTRADICTED]` |
| **Static-inference consensus ≠ corroboration** | QA evaluator (reproduction pass) | Agreement reached by reading the **same source lines** (or citing pass-1) is `[STATIC-INFERENCE-CONSENSUS]`, not independent corroboration; only a re-derived catch or a `[CMD_CONFIRMED]` predicate compounds |
| **Read-only-reviewer guard** | `scripts/reviewer-guard.sh` (runner) | Snapshots the tree (`git status --porcelain` + a tracked-content digest) before/after a spawned review pass; ANY mutation fails **loud** — proving the reviewer was truly read-only |

`--corroborate` is **auto-on at R3+** (prod-adjacent stakes justify the ~2× review) and **opt-in at R2
and below**; it rides *behind* the existing `--with-qa` gate (no first pass ⇒ nothing to corroborate ⇒
no-op). This is **one sequential second pass**, not a panel, on a different *in-house* model, not
cross-vendor. A downgrade or `uncorroborated` mark **Surfaces** a Type-B call; it never silently
downgrades a human-gated decision.

### The behavioural-claim backlog

The reviewer features above are all **instruction-only** — a static `working/` verifier proves the
charter *text is present*, never that the charter *fires* on a real defect.
[`BEHAVIOURAL-CLAIMS.md`](https://github.com/lucagattoni/Claude-Warp/blob/main/BEHAVIOURAL-CLAIMS.md) is the standing registry that keeps that gap
visible: each feature is logged with the **behavioural claim** it makes, the **catch it predicts** on
a planted defect, and a **status** from a controlled vocabulary that never conflates two strengths of
evidence —

| Status | Means | Strength |
|---|---|---|
| `unverified` | charter text present; no dogfood has produced the catch yet (the default) | present only |
| `verified-on-fixture <date>` | an **in-context** reviewer pass applied the charter to the tracked fixture and the catch fired — proves *the instructions cause the catch* | medium |
| `verified-live <date>` | a **real spawned independent agent** (`claude -p`, different in-house model, reasoning-blind) produced the catch — proves it *survives independence* | strong |

The reproducible procedure is [`tests/dogfood/RUNBOOK.md`](https://github.com/lucagattoni/Claude-Warp/blob/main/tests/dogfood/RUNBOOK.md) run against
the tracked fixture
[`tests/dogfood/trivially-passing-contract.yaml`](https://github.com/lucagattoni/Claude-Warp/blob/main/tests/dogfood/trivially-passing-contract.yaml)
— a deliberately broken contract whose every planted defect is tagged `# PLANT[<row>]`. The honesty
crux is the vocabulary itself: **a fixture pass is strictly weaker than a live pass and is never
relabelled as one** (P6 applied to our own claims).

The live-flip history: a spawned **Sonnet** reviewer (different model from the Opus drafter,
reasoning-blind) flipped the red-team charter + honesty riders (D2, v0.31.1), `/converge` (D3,
v0.31.3 — setting it up first *corrected* a mischaracterised claim), reproduction-required (D4,
v0.31.4), and command-verification (D5, v0.32.2), each producing its predicted catch under a real
spawned independent agent — taking the backlog to **5/5 `verified-live`**.

**v0.33.0 re-opened the count to 5/6.** A sixth rule — **provenance-binding** of cited git artifacts —
lands in the QA reproduction pass: a finding that cites a git object has its citation re-checked
against the object store and tagged `[SHA_CONFIRMED]`/`[SHA_MISSING]`; a `[SHA_MISSING]` citation is
**rejected**. Like every fresh instruction-only feature it enters `unverified` — the static checker
proves the charter text is present, not that a live agent runs `cat-file` under independence — so the
backlog count moves **5/5 → 5/6** and the live flip is **Dogfood D6** (pending). The re-open is the
backlog doing its job: a new untested mechanism is tracked as a visible gap, not shipped silently
inside a "complete" count.

> The `dev.sh verify` check-7 single-sources this `5/6` literal: it is computed from the claim
> headings in `BEHAVIOURAL-CLAIMS.md` and asserted identical here, so a count update can't half-land.

### Enforcing a verdict — the `review-gate` hook (`review-result.v1`)

The riders above govern how a review *reports*; they do not, on their own, *stop* a loop that ignores a
bad verdict. The **`review-gate`** hook pattern (`/claude-warp-new-hook`) closes that gap: a review
surface writes a machine-readable verdict to `.claudewarp/review-result.json`, and a `Stop` hook reads
it and **blocks turn end** until it is `APPROVE` with zero open critical/major findings.

```json
{ "schema": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES | decision_needed",
  "findings": [ { "severity": "critical|major|minor|recommendation", "note": "<what>" } ] }
```

Two properties keep it honest rather than theatre. It **fails closed** — a missing or unparseable
verdict blocks, because *no review* must count as *not approved* (P6 applied to the gate itself). And it
**separates review from enforcement**: the surface that *produces* the verdict (the contract Phase 6
critical pass, the QA evaluator, `/converge`, or a manual pass) is never the code that *enforces* it, so
a loop cannot grade-and-pass itself in one move. Only `critical`/`major` gate (mirroring the
severity→verdict rider); `minor`/`recommendation` are recorded, never blocking. Because the hook is
deterministic shell, its logic is covered by a direct exit-code test — so, unlike the instruction-only
riders above, it needs no behavioural-claim dogfood. Adapts **claude-code-harness**'s `review-result.v1`
verdict + commit guard (Chachamaru127) — critically: ClaudeWarp gates the `Stop` event (the loop's own
done-signal), not only `git commit`, and reuses the existing severity vocabulary instead of a parallel one.
