---
name: harness-sync
description: Re-check the Claude Code changelog and prune harness components that have become native; update harness-manifest.json with current CC version
---

Synchronise the ClaudeWarp harness against the current Claude Code version.

## Phase 1 — Get current state

1. Get Irish time:
   ```bash
   TZ='Europe/Dublin' date '+%Y-%m-%d %H:%M %Z'
   ```
2. Get installed Claude Code version:
   ```bash
   claude --version
   ```
   Record as `CC_VERSION`.
3. Read `harness-manifest.json` — get `claude_code.last_sync` and `components[]`.

## Phase 2 — Fetch changelog

Check if `~/.claude/cache/changelog.md` exists and is less than 24 hours old:
```bash
find ~/.claude/cache/changelog.md -mmin -1440 2>/dev/null
```

If stale or absent, fetch the latest changelog:
```
WebFetch https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md
```
Write the result to `~/.claude/cache/changelog.md`.

## Phase 3 — Check each component

For each component in `harness-manifest.json` `components[]` where `status == "active"`:

Read the component's `native_since` field. If it is non-null and `native_since` ≤ `CC_VERSION`:
→ the component is **superseded** (already handled natively by Claude Code).

Additionally, scan the fetched changelog for evidence that any currently-active component
is now natively supported. Key patterns to look for:

| Component | Look for in changelog |
|---|---|
| `scheduling-guards` | native "run at most once per day" or guard primitive |
| `external-trigger` | scheduled-tasks that work without daemon running |
| `cross-run-state` | native structured state persistence across sessions |
| `changelog-monitor` | native self-update or harness-sync mechanism |
| `loop-scaffolder` | native loop scaffolding CLI or skill generator |

If evidence found → record the version and set `native_since` in the manifest.

## Phase 4 — Apply auto-cuts

For each component now marked superseded (auto-cut policy agreed):

1. Set `status` → `"superseded"` in `harness-manifest.json`.
2. Write a migration note to `HARNESS_SYNC_LOG.md`:
   ```markdown
   ## YYYY-MM-DD HH:MM IST
   ### Component superseded: <name>
   **Native since:** Claude Code v<version>
   **Migration:** <one sentence on how to use the native feature instead>
   **Action:** Component stubbed/removed from harness.
   ---
   ```
3. If the component has a corresponding skill in `.claude/skills/`, add a deprecation
   notice at the top of its SKILL.md rather than deleting it — so any project that
   already uses it sees a clear migration path.

## Phase 5 — Update manifest

Write back to `harness-manifest.json`:
- `claude_code.version_at_install` → preserve (do not overwrite)
- `claude_code.last_sync` → current IST timestamp
- Update any `native_since` and `status` fields found in Phase 3–4.

## Phase 6 — Commit

```bash
git add harness-manifest.json HARNESS_SYNC_LOG.md .claude/skills/
git commit -m "chore(harness-sync): CC v<CC_VERSION>, <N> components checked, <M> superseded"
```
If nothing changed: log "harness up to date, no changes" and skip the commit.

## Phase 7 — Report

```
harness-sync complete ✓

Claude Code version : <CC_VERSION>
Components checked  : <N>
Superseded          : <M> (see HARNESS_SYNC_LOG.md)
Next sync           : tomorrow (or run /harness-sync anytime)
```
