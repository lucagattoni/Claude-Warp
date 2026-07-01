# Guide — Deployment posture

Before scheduling a loop unattended, choose how much it's allowed to do without a human.
This is separate from *what* the loop does — it's the safety boundary around it. ClaudeWarp's
autonomy levels (`L1`/`L2`/`L3`, assigned by `/claude-warp-new-loop` and `/claude-warp-contract`)
map to three deployment patterns:

| Autonomy | Deployment pattern | How to run it |
|---|---|---|
| **L1** report-only | **Approval-First** | Run interactively or with `--permission-mode plan`; the loop proposes, you approve. No unattended writes. |
| **L2** assisted | **Curated Allow-list** | `--permission-mode auto` with an explicit allowed-tools list and a `destructive-block` hook; safe non-production paths only. |
| **L3** unattended | **Sandboxed Full-Auto** | Run in an isolated environment (container, dedicated OS user, or worktree) with network/filesystem limits — never full-auto directly on production. |

Two control layers enforce this: **in-process** controls (hooks, `--permission-mode`,
allowed-tools — see [`/claude-warp-new-hook`](../reference/skills.md)) and **out-of-process** controls
(the OS user, container, or network boundary the loop runs inside). L3 loops need both. Full detail:
Claude-Loops [§2.3 Harness vs Environment Engineering](https://lucagattoni.github.io/Claude-Loops/24-harness-patterns/).

---

**Next:** [schedule it](scheduling.md) · [monitor it once it's running](monitoring.md).
