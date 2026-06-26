# ClaudeWarp — Installation

---

## Prerequisites

- **Claude Code** installed and authenticated (`claude --version` works)
- A **git repository** — ClaudeWarp commits its own setup, so the target directory must be a git repo
- macOS or Linux (Windows via WSL)

---

ClaudeWarp installs two ways. They are complementary — pick by what you want:

| | **curl installer** | **Claude Code plugin** |
|---|---|---|
| Command | `bash <(curl -fsSL …/install.sh)` | `/plugin marketplace add lucagattoni/Claude-Warp` + `/plugin install` |
| Skill names | bare — `/claude-warp-setup` | namespaced — `/claude-warp:claude-warp-setup` |
| Runs project setup | **Yes** — fills `CLAUDE.md` + `harness-manifest.json` and commits | No — exposes skills only; run setup yourself afterwards |
| Scope | this project (`.claude/skills/`) | user or project, reusable everywhere |

Use the **curl installer** to onboard a single project in one shot. Use the **plugin** to have the skills available across all your projects with versioned updates via `/plugin update`.

---

## Install in a project (curl)

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

### Installing into a non-empty repo

Setup is safe to run into a repo that already has content or a prior ClaudeWarp install:

- An existing **`CLAUDE.md`** is preserved — ClaudeWarp's operating instructions are appended
  under a `## ClaudeWarp` section, never overwriting your content.
- An existing **`harness-manifest.json`** is preserved on re-install — registered loops,
  `last_sync`, and component statuses are kept; only the version fields are updated.
- The install commit stages only the files setup writes (`.claude/skills/`, `CLAUDE.md`,
  `harness-manifest.json`, `.gitignore`) — it won't sweep in unrelated changes from `plans/` or `docs/`.

To refresh skills to a new version, prefer `/claude-warp-update` over re-running the installer.

---

## Install as a Claude Code plugin

ClaudeWarp is also a [Claude Code plugin](https://code.claude.com/docs/en/plugins): the repo doubles as a single-plugin [marketplace](https://code.claude.com/docs/en/plugin-marketplaces). From inside Claude Code:

```text
/plugin marketplace add lucagattoni/Claude-Warp
/plugin install claude-warp@claude-warp
```

This registers the `claude-warp` marketplace and installs the `claude-warp` plugin (all 12 skills) at user scope, so they are available in every project — no per-project copy. Update with `/plugin update claude-warp@claude-warp`; uninstall with `/plugin uninstall claude-warp@claude-warp`.

To try it without installing (e.g. from a local clone):

```bash
claude --plugin-dir /path/to/Claude-Warp
```

### Namespacing

Plugin skills are **namespaced** under the plugin name, so they read `/claude-warp:claude-warp-<skill>` rather than the bare `/claude-warp-<skill>` of the curl install:

| curl install | plugin install |
|---|---|
| `/claude-warp-contract` | `/claude-warp:claude-warp-contract` |
| `/claude-warp-setup` | `/claude-warp:claude-warp-setup` |

The skills' own write-ups and "Next:" hand-offs still print the **bare** slug (e.g. `/claude-warp-new-goal`) — that text is an instruction Claude resolves to the installed skill in either mode, so cross-skill chaining works under both. When you type a hand-off command yourself after a plugin install, add the `claude-warp:` prefix.

The plugin path does **not** run `/claude-warp-setup` for you. After installing, run `/claude-warp:claude-warp-setup` once in a project to materialise its `CLAUDE.md` and `harness-manifest.json`.

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
