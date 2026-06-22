# ClaudeWarp — Installation

---

## Prerequisites

- **Claude Code** installed and authenticated (`claude --version` works)
- A **git repository** — ClaudeWarp commits its own setup, so the target directory must be a git repo
- macOS or Linux (Windows via WSL)

---

## Install in a project

Navigate to your project root, then run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/install.sh)
```

This single command:
1. Downloads `install.sh` from GitHub
2. Copies the `/claude-warp-setup` skill into `.claude/skills/`
3. Runs `claude -p "/claude-warp-setup"` autonomously — Claude detects your project type, fills all templates, and commits the result

**What gets created in your project:**

```
.claude/
  skills/
    claude-warp-setup/        ← per-project installer (also usable in new projects)
    claude-warp-new-loop/     ← scaffold a loop
    claude-warp-new-harness/  ← scaffold a two-part harness
    claude-warp-new-agent/    ← scaffold a subagent
    claude-warp-sync/         ← prune superseded components
    claude-warp-update/       ← pull latest skills from GitHub
    claude-warp-sync-research/← gap analysis against Claude-Loops
CLAUDE.md                     ← loop engineering context (project-specific)
harness-manifest.json         ← version + component registry
scripts/                      ← guard and runner scripts land here
plans/                        ← planning documents
docs/                         ← project docs
logs/                         ← gitignored runtime logs
```

A single commit is created: `chore: install ClaudeWarp loop harness vX.Y.Z`

---

## Verify

```bash
cat harness-manifest.json
```

Check that `project.name` and `project.type` are not placeholder values. If anything looks wrong, edit `CLAUDE.md` and `harness-manifest.json` directly.

---

## Make the installer globally available (optional)

After your first install, copy `/claude-warp-setup` to your global Claude skills so you can install ClaudeWarp into any future project without re-running the curl command:

```bash
cp -r .claude/skills/claude-warp-setup ~/.claude/skills/
```

Then in any new project:
```bash
claude -p "/claude-warp-setup"
```

---

## Update ClaudeWarp in a project

When a new version of ClaudeWarp is released, pull the latest skills without reinstalling from scratch:

```bash
claude -p "/claude-warp-update"
```

This fetches each skill from GitHub, updates changed files, installs any new skills, and bumps the version in `harness-manifest.json`.

---

## Uninstall

ClaudeWarp does not touch anything outside your project directory. To remove it:

```bash
rm -rf .claude/skills/claude-warp-*
rm harness-manifest.json
# optionally remove the ClaudeWarp section from CLAUDE.md
```
