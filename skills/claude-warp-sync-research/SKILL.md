---
name: claude-warp-sync-research
description: Developer tool — runs claude-warp-sync first, then scans Claude-Loops for patterns and concepts not yet implemented in ClaudeWarp; surfaces prioritised feature gaps
---

Check ClaudeWarp for available improvements. Preliminary step: sync against Claude Code. Then scan Claude-Loops for implementable ideas.

## Phase 0 — Prerequisite: run claude-warp-sync

Invoke the `/claude-warp-sync` skill inline before doing anything else. Wait for it to complete and record its output — specifically `CC_VERSION` and any superseded components.

If claude-warp-sync fails, note the failure, record `CC_VERSION` as "unknown", and continue.

## Phase 1 — Get current state

1. Get the exact local time:
   ```bash
   date '+%Y-%m-%d %H:%M %Z'
   ```
   Record as `RUN_TS`.

2. Fetch the latest Claude-Loops commit SHA to record what version was checked:
   ```
   WebFetch https://api.github.com/repos/lucagattoni/Claude-Loops/commits/main?per_page=1
   ```
   Record the `sha` (short: first 7 chars) and `commit.author.date` as `LOOPS_COMMIT`.

3. Fetch the most recent news digest:
   ```
   WebFetch https://raw.githubusercontent.com/lucagattoni/Claude-Loops/main/LOOP_ENGINEERING_NEWS.md
   ```
   Read the last 2–3 run blocks to understand the most recent findings.

## Phase 2 — Read Claude-Loops index

Fetch the topic index:
```
WebFetch https://raw.githubusercontent.com/lucagattoni/Claude-Loops/main/LOOP_ENGINEERING.md
```
Build a complete list of all documented topics and their doc file paths.

For any topics that look new or substantively relevant, fetch the corresponding doc:
```
WebFetch https://raw.githubusercontent.com/lucagattoni/Claude-Loops/main/docs/<file>.md
```

Also read `LOOP_ENGINEERING_NEWS.md` for any recently added "new findings" that reference concepts not yet covered by an entry in the main index.

## Phase 3 — Inventory ClaudeWarp

Build a picture of what ClaudeWarp currently provides by fetching from GitHub:

1. Fetch the skills directory listing:
   ```
   WebFetch https://api.github.com/repos/lucagattoni/Claude-Warp/contents/skills
   ```
   For each skill directory, fetch its SKILL.md frontmatter (`name`, `description`):
   ```
   WebFetch https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/skills/<name>/SKILL.md
   ```

2. Fetch the templates directory listing:
   ```
   WebFetch https://api.github.com/repos/lucagattoni/Claude-Warp/contents/templates
   ```

3. Fetch `README.md` for stated scope and design principles:
   ```
   WebFetch https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/README.md
   ```

## Phase 4 — Gap analysis

Compare the Claude-Loops topic list against the ClaudeWarp inventory.

For each Claude-Loops topic, answer: **does ClaudeWarp have a skill, template, or documented pattern that covers this?**

Focus on topics that have a clear actionable artifact in ClaudeWarp (a new skill, a template addition, a CLAUDE.md section). Skip pure theory with no implementation surface.

Also check LOOP_ENGINEERING_NEWS.md findings — any Tier 1 or Tier 2 items that suggest a new pattern or tool worth implementing.

Key gaps to look for (but not limited to):

| Claude-Loops concept | Possible ClaudeWarp artifact |
|---|---|
| Loop Contract (TRIGGER/SCOPE/ACTION/BUDGET/STOP/REPORT) | Template or checklist embedded in `new-loop` skill or a standalone `loop-contract` skill |
| Anchor File Pattern (VISION.md/CLAUDE.md/AGENTS.md/PROMPT.md) | Template files + `new-loop` phase |
| Two-part harness (initializer agent + coding agent) | A `new-harness` or `loop-init` skill |
| Four-type loop taxonomy (heartbeat/cron/hook/goal) | Documentation in `new-loop` or a loop-type selector |
| Goal loop stop conditions | Guard script enhancement or validation step in `new-loop` |
| Cross-context-window state management | State file template or skill |
| git-based recovery (commit after each unit) | Phase in `new-loop` or a coding agent skill |
| Agent definitions in `.claude/agents/` | Skill or template for scaffolding agents |
| Cost control / budget caps in runner scripts | `run-headless.sh` template enhancement |
| Factory model (initializer → feature list → coding agent) | New skill |

Rate each gap: **High** (clearly actionable, directly improves loop reliability or correctness), **Medium** (useful extension, not urgent), or **Low** (nice-to-have, theoretical).

## Phase 5 — Write update report

Write findings to `CLAUDE_WARP_UPDATE_LOG.md` in the ClaudeWarp root (append; do not overwrite). Format:

```markdown
## <RUN_TS>

### claude-warp-sync output
<paste the claude-warp-sync summary — CC_VERSION, components checked, superseded>

### Claude-Loops last updated
<LOOPS_COMMIT sha> (<date>)

### Feature gaps

#### High priority
- **<concept>**: <one sentence on what to implement and where>
  Source: [<doc title>](docs/<file>.md)

#### Medium priority
- **<concept>**: <one sentence>

#### Low priority
- **<concept>**: <one sentence>

### No gap found
<list of Claude-Loops topics already covered by ClaudeWarp>

---
```

If a "High priority" item also maps to a superseded claude-warp-sync component, call that out explicitly — it means Claude Code now handles it natively and no new skill is needed.

## Phase 6 — Present summary to user

Print a concise report to the terminal (do not just point to the log file):

```
claude-warp-sync-research complete ✓

Claude Code version : <CC_VERSION>
Claude-Loops commit : <short hash> (<date>)

Feature gaps found  : <total>
  High priority     : <N>
  Medium priority   : <N>
  Low priority      : <N>

Top picks to implement:
  1. <concept> — <one sentence why this matters>
  2. <concept> — <one sentence>
  3. <concept> — <one sentence>

Full report: CLAUDE_WARP_UPDATE_LOG.md
```

Do NOT start implementing any of the gaps during this skill run. Surface the findings only — the user decides what to build next.
