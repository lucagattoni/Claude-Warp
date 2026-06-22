---
name: setup-loop-harness
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
mkdir -p .claude/skills/new-loop
mkdir -p .claude/skills/harness-sync
mkdir -p scripts
mkdir -p plans
mkdir -p docs
mkdir -p logs
```

Ensure `logs/` is gitignored:
- Read `.gitignore`; if `logs/` is not present, append it.

## Phase 3 — Install skills from ClaudeWarp

The ClaudeWarp skills source directory is the repo where this skill lives.
Detect it: the running skill's path gives the ClaudeWarp root.

Copy from ClaudeWarp source into target project:
- `skills/new-loop/SKILL.md` → `.claude/skills/new-loop/SKILL.md`
- `skills/harness-sync/SKILL.md` → `.claude/skills/harness-sync/SKILL.md`
- `skills/claude-warp-update/SKILL.md` → `.claude/skills/claude-warp-update/SKILL.md`
- `skills/new-agent/SKILL.md` → `.claude/skills/new-agent/SKILL.md`
- `skills/new-harness/SKILL.md` → `.claude/skills/new-harness/SKILL.md`

## Phase 4 — Fill CLAUDE.md

Read `templates/CLAUDE.md.tpl` from the ClaudeWarp source.
Replace all placeholders:
- `{{PROJECT_NAME}}` → detected project name
- `{{PROJECT_TYPE}}` → detected project type
- `{{REPO_ROOT}}` → absolute path of project root
- `{{HARNESS_VERSION}}` → read from ClaudeWarp's own `harness-manifest.json.tpl` version field

If a `CLAUDE.md` already exists in the target project, append the ClaudeWarp section
under a `## ClaudeWarp` heading rather than overwriting.

## Phase 5 — Write harness-manifest.json

Read `templates/harness-manifest.json.tpl` from ClaudeWarp source.
Replace all placeholders:
- `{{HARNESS_VERSION}}` → ClaudeWarp version
- `{{INSTALLED_AT}}` → local time from Phase 1
- `{{PROJECT_NAME}}`, `{{PROJECT_TYPE}}`, `{{REPO_ROOT}}` → from Phase 1
- `{{CC_VERSION}}` → Claude Code version from Phase 1

Write to `harness-manifest.json` in the project root.

## Phase 6 — Commit

```bash
git add .claude/skills/ CLAUDE.md harness-manifest.json .gitignore plans/ docs/
git commit -m "chore: install ClaudeWarp loop harness v{{HARNESS_VERSION}}"
```

## Phase 7 — Report

Print a summary:
```
ClaudeWarp installed ✓

Project : <name> (<type>)
Skills  : /new-loop, /harness-sync, /claude-warp-update, /new-agent, /new-harness
Next    : run /new-loop "your goal here" to scaffold your first loop
          run /harness-sync to check for Claude Code updates

To make skills globally available in all future projects (optional):
  cp -r .claude/skills/setup-loop-harness ~/.claude/skills/
```
(Do NOT write to ~/.claude/ — print the command only.)
