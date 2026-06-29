---
name: claude-warp-sync-research
description: Developer tool — runs claude-warp-sync first, then scans Claude-Loops for patterns and concepts not yet implemented in ClaudeWarp; surfaces prioritised feature gaps
---

Check ClaudeWarp for available improvements. Preliminary step: sync against Claude Code. Then scan Claude-Loops for implementable ideas.

## Phase 0 — Prerequisite: run claude-warp-sync

Invoke the `/claude-warp-sync` skill inline before doing anything else. Wait for it to complete and record its output — specifically `CC_VERSION` and any superseded components.

If claude-warp-sync fails, note the failure, record `CC_VERSION` as "unknown", and continue.

## Phase 1 — Get current state

**Completeness rule (the point of this skill).** Every run must account for *every*
Claude-Loops change since the last recorded sync — never just the latest run(s). The last
sync's commit SHA is the lower bound, the current `main` HEAD is the upper bound, and the
GitHub compare between them is the authoritative change set. Scoping by "the last few run
blocks" is a defect: a multi-day gap spans several runs and several doc edits, and any one
of them can carry a Tier-1 finding.

1. Get the exact local time:
   ```bash
   date '+%Y-%m-%d %H:%M %Z'
   ```
   Record as `RUN_TS`.

2. **Establish the last-sync baseline.** Read `CLAUDE_WARP_UPDATE_LOG.md` (gitignored, repo
   root). Find the **most recent prior run block** — the one with the latest timestamp,
   which may *not* be the topmost entry (the log is appended but not strictly sorted, so
   scan every `## <timestamp>` header and pick the newest date). From its
   `### Claude-Loops last updated` line take the short SHA → `LAST_SYNCED_SHA`, and the
   block's timestamp → `LAST_SYNC_TS`. If the log is absent or has no prior run block,
   leave `LAST_SYNCED_SHA` empty (first-ever sync → full index scan) and note it.

3. Fetch the current Claude-Loops HEAD to set the upper bound:
   ```
   WebFetch https://api.github.com/repos/lucagattoni/Claude-Loops/commits/main?per_page=1
   ```
   Record the `sha` (short: first 7 chars) and `commit.author.date` as `LOOPS_COMMIT`.

4. **Enumerate the full delta since the last sync — the authoritative change set.** If
   `LAST_SYNCED_SHA` is set, fetch the compare:
   ```
   WebFetch https://api.github.com/repos/lucagattoni/Claude-Loops/compare/<LAST_SYNCED_SHA>...<LOOPS_COMMIT>
   ```
   Record **every** commit subject and **every** file under `docs/` added or modified across
   the range. This list — not a count of recent runs — is what Phases 2–4 must cover. If
   `LAST_SYNCED_SHA` is empty (first run), skip the compare and treat the whole index as the
   change set.

5. Fetch the news digest:
   ```
   WebFetch https://raw.githubusercontent.com/lucagattoni/Claude-Loops/main/LOOP_ENGINEERING_NEWS.md
   ```
   Read **every** run block dated after `LAST_SYNC_TS` (not a fixed number of blocks), and
   cross-check them against the Phase-1 compare commit list so no run in the window is missed.

## Phase 2 — Read Claude-Loops index

Fetch the topic index:
```
WebFetch https://raw.githubusercontent.com/lucagattoni/Claude-Loops/main/LOOP_ENGINEERING.md
```
Build a complete list of all documented topics and their doc file paths.

Fetch **every** `docs/` file flagged added or modified in the Phase-1 compare delta, plus
any index topic that looks new or substantively relevant:
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

Your input set is the **full delta from Phase 1** — every doc changed and every news run
block since `LAST_SYNCED_SHA` / `LAST_SYNC_TS`, not just the latest run. Work the whole set.

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

### Sync window
<LAST_SYNCED_SHA>..<LOOPS_COMMIT short sha> — <N> commits, <M> docs changed
(first-ever sync: full index scan, no prior baseline)

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

Implementing now (High + Medium):
  1. <concept>
  2. <concept>
  ...

Full report: CLAUDE_WARP_UPDATE_LOG.md
```

## Phase 7 — Implement findings autonomously

Implement **all High and Medium priority gaps** without stopping to ask, unless:
- The implementation requires credentials, external accounts, or platform-specific configuration the user must supply
- Two gaps directly contradict each other (pick the simpler one and note the conflict)
- A gap requires a product-scope decision that cannot be defaulted (e.g. breaking API change)

For everything else, make the reasonable call and proceed.

### Implementation order

Before starting: scan all gaps as a group for interactions. If two gaps would
modify the same file in conflicting ways, implement the higher-priority one first
and let it constrain the second. Note interactions in the implementation log.

Work through High items first, then Medium. For each gap, apply the
**pre → implement → post** review loop:

**PRE-REVIEW** — four checks, ordered by cost; a failing check stops and skips
this gap (record the reason in the implementation log):

1. **Overlap audit** (cheapest — one file read): Read the most relevant existing
   skill or template. Does any phase already partially cover this? If yes, extend
   that artifact; don't create a parallel one.

2. **Scope declaration** (zero cost — forces clarity before design): State the
   exact files to create or edit. If the list exceeds 3 new files for one gap,
   the scope is too large — split or cut. You must be able to name the files
   before writing a single line.

3. **Devil's advocate** (argues against the *specific* thing scoped in step 2):
   Produce the strongest case for *not* building it:
   - Can a ClaudeWarp user name a concrete scenario where this implementation
     makes their loop more reliable or correct? If no concrete scenario exists,
     the gap is theoretical — skip it.
   - Does the source doc describe a ClaudeWarp-applicable pattern, or advice
     for an unrelated context (enterprise fleet, Slack bots, specific CI vendor)?
   - Is there a workaround so trivial that the cost of a new skill exceeds the
     benefit?
   If none of these objections land, you have a clear rationale — proceed.
   If any objection stands, skip and record why.

4. **Convention fit** (cheap now, expensive later): Verify the planned artifact
   matches existing patterns: naming (`claude-warp-*`), phase numbering,
   frontmatter schema, placeholder style (`{{UPPER_SNAKE}}`), commit format.
   Open one similar existing skill as the reference before writing.

**IMPLEMENT** — write/edit the files; follow all existing ClaudeWarp conventions:
- Skills live in `skills/<name>/SKILL.md` with frontmatter (`name`, `description`)
- Templates live in `templates/` with `.tpl` extension
- Docs live in `docs/`; update `docs/reference/skills.md` for any new skills or templates
- Update `README.md` Skills table if a new skill is added

**POST-REVIEW** — five checks, ordered most-impactful-first; fix before committing:

1. **User journey trace** (the primary quality gate): Walk through every phase as
   if executing it right now from a clean project state. For each phase: what
   exact input does the agent receive? What command or file operation runs? What
   is the expected output? Can the phase be completed without unstated assumptions?
   A phase an LLM cannot follow reliably is a bug even if the prose looks fine.
   Finally, compare the traced outcome with the source doc intent: does the
   implementation capture the core insight described in the Claude-Loops doc,
   or only a surface-level interpretation of it?

2. **Regression check** (prevents breaking existing functionality): For every
   existing skill or template that is related to or references the changed area,
   verify it still works correctly:
   - Template changes: grep for all skills that fill this template's placeholders;
     confirm every `{{PLACEHOLDER}}` is still covered
   - Skill changes: verify no other skill's phase sequence depends on the old behaviour
   - Doc changes: verify all cross-links resolve correctly

3. **Devil's advocate on coverage** (finds what the journey trace misses):
   What would a skeptical reviewer reject?
   - Edge cases: empty `$ARGUMENTS`, no git repo, project with unusual structure?
   - Phases that ask the LLM to infer something non-obvious without guidance?
   - Done conditions that could be trivially satisfied without real work?
   Address every objection that cannot be dismissed.

4. **Reference audit** (systematic, not impressionistic — grep, don't rely on
   memory): In one pass, check: `docs/reference/skills.md` documents the new skill
   or template; `README.md` Skills table is updated if a new skill was added;
   `CHANGELOG.md` has an `[Unreleased]` entry; no file still describes the old
   behaviour using old names.

5. **Fresh reader pass** (last — catches what focused checks miss): Re-read
   every file created or edited as if arriving in a new session with no context.
   Does it make sense standalone? Is any jargon or implied knowledge left
   unexplained?

Fix every issue found, then commit.

**COMMIT** each gap as a separate commit after post-review passes:
`feat(<slug>): <what and why in one line>`

**Update CHANGELOG.md `[Unreleased]`** — add an entry for each gap implemented.

After all gaps are implemented, **cut a release** following the global versioning rule
(MINOR if any new skill or capability added; PATCH if fixes/docs only).

### Low priority gaps

Skip Low priority items — surface them in the report for the user to decide.

### After implementation

Append a `### Implementation` section to the current run block in `CLAUDE_WARP_UPDATE_LOG.md`:

```markdown
### Implementation
- ✅ <gap name> — <one sentence on what was built>
- ✅ <gap name> — ...
- ⏭ <gap name> — skipped (Low priority)
- ⚠ <gap name> — needs user input: <what is needed>
```
