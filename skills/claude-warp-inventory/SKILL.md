---
name: claude-warp-inventory
description: Zero-LLM self-inspection — scans installed ClaudeWarp resources (skills, agents, hooks, loops, harnesses) and reports versions, health issues, and stale entries; use to diagnose a broken or outdated install
---

Inspect the ClaudeWarp install in this project. No LLM turns needed for the
scan itself — all phases use Bash and Read only.

## Phase 1 — Read manifest

```bash
cat harness-manifest.json 2>/dev/null || echo "MISSING"
```

Record:
- `INSTALLED_VERSION` — `version` field (or "unknown" if missing)
- `LAST_SYNC` — `claude_code.last_sync` (or "never")
- `COMPONENTS` — all entries in `components[]` with their `status`

**If `harness-manifest.json` is missing,** distinguish two cases before reacting — a missing
manifest is only a problem for a real install, not for the ClaudeWarp source repo running
self-hosted via symlinks (`scripts/dev.sh selfhost`):

```bash
# Self-host detection: are .claude/skills entries symlinks into a sibling skills/ source?
if [ -d skills ] && ls -d .claude/skills/*/ >/dev/null 2>&1 && \
   [ -L "$(ls -d .claude/skills/*/ | head -1 | sed 's:/$::')" ]; then
  echo "SELF_HOST"
else
  echo "NO_MANIFEST"
fi
```

- `SELF_HOST` → this is the ClaudeWarp source repo dogfooding its own skills. Record mode as
  **"self-hosted dev repo (symlinks)"**, set `INSTALLED_VERSION` from `VERSION`, and **continue
  the scan** — do not warn or stop. (Manifest, loops, and agents are expected to be absent here.)
- `NO_MANIFEST` → a genuine broken/absent install. Print
  `⚠ harness-manifest.json not found — run /claude-warp-setup` and stop.

## Phase 2 — Scan skills

```bash
ls .claude/skills/ 2>/dev/null || echo "MISSING"
```

For each directory under `.claude/skills/`:
1. Check that `SKILL.md` exists inside it
2. Read the `name:` field from the frontmatter
3. Cross-reference with `harness-manifest.json` `loops[]` and known ClaudeWarp skill names

Flag:
- `⚠ missing SKILL.md` — directory exists but skill file absent
- `⚠ unknown skill` — not a ClaudeWarp skill and not registered in manifest (may be orphan)
- `✓` — present and recognised

## Phase 3 — Scan agents

```bash
ls .claude/agents/ 2>/dev/null || echo "none"
```

For each `.md` file:
1. Read `name:` and `model:` from frontmatter
2. Check model is a known Claude model ID (claude-opus-4-8, claude-sonnet-4-6, claude-haiku-4-5-*)
3. Flag unknown model strings as `⚠ stale model id` — may need updating after a model deprecation

## Phase 4 — Scan hooks

```bash
cat .claude/settings.json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
hooks=d.get('hooks',{})
for event,entries in hooks.items():
    for e in entries:
        print(event, e.get('command','?'))
" 2>/dev/null || echo "no hooks configured"
```

For each hook command, verify the referenced script exists:
```bash
# e.g. if command is "bash hooks/verify-npm-test.sh"
ls hooks/ 2>/dev/null
```

Flag `⚠ missing script` if the hook references a file that doesn't exist.

## Phase 5 — Scan loop & goal state files

```bash
ls *_LOG.md *-GOAL.md *-features.json 2>/dev/null || echo "none"
```

Detect each file's schema first — don't assume the loop shape (a §2.2 `GOAL.md` has no
`<!-- state:` header):

- **Loop state log** (has `<!-- state:` header): report `last_run`, `last_verdict`,
  `consecutive_fails`. Flag `⚠ consecutive_fails ≥ 3` (needs attention) and
  `⚠ last_verdict: IN_PROGRESS` (interrupted; next run recovers).
- **Goal** (`*-GOAL.md` with `## Done conditions`, no state header): report
  `<checked>/<total>` done conditions and whether it's COMPLETE. Flag
  `⚠ incomplete + no recent execution-log entry` (a stalled goal); a complete goal is `✓`.
- **Harness** (`*-features.json`): report task counts (done/pending/failed). Flag
  `⚠ failed > 0`.

## Phase 6 — Scan scripts

```bash
ls scripts/ 2>/dev/null || echo "none"
```

For each `run-*.sh` or `guard-*.sh`:
- Verify it is executable: `test -x scripts/<file>`
- Flag `⚠ not executable` if not

## Phase 7 — Print report

```
ClaudeWarp inventory ✓

  Installed version : <INSTALLED_VERSION>
  Mode              : <"installed" | "self-hosted dev repo (symlinks)">
  Last sync         : <LAST_SYNC>          (omit in self-host mode)
  Claude Code       : <version from harness-manifest or `claude --version`>

Skills (<N> installed):
  ✓ claude-warp-setup
  ✓ claude-warp-contract
  ...
  ⚠ <name> — <issue>

Agents (<N> installed):
  ✓ <name> (<model>)
  ⚠ <name> — stale model id: <model>

Hooks (<N> configured):
  ✓ <event> → <script>
  ⚠ <event> → <script> — missing script

Loop state files:
  ✓ <file> — last: <date>, verdict: <verdict>
  ⚠ <file> — consecutive_fails: <N> (needs attention)

Scripts:
  ✓ scripts/run-<slug>.sh
  ⚠ scripts/run-<slug>.sh — not executable (run: chmod +x scripts/run-<slug>.sh)

Issues found: <N>
```

If issues are found, suggest the remediation command for each one inline.
```
