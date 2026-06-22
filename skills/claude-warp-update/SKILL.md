---
name: claude-warp-update
description: Pull the latest ClaudeWarp skills from GitHub into this project's .claude/skills/ and update harness-manifest.json
---

Update the ClaudeWarp skills installed in this project to the latest version from
the ClaudeWarp GitHub repo.

## Phase 1 — Get current state

1. Get local time:
   ```bash
   date '+%Y-%m-%d %H:%M %Z'
   ```

2. Read `harness-manifest.json` — get current `harness.version`.

3. List skills currently installed in this project:
   ```bash
   ls .claude/skills/
   ```
   Record as `INSTALLED_SKILLS`.

## Phase 2 — Fetch skill list from GitHub

Fetch the directory listing of skills in the ClaudeWarp repo:
```
WebFetch https://api.github.com/repos/lucagattoni/Claude-Warp/contents/skills
```

Parse the JSON array — each entry has `name` (skill directory) and `type: "dir"`.
Record as `REMOTE_SKILLS`.

Also fetch the latest CHANGELOG.md to determine the current released version:
```
WebFetch https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/CHANGELOG.md
```
Extract the topmost versioned heading (e.g. `## [0.4.0]`) as `REMOTE_VERSION`.

## Phase 3 — Compare

For each skill in `INSTALLED_SKILLS`:
- Fetch the remote SKILL.md:
  ```
  WebFetch https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/skills/<name>/SKILL.md
  ```
- Compare with local `.claude/skills/<name>/SKILL.md`
- If remote differs → mark as **update available**
- If skill not found in `REMOTE_SKILLS` → mark as **orphan** (removed upstream)

For each skill in `REMOTE_SKILLS` not in `INSTALLED_SKILLS`:
→ mark as **new skill available**

## Phase 4 — Apply updates

For each skill marked **update available**: overwrite the local copy with the
fetched remote content.

For each skill marked **new skill available**: install it:
```bash
mkdir -p .claude/skills/<name>
```
Write the fetched SKILL.md content to `.claude/skills/<name>/SKILL.md`.

For each skill marked **orphan**: do NOT delete — report it and let the user decide.

## Phase 5 — Update manifest

In `harness-manifest.json` update:
- `harness.version` → `REMOTE_VERSION`
- `harness.last_update` → current local timestamp

Write back.

## Phase 6 — Commit

```bash
git add .claude/skills/ harness-manifest.json
git commit -m "chore(claude-warp-update): sync skills to ClaudeWarp v<REMOTE_VERSION>"
```

If nothing changed: print "ClaudeWarp skills are up to date — no changes." and skip commit.

## Phase 7 — Report

```
claude-warp-update complete ✓

Remote      : https://github.com/lucagattoni/Claude-Warp
Version     : <LOCAL_VERSION> → <REMOTE_VERSION>

Skills updated  : <N>  (<names>)
Skills added    : <M>  (<names>)
Orphans found   : <K>  (<names — no action taken, review manually>)
```
