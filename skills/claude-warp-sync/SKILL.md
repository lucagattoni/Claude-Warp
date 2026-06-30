---
name: claude-warp-sync
description: Scan every Claude Code release between the last-scanned version and current, prune harness components that have become native, and record the new last-scanned version (manifest for installs, the Native-vs-harness provenance line for the source repo)
---

Synchronise the ClaudeWarp harness against the current Claude Code version.

## Phase 1 — Get current state + the scan window

1. Get local time:
   ```bash
   date '+%Y-%m-%d %H:%M %Z'
   ```
2. Get installed Claude Code version:
   ```bash
   claude --version
   ```
   Record as `CC_VERSION`.
3. Establish `LAST_SCANNED` — the CC version this harness was last scanned against. The pair
   `(LAST_SCANNED, CC_VERSION]` is the **scan window**; the whole point of a sync is to read every
   release inside it, so getting the lower bound right is mandatory.
   - **Install** (a `harness-manifest.json` exists): read `claude_code.last_sync_version`. If that
     field is absent (older manifest), fall back to `claude_code.version_at_install`. Also load
     `components[]`.
   - **Self-hosted source repo** (no `harness-manifest.json`): there are no tracked components to
     prune, **but still run the scan** — the boundary record lives in the docs instead. Read
     `LAST_SCANNED` from the provenance line in `docs/reference/architecture.md` (the
     "Boundary last verified against Claude Code vX.Y.Z" marker under the *Native vs harness* table);
     if absent, fall back to the highest CC version referenced anywhere in `docs/`. The
     *Native vs harness* table is the source-repo equivalent of `components[]`.
   - If `LAST_SCANNED` == `CC_VERSION`: the window is empty — print
     `already scanned against vCC_VERSION — nothing new` and stop (no commit).

## Phase 2 — Get a changelog that spans the whole window

The canonical changelog contains **every** released version, so a single copy covers any window.

```bash
find ~/.claude/cache/changelog.md -mmin -1440 2>/dev/null
```

Fetch if stale or absent (and **also** re-fetch if the cache's newest `## ` heading is older than
`CC_VERSION`, or its oldest heading is newer than `LAST_SCANNED` — the cache must fully cover the
window):
```
WebFetch https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md
```
Write the result to `~/.claude/cache/changelog.md`.

## Phase 3 — Scan EVERY release in the window (not a keyword grep)

This is the heart of the skill. **Read the full release notes of every version `v` such that
`LAST_SCANNED < v ≤ CC_VERSION`** — one release at a time, top to bottom. Do not shortcut this with a
keyword grep of the latest entry only: a supersession can land in any intermediate release, and the
changelog **skips version numbers** (e.g. 184, 188, 189 may simply not exist) — scan the versions
that *are* present in the window, all of them.

Extract the window into view first, then read it:
```bash
# print every release from CC_VERSION down to (but not including) LAST_SCANNED
awk -v top="## $CC_VERSION" -v bot="## $LAST_SCANNED" \
    '$0==top{f=1} $0==bot{exit} f{print}' ~/.claude/cache/changelog.md
```
Sanity-check coverage: list the `## ` headings the window contains and confirm the top is
`CC_VERSION` and the next-below-window heading is `LAST_SCANNED`. If the window is large, read it in
chunks — but read **all** of it.

For **each** release in the window, judge every still-active component (install: `components[]` with
`status == "active"`; self-host: each **Harness** row of the *Native vs harness* table) against that
release's notes. The patterns below are a **checklist applied to every release**, not a substitute
for reading the prose:

| Component | Native-supersession signal |
|---|---|
| `scheduling-guards` | a native once-per-run / "run at most once per day" guard primitive |
| `external-trigger` | scheduled tasks / cron that fire without ClaudeWarp's crontab + headless runner |
| `cross-run-state` | native structured, deduped state persisted across sessions |
| `changelog-monitor` | native self-update *that also prunes user scaffolds* (a harness-sync) |
| `loop-scaffolder` | a native CLI/skill generator that scaffolds a loop (skill + guard + runner + state) |
| `agent-scaffolder` | a native generator for `.claude/agents/` definitions |

Also note releases that merely **reinforce** an already-native row (more agent/worktree/skill/
code-review/scheduling maturity) — these don't supersede anything but belong in the report so the
boundary stays honestly dated.

A component is **superseded** only when a release in the window provides a genuine native equivalent.
Record the exact version that introduced it as `native_since`. A close-but-not-equal case (e.g.
native scheduling that still needs the daemon, where the harness runs daemon-free) is **not** an
auto-cut — surface it as a judgment call for the user, do not silently flip it.

## Phase 4 — Apply auto-cuts

For each component now marked superseded (auto-cut policy agreed):

1. Set `status` → `"superseded"` in `harness-manifest.json`.
2. Write a migration note to `HARNESS_SYNC_LOG.md`:
   ```markdown
   ## YYYY-MM-DD HH:MM <TZ>
   ### Component superseded: <name>
   **Native since:** Claude Code v<version>
   **Migration:** <one sentence on how to use the native feature instead>
   **Action:** Component stubbed/removed from harness.
   ---
   ```
3. If the component has a corresponding skill in `.claude/skills/`, add a deprecation
   notice at the top of its SKILL.md rather than deleting it — so any project that
   already uses it sees a clear migration path.

## Phase 5 — Record the new baseline (so the next window starts here)

The next sync must start from where this one ended — **persist the version just scanned**, not only a
timestamp. Without this the window can never advance and every run re-scans from the install version.

- **Install** — write back to `harness-manifest.json`:
  - `claude_code.version_at_install` → preserve (do not overwrite)
  - `claude_code.last_sync` → current local timestamp
  - **`claude_code.last_sync_version` → `CC_VERSION`** (the new lower bound for next time)
  - Update any `native_since` and `status` fields found in Phase 3–4.
- **Self-hosted source repo** — update the provenance line under the *Native vs harness* table in
  `docs/reference/architecture.md` to read `Boundary last verified against Claude Code v<CC_VERSION>
  (<date>)`, naming the window `v<LAST_SCANNED+1> → v<CC_VERSION>` that was scanned and whether
  anything was superseded. This line **is** the source-repo baseline.

## Phase 6 — Commit

```bash
# install:
git add harness-manifest.json HARNESS_SYNC_LOG.md .claude/skills/
# self-host:
git add docs/reference/architecture.md
git commit -m "chore(claude-warp-sync): CC v<CC_VERSION>, window v<LAST_SCANNED>→v<CC_VERSION>, <M> superseded"
```
If the window was non-empty but nothing was superseded, still commit the advanced baseline (the
recorded `last_sync_version` / provenance line changed). Only skip the commit when the window was
empty (`LAST_SCANNED == CC_VERSION`). On a self-host repo, post-release housekeeping rides in a PR —
never push the baseline bump direct to `main`.

## Phase 7 — Report

```
claude-warp-sync complete ✓

Claude Code version : <CC_VERSION>
Window scanned      : v<LAST_SCANNED> → v<CC_VERSION>  (<K> releases read)
Components checked  : <N>
Superseded          : <M> (see HARNESS_SYNC_LOG.md)
Reinforced (no cut) : <brief — rows the window strengthened but did not supersede>
Next sync           : starts from v<CC_VERSION> (or run /claude-warp-sync anytime)
```
