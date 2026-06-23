---
name: claude-warp-setup
description: Configure ClaudeWarp in the current project — fills templates, creates dirs, writes harness-manifest.json, and commits
---

Set up the ClaudeWarp loop harness in the current project directory.

## Phase 1 — Detect project

1. Get the exact local time:
   ```bash
   date '+%Y-%m-%d %H:%M %Z'
   ```
2. Detect project type by checking for these files in order:
   - `package.json` → `node`
   - `pyproject.toml` or `setup.py` → `python`
   - `go.mod` → `go`
   - `Cargo.toml` → `rust`
   - None → `generic`
3. Read the project name from:
   - `package.json` → `.name` field
   - `pyproject.toml` → `[project] name`
   - `go.mod` → module path last segment
   - Otherwise → current directory name (`basename $(pwd)`)
4. Get repo root: `git rev-parse --show-toplevel`
5. Get installed Claude Code version: `claude --version`

## Phase 2 — Create directory structure

```bash
mkdir -p .claude/skills/claude-warp-setup
mkdir -p .claude/skills/claude-warp-new-loop
mkdir -p .claude/skills/claude-warp-sync
mkdir -p .claude/skills/claude-warp-update
mkdir -p .claude/skills/claude-warp-new-agent
mkdir -p .claude/skills/claude-warp-new-harness
mkdir -p .claude/skills/claude-warp-sync-research
mkdir -p scripts
mkdir -p plans
mkdir -p docs
mkdir -p logs
```

Ensure `logs/` is gitignored:
- Read `.gitignore`; if `logs/` is not present, append it.

## Phase 3 — Locate ClaudeWarp source and install skills

**Locate the ClaudeWarp source** — check in order:
1. `.claudewarp-skills/` exists at the project root → use it (placed by `install.sh`)
2. Otherwise, derive from this SKILL.md's own path: go up to the repo root
   (e.g. `~/.claude/skills/claude-warp-setup/` → `~/.claude/skills/` is the skills dir;
   the ClaudeWarp root is two levels up from this file)

Record the resolved ClaudeWarp root as `WARP_ROOT`.

**Similarly locate templates:**
1. `.claudewarp-templates/` exists at the project root → `TEMPLATE_ROOT=.claudewarp-templates`
2. Otherwise → `TEMPLATE_ROOT=$WARP_ROOT/templates`

Copy skills from `$WARP_ROOT/skills/<name>/SKILL.md` into the target project:
- `claude-warp-setup` → `.claude/skills/claude-warp-setup/SKILL.md`
- `claude-warp-new-loop` → `.claude/skills/claude-warp-new-loop/SKILL.md`
- `claude-warp-sync` → `.claude/skills/claude-warp-sync/SKILL.md`
- `claude-warp-update` → `.claude/skills/claude-warp-update/SKILL.md`
- `claude-warp-new-agent` → `.claude/skills/claude-warp-new-agent/SKILL.md`
- `claude-warp-new-harness` → `.claude/skills/claude-warp-new-harness/SKILL.md`
- `claude-warp-sync-research` → `.claude/skills/claude-warp-sync-research/SKILL.md`

Read `$WARP_ROOT/VERSION` and record as `HARNESS_VERSION`.

## Phase 4 — Fill CLAUDE.md

Read `$TEMPLATE_ROOT/CLAUDE.md.tpl`.
Replace all placeholders:
- `{{PROJECT_NAME}}` → detected project name
- `{{PROJECT_TYPE}}` → detected project type
- `{{REPO_ROOT}}` → absolute path of project root
- `{{HARNESS_VERSION}}` → `HARNESS_VERSION` from Phase 3

If a `CLAUDE.md` already exists in the target project, append the ClaudeWarp section
under a `## ClaudeWarp` heading rather than overwriting.

## Phase 5 — Write harness-manifest.json

Read `$TEMPLATE_ROOT/harness-manifest.json.tpl`.
Replace all placeholders:
- `{{HARNESS_VERSION}}` → `HARNESS_VERSION` from Phase 3
- `{{INSTALLED_AT}}` → local time from Phase 1
- `{{PROJECT_NAME}}`, `{{PROJECT_TYPE}}`, `{{REPO_ROOT}}` → from Phase 1
- `{{CC_VERSION}}` → Claude Code version from Phase 1

Write to `harness-manifest.json` in the project root.

## Phase 6 — Commit

Use the literal version string resolved in Phase 3 (e.g. `0.6.0`) — do not write
`{{HARNESS_VERSION}}` literally in the commit message.

```bash
git add .claude/skills/ CLAUDE.md harness-manifest.json .gitignore plans/ docs/
git commit -m "chore: install ClaudeWarp loop harness v<HARNESS_VERSION>"
```

## Phase 7 — Report

Print a summary:
```
ClaudeWarp installed ✓

Project : <name> (<type>)
Skills  : /claude-warp-new-loop, /claude-warp-sync, /claude-warp-update,
          /claude-warp-new-agent, /claude-warp-new-harness, /claude-warp-sync-research
Next    : run /claude-warp-new-loop "your goal here" to scaffold your first loop
          run /claude-warp-sync to check for Claude Code updates
          run /claude-warp-update to pull the latest ClaudeWarp skills

To make skills globally available in all future projects (optional):
  cp -r .claude/skills/claude-warp-setup ~/.claude/skills/
```
(Do NOT write to ~/.claude/ — print the command only.)
