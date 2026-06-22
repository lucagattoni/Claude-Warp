---
name: new-agent
description: Scaffold a specialized subagent definition in .claude/agents/ — sets name, description, model, tools, and persona from a one-line role description
---

Scaffold a new subagent definition for the role: `$ARGUMENTS`

## Phase 1 — Understand the role

Parse `$ARGUMENTS` as a plain-English role description.
Derive from it:
- `AGENT_NAME` — kebab-case identifier (e.g. `security-reviewer`)
- `AGENT_DISPLAY` — human-readable name (e.g. "Security Reviewer")
- `AGENT_DESCRIPTION` — one sentence: what this agent does and when to use it
- `AGENT_MODEL` — choose based on role:
  - Routine review / summarisation → `claude-sonnet-4-6`
  - Deep analysis, security, complex reasoning → `claude-opus-4-8`
  - Fast lookups, classification → `claude-haiku-4-5-20251001`
- `AGENT_TOOLS` — minimum tool set for the role (e.g. `Read,Grep,Glob,Bash` for
  a code reviewer; `Read,WebFetch` for a research agent)
- `AGENT_PERSONA` — 2–4 sentences describing the agent's expertise, focus, and
  what it should and should not do

Get local time:
```bash
date '+%Y-%m-%d %H:%M %Z'
```

## Phase 2 — Create agent file

Write `.claude/agents/<AGENT_NAME>.md`:

```markdown
---
name: <AGENT_NAME>
description: <AGENT_DESCRIPTION>
model: <AGENT_MODEL>
tools: <AGENT_TOOLS>
---

<AGENT_PERSONA>
```

Key rules for the persona:
- State what the agent is expert at
- State what it should flag or produce
- State what it must NOT do (e.g. "Do not fix code — only report findings")
- End with the output format (e.g. "Report each finding as: file:line — description")

## Phase 3 — Register in manifest

Read `harness-manifest.json` (if present). Append to an `agents` array (create
it if absent):
```json
{
  "name": "<AGENT_NAME>",
  "role": "<AGENT_DESCRIPTION>",
  "model": "<AGENT_MODEL>",
  "created_at": "<LOCAL_TIMESTAMP>"
}
```
Write back.

## Phase 4 — Commit

```bash
git add .claude/agents/<AGENT_NAME>.md harness-manifest.json
git commit -m "feat(agent): scaffold <AGENT_NAME>"
```

## Phase 5 — Report

```
Agent scaffolded ✓

  File  : .claude/agents/<AGENT_NAME>.md
  Model : <AGENT_MODEL>
  Tools : <AGENT_TOOLS>

To invoke from a parent loop or skill:
  Use the Agent tool with subagent_type: "<AGENT_NAME>"
  — or reference it in a skill step:
  "Use a subagent to <role>. Report only <output format>."

To invoke from a parent loop in headless mode:
  Pass the agent name in your skill's Agent tool call.
```
