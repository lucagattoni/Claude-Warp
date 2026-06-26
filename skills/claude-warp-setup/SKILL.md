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
mkdir -p .claude/skills scripts plans docs logs
```

(Per-skill directories are created dynamically in Phase 3 from whatever skills the
ClaudeWarp source actually contains — never hardcode the skill list.)

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

Copy **every** skill from `$WARP_ROOT/skills/` into the target project — iterate the
source directory rather than naming skills, so new skills are never missed:

```bash
for dir in "$WARP_ROOT"/skills/*/; do
  name="$(basename "$dir")"
  mkdir -p ".claude/skills/$name"
  cp "$dir/SKILL.md" ".claude/skills/$name/SKILL.md"
done
```

This installs all ClaudeWarp skills present in the source (setup, new, contract,
new-loop, new-goal, new-harness, new-agent, new-hook, inventory, retro, sync,
sync-research, update — and anything added later). Confirm the count matches
`ls "$WARP_ROOT"/skills | wc -l`.

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
Skills  : <N> installed (list them from .claude/skills/, e.g.
          /claude-warp-new, /claude-warp-contract, /claude-warp-new-loop, …)
Next    : run /claude-warp-new "your goal here" — it routes to the right scaffold
          (or /claude-warp-contract "goal" to negotiate a full contract first)
          run /claude-warp-inventory to verify the install
          run /claude-warp-sync to check for Claude Code updates

To make skills globally available in all future projects (optional):
  cp -r .claude/skills/claude-warp-setup ~/.claude/skills/
```
(Do NOT write to ~/.claude/ — print the command only.)
