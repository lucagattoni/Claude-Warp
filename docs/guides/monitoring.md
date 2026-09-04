# Guide — Monitoring & keeping current

How to watch loops while they run, and how to keep the harness itself healthy and up to date.

## Monitoring running loops

Background agents and fan-out runners surface sessions through the Claude Code agent dashboard:

```bash
# Interactive dashboard — shows all running and completed sessions
claude agents

# Machine-readable — useful for scripting. --all includes finished sessions (without it a
# finished session simply disappears). state: working | blocked | done; waitingFor says
# what a blocked session is waiting on.
claude agents --json --all | jq '.[] | {id, state, waitingFor}'

# Tail output from a specific session
claude logs <session-id>

# Attach your terminal to a running session
claude attach <session-id>

# Restart a completed or failed session with full history
claude respawn <session-id>
```

For headless single-agent runners, output goes to `logs/<slug>-<date>.log`.

## Cost per run

For a loop you routed to native `/loop` instead of a cron runner, `/usage` shows a **Loops**
breakdown — run count, total tokens, tokens per run, last run (v2.1.243+). Tokens per run *is*
cost per closed unit for a loop whose unit of work is one wake-up; tokens-per-run climbing
without more units closed is the runaway signal to slow down or kill. For a ClaudeWarp headless
runner the ceiling is the `--max-budget-usd` it was launched with and the log records every
attempt; a fan-out worker (`claude --bg`) takes no dollar cap at all — its runner pins the model
and stops stragglers at a deadline instead (see [Scaffolding → Fan-out loop](scaffolding.md#fan-out-loop-parallel)).

---

## Keeping the harness current

**Sync with Claude Code** — prunes harness components that Claude Code now handles natively:
```bash
claude -p "/claude-warp-sync"
```

**Update ClaudeWarp skills** — pulls the latest skill versions from GitHub:
```bash
claude -p "/claude-warp-update"
```

**Research new patterns** — scans Claude-Loops on GitHub for concepts not yet in ClaudeWarp (developer tool, run from the ClaudeWarp source repo):
```bash
claude -p "/claude-warp-sync-research"
```

**Check the install** — zero-LLM scan of installed skills, agents, hooks, and loop state files; flags missing files, stale model IDs, or loops needing attention:
```bash
claude -p "/claude-warp-inventory"
```

**Prune what never fires** — native `/skill-doctor` (v2.1.261+) lists the loaded skills that go
unused in a project and what each costs in context. A ClaudeWarp skill that never fires in a
given project is a candidate for removal from that project's `.claude/skills/` — the same
shrink-on-evidence rule `/claude-warp-sync` applies to the harness itself.

---

**Next:** [iterate on a loop](iterating.md) once you've seen how it behaves.
