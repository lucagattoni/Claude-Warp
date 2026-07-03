# Reference — Templates

The `.tpl` files in `templates/` are the skeletons the scaffolders fill. Each is owned by one skill,
which substitutes the goal-derived values (see [Skills](skills.md)) before writing the materialised
file into your project.

| Template | Used by | Purpose |
|---|---|---|
| `CLAUDE.md.tpl` | `claude-warp-setup` | Base loop engineering context for a project |
| `loop.SKILL.md.tpl` | `claude-warp-new-loop` | Loop skill skeleton: guard → state → work → verify → write → stop |
| `guard.sh.tpl` | `claude-warp-new-loop` | Run-once-per-day / weekday-only guard script |
| `run-headless.sh.tpl` | `claude-warp-new-loop` | Single-agent headless runner with `--max-turns`, `--max-budget-usd`, configurable `--effort`, and an optional `--worktree` mode (throwaway worktree + origin-advanced retry guard, for L3 loops) |
| `run-fanout.sh.tpl` | `claude-warp-new-loop` | Parallel fan-out runner: `claude --bg --worktree` per item, git-isolated, polled via `claude agents --json` |
| `run-two-stage.sh.tpl` | `claude-warp-new-loop` | Two-session pipeline runner (KB Tracker shape): a search stage and an integrate stage run sequentially in one throwaway worktree with an artifact handoff |
| `trigger.crontab.tpl` | `claude-warp-new-loop` | Reference cron entry (not installed — paste into `crontab -e`) |
| `harness-manifest.json.tpl` | `claude-warp-setup` | Version + components registry |
| `VISION.md.tpl` | `claude-warp-new-harness` | Anchor file: high-level goal and success criteria |
| `AGENTS.md.tpl` | `claude-warp-new-harness` | Anchor file: agent roles and handoff protocol |
| `PROMPT.md.tpl` | `claude-warp-new-harness` | Anchor file: current work unit; edit to re-task the loop |

For how these files behave once running, see [Architecture → Loop anatomy](architecture.md#loop-anatomy).
