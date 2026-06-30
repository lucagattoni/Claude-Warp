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

Ensure `logs/` and the runtime ledger are gitignored:
- Read `.gitignore`; if `logs/` is not present, append it.
- If `.claudewarp/ledger.jsonl` is not present, append it — the cross-session closure ledger
  (`/claude-warp-ledger`) is local runtime data (per-checkout persistence), like a log, so it
  stays out of version control by default.

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

**If a `CLAUDE.md` already exists**, do not write the full template (it is a standalone
document with its own `# {{PROJECT_NAME}}` title and a "harness installed by ClaudeWarp"
tagline that would misframe an existing project). Instead, append a single `## ClaudeWarp`
section containing **only the operating content** from the template — the Skills list, Loop
conventions, Escalation rules, Scheduling, and Token/context discipline. **Omit** the H1 title,
the tagline, and the `## Project` identity block (the host `CLAUDE.md` already provides those).
Demote the template's `##` headings to `###` so they nest under the `## ClaudeWarp` heading.

## Phase 4b — Scaffold the project constitution

Standing project governance the contract critical pass validates against (see
`/claude-warp-contract` Phase 6/7). Scaffold it **only if absent** — never overwrite a
constitution the user has filled in.

```bash
mkdir -p .claudewarp
```

If `.claudewarp/constitution.md` does **not** exist, read `$TEMPLATE_ROOT/constitution.md.tpl`,
replace `{{PROJECT_NAME}}` (detected name) and `{{INSTALLED_AT}}` (Phase 1 local time), and write
it to `.claudewarp/constitution.md`. It ships **unfilled** — the constitution check is a no-op
until the user replaces the `# UNFILLED` example rows, so this is safe on every project. If the
file already exists, leave it untouched.

## Phase 5 — Write harness-manifest.json

**If `harness-manifest.json` already exists** (re-install or upgrade), do **not** overwrite it —
that would wipe harness state. Read it and update **only** the version fields, preserving
everything else:

- Preserve: `loops[]` (registered by `/claude-warp-new-loop`), any `harnesses[]`, the
  `components[]` array and each component's `status` (set by `/claude-warp-sync`),
  `claude_code.last_sync`, `claude_code.last_sync_version` (the sync scan baseline — do not reset it,
  or the next sync re-scans from scratch), `last_update`, and the original `installed_at`.
- Update: `version` → `HARNESS_VERSION`; `claude_code.version_at_install` → Claude Code version
  from Phase 1; add `reinstalled_at` → local time from Phase 1.

**If no manifest exists** (fresh install), read `$TEMPLATE_ROOT/harness-manifest.json.tpl` and
replace all placeholders:
- `{{HARNESS_VERSION}}` → `HARNESS_VERSION` from Phase 3
- `{{INSTALLED_AT}}` → local time from Phase 1
- `{{PROJECT_NAME}}`, `{{PROJECT_TYPE}}`, `{{REPO_ROOT}}` → from Phase 1
- `{{CC_VERSION}}` → Claude Code version from Phase 1

Write to `harness-manifest.json` in the project root.

## Phase 6 — Commit

Use the literal version string resolved in Phase 3 (e.g. `0.6.0`) — do not write
`{{HARNESS_VERSION}}` literally in the commit message.

Stage only the files setup created or changed — never blanket-add `plans/` or `docs/`, which
in an existing repo would sweep the user's unrelated uncommitted work into the install commit:

```bash
git add .claude/skills/ CLAUDE.md harness-manifest.json .gitignore .claudewarp/constitution.md
git commit -m "chore: install ClaudeWarp loop harness v<HARNESS_VERSION>"
```

## Phase 7 — Report

Print a summary:
```
ClaudeWarp installed ✓

Project : <name> (<type>)
Skills  : <N> installed (list them from .claude/skills/, e.g.
          /claude-warp-contract, /claude-warp-new-loop, /claude-warp-new-goal, …)
Govern  : .claudewarp/constitution.md scaffolded (unfilled — fill it to enable the
          constitution gate in /claude-warp-contract)
Next    : run /claude-warp-contract "your goal here" — the single entry: it specifies
          your plan, auto-routes to the shape (single-shot/loop/harness), and scaffolds
          run /claude-warp-inventory to verify the install
          run /claude-warp-sync to check for Claude Code updates

To make skills globally available in all future projects (optional):
  cp -r .claude/skills/claude-warp-setup ~/.claude/skills/
```
(Do NOT write to ~/.claude/ — print the command only.)
