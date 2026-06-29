# Guide — Monitoring & keeping current

How to watch loops while they run, and how to keep the harness itself healthy and up to date.

## Monitoring running loops

Background agents and fan-out runners surface sessions through the Claude Code agent dashboard:

```bash
# Interactive dashboard — shows all running and completed sessions
claude agents

# Machine-readable — useful for scripting
claude agents --json | jq '.[].status'

# Tail output from a specific session
claude logs <session-id>

# Attach your terminal to a running session
claude attach <session-id>

# Restart a completed or failed session with full history
claude respawn <session-id>
```

For headless single-agent runners, output goes to `logs/<slug>-<date>.log`.

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

---

**Next:** [iterate on a loop](iterating.md) once you've seen how it behaves.
