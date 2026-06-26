# Goal Readiness — G0 to G3

> "Goal" here means a **single-shot plan** — see [Concepts: Plans, Shapes, and the Contract](concepts.md). A plan is the spec; goal/loop/harness are the shapes it can take. This page is the readiness scale for the goal shape (and, via G2+/G3 gating, for any plan `/claude-warp-contract` produces).

Before an autonomous loop or goal can run reliably, the goal it is given needs to be specified well enough for an agent to:

1. Know what to do
2. Know when it is done
3. Stay within safe boundaries

The G0–G3 scale scores a goal across those three axes. ClaudeWarp uses it in `/claude-warp-new-goal` and `/claude-warp-contract` to gate whether a goal is ready to hand to an agent unattended.

---

## The scale

| Score | Label | Criteria | What happens |
|---|---|---|---|
| **G0** | Not ready | No verifiable done condition; objective is ambiguous or contradictory; two valid interpretations exist | Skill stops and explains what is missing |
| **G1** | Weak | Done condition is human-judgement-only ("looks good", "feels complete"); no programmatic check possible | Proceeds with a warning block in GOAL.md; budget cap is halved as a safeguard |
| **G2** | Functional | Programmatic verifier exists (a command with an exit code); scope is defined; budget is unspecified | Proceeds with a warning block; budget defaults conservatively |
| **G3** | Ready | Objective is unambiguous; verifier is a command with a deterministic exit code; scope and budget are both defined | Proceeds cleanly; no warnings |

---

## Scoring a goal

Ask these questions in order. Stop at the first criterion that fails.

**1. Is the objective unambiguous?**
A goal passes if a stranger could read it and predict, without asking any follow-up questions, what the agent will and will not do.

- Fail: "improve the codebase" (improve how? which parts?)
- Pass: "remove all `console.log` statements from `src/` and verify with `grep -r 'console.log' src/`"

**2. Is the done condition programmatic?**
The agent needs a shell command it can run and read the exit code of. Human judgement ("when it looks good") is G1 at best.

- Fail: "the PR is ready for review" (who decides?)
- Pass: "`npm test` exits 0 and `git diff --name-only HEAD~1` is non-empty"

**3. Is the scope defined?**
The goal specifies which files, directories, or systems the agent may touch — and ideally what it must never touch.

- Fail: "refactor the auth module" (all files? just the module? what about tests?)
- Pass: "refactor `src/auth/` only; must not modify `src/auth/legacy/`"

**4. Is the budget defined?**
A cost cap (`MAX_BUDGET_USD`) and turn cap (`MAX_TURNS`) prevent runaway sessions.

- Fail: no mention of time or cost
- Pass: "$2.00 max; 30 turns max"

---

## Why it matters

Autonomous agents follow the path of least resistance. An underspecified goal has two failure modes:

- **Hallucinated completion** — the agent decides it is done using internal reasoning rather than an observable check. It writes a pass verdict and stops, even though the work is wrong or incomplete.
- **Scope creep** — without explicit boundaries, the agent touches things it shouldn't, causing regressions the goal description never anticipated.

G3 goals are designed to make both failure modes structurally harder. The verifier is a command, not a judgement. The scope is a path, not a description.

---

## How ClaudeWarp uses it

**`/claude-warp-new-goal`** — scores the goal before creating any files:
- G0 → stops with explanation
- G1/G2 → proceeds but writes a `⚠ Warning` block at the top of `GOAL.md` listing what is missing
- G3 → proceeds cleanly

**`/claude-warp-contract`** — interactive contract negotiation. Drafts a complete, risk-classified Loop Contract (or Goal), then critically reviews it against known failure patterns and a readiness gate (LCR for loops, G0–G3 for goals) before handing off to a scaffolder. Run this first when a goal is vague or high-risk. Produces `loop-contract.yaml` + anchor files as the handoff artifact.

**`/claude-warp-new-loop` (L1/L2/L3)** — the loop autonomy level is derived from the same axes: does Phase 3 write files (scope), does Phase 3b have a programmatic verifier (verifier), does it touch production paths (scope + blast radius). L3 loops require G3-equivalent specification.

---

## Going deeper

**Why programmatic verifiers matter for agents:**
- [Anthropic — Building effective agents](https://www.anthropic.com/research/building-effective-agents) — covers tool use, verification, and why agents need observable exit conditions
- [Simon Willison — Prompting as a skill](https://simonwillison.net/2023/Oct/26/llm-automation/) — on the difference between "looks done" and "is done"

**Specification and goal engineering:**
- [Geoffrey Litt — The problem with AI tasks](https://www.geoffreylitt.com/2023/07/07/the-problem-with-ai-tasks.html) — on under-specification as the primary cause of autonomous agent failure
- [Addy Osmani — AI-assisted development](https://addyosmani.com/blog/ai-assisted-development/) — the L1/L2/L3 phased rollout discipline that the readiness scale is partially inspired by

**Loop engineering context (ClaudeLoops companion):**
- [ClaudeLoops](https://github.com/lucagattoni/Claude-Loops) — the knowledge base behind ClaudeWarp; goal engineering patterns are documented in `docs/doc-30-goal-engineering.md`
