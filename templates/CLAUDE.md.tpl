# {{PROJECT_NAME}}

> Loop engineering harness installed by ClaudeWarp.

## Project

- **Type:** {{PROJECT_TYPE}}
- **Root:** {{REPO_ROOT}}
- **Harness version:** {{HARNESS_VERSION}}

## Loop engineering context

This project uses Claude Code loop engineering patterns. Key principle: you write loops
that prompt Claude autonomously — not one-shot prompts.

**Skills available** (invoke with `/skill-name`):
- `/new-loop "goal"` — scaffold a new loop (SKILL.md + guard + trigger + state)
- `/harness-sync` — re-check Claude Code changelog; prune superseded harness components
- `/plan-task "title"` — create a plans/<slug>.md with phases and success criteria

## Loop conventions

- Every loop skill lives in `.claude/skills/<name>/SKILL.md`
- Every loop has a **stopping condition** defined in its SKILL.md
- Every loop has a **guard script** at `scripts/guard-<name>.sh` (prevents double-runs)
- State that accumulates across runs goes in a dedicated tracking file, never in CLAUDE.md
- Logs go in `logs/` (gitignored)

## Scheduling

External trigger (cron/launchd) → `scripts/run-<name>.sh` → `claude -p "/<name>"`.
See `templates/trigger.crontab.tpl` and `docs/guide.md` for setup instructions.

## Timestamps

All timestamps in this project use Irish Standard Time:
```bash
TZ='Europe/Dublin' date '+%Y-%m-%d %H:%M %Z'
```
