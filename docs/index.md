---
hide:
  - navigation
  - toc
---

<p align="center">
  <img src="https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/assets/claude-warp-header.png" alt="Claude-Warp — a loop harness for Claude Code" width="820">
</p>

# ClaudeWarp

**The loop harness for Claude Code.** ClaudeWarp installs the infrastructure layer Claude Code
doesn't provide natively — loop scaffolding, scheduling guards, headless runners, readiness gates,
and a self-pruning mechanism that retires components as Claude Code absorbs them. You describe *what
you want and how to know it's done*; it scaffolds the right thing to run it — once, on a schedule, or
as a large multi-stage job — and stops when it should.

It is intentionally thin. Anything Claude Code already handles — subagents, worktrees, memory, code
review, scheduling runtime — is referenced, not reimplemented.

<div class="grid cards" markdown>

-   :hatching_chick:{ .lg .middle } __New to this?__

    ---

    Run your first autonomous task in ~10 minutes — zero prior loop or Claude-Code-lifecycle
    knowledge assumed. Then read the concepts for the *why*.

    [:octicons-arrow-right-24: Quickstart](quickstart.md) ·
    [Concepts](concepts.md)

-   :rocket:{ .lg .middle } __Claude Code veteran?__

    ---

    Skip the intro. Function overview, deep reference, and the harness architecture.

    [:octicons-arrow-right-24: Skills reference](reference/skills.md) ·
    [Architecture](reference/architecture.md)

-   :package:{ .lg .middle } __Install__

    ---

    One curl command (runs project setup) or the Claude Code plugin (skills everywhere).

    [:octicons-arrow-right-24: Install](install.md)

-   :gear:{ .lg .middle } __Building on ClaudeWarp?__

    ---

    `dev.sh` checks, the verifier library, templates, and prior-art acknowledgements.

    [:octicons-arrow-right-24: Developing](reference/developing.md) ·
    [Templates](reference/templates.md)

</div>

---

## The model in one breath

You tell ClaudeWarp *what you want and how to know it's done*; it figures out whether that's a
one-shot **goal**, a recurring **loop**, or a big multi-stage **harness**, and scaffolds the right
thing. One door — `/claude-warp-contract` — classifies the shape for you.

| Shape | Runs | When the plan is… |
|---|---|---|
| **goal** | once, stops at a verifiable check | small, one-and-done |
| **loop** | recurs on a schedule or event | recurring |
| **harness** | decomposed into subplans | big / multi-stage |

→ The full model: [Concepts](concepts.md). · Ready to specify safely: [Goal readiness](goal-readiness.md).

## How-to guides

[Scaffolding](guides/scaffolding.md) ·
[Scheduling](guides/scheduling.md) ·
[Deployment posture](guides/deployment.md) ·
[Monitoring](guides/monitoring.md) ·
[Iterating](guides/iterating.md)

## Companion

[ClaudeLoops](https://lucagattoni.github.io/Claude-Loops/) is the knowledge base behind ClaudeWarp —
loop-engineering patterns, failure modes, and building blocks.
