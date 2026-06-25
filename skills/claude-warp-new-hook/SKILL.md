---
name: claude-warp-new-hook
description: Scaffold a Claude Code hook for loop control — verify-before-stop circuit breaker, destructive command blocking, or audit logging; writes the hook script and wires it into .claude/settings.json
---

Scaffold a hook for: `$ARGUMENTS`

If `$ARGUMENTS` is empty, stop and print:
`Usage: /claude-warp-new-hook "describe what the hook should do"`
Examples:
- `"verify-before-stop: block turn end until npm test passes"`
- `"block destructive commands: deny rm -rf and git push --force"`
- `"audit log: record all Bash tool calls to logs/audit.log"`

Hooks run deterministic shell scripts at defined lifecycle points — they are
not LLM judgments. Use them when a loop needs hard guarantees, not best-effort
behaviour. Phase 3b (Verify) uses LLM reasoning; a Stop hook uses exit codes.

## Phase 1 — Identify hook pattern

Parse `$ARGUMENTS` and determine which named pattern applies:

| Pattern | Hook event | Exit code 2 blocks | Use when |
|---|---|---|---|
| **verify-before-stop** | `Stop` | Turn end until check passes | Loop must not stop until a test/linter passes |
| **destructive-block** | `PreToolUse` | The tool call | Loop must never run certain commands unattended |
| **audit-log** | `PostToolUse` | Never (async) | Need a tamper-evident record of all tool calls |
| **subagent-chain** | `SubagentStop` | Never (async) | Trigger follow-on work when a background agent finishes |

Derive:
- `HOOK_PATTERN` — one of the four above
- `HOOK_SLUG` — kebab-case name (e.g. `verify-npm-test`, `block-destructive`, `audit-bash`)
- `CHECK_CMD` — the shell command to run (verify-before-stop and destructive-block only)
- `LOOP_SLUG` — the loop this hook belongs to (if scoped; blank = project-wide)

## Phase 2 — Write the hook script

Create `hooks/<HOOK_SLUG>.sh`.

### verify-before-stop

```bash
#!/usr/bin/env bash
# Hook: verify-before-stop for <HOOK_SLUG>
# Event: Stop — blocks turn end (exit 2) until <CHECK_CMD> passes.
# asyncRewake: true — Claude re-enters with failure output as context.
set -euo pipefail

OUTPUT=$(<CHECK_CMD> 2>&1) && EXIT=0 || EXIT=$?

if [ "$EXIT" -ne 0 ]; then
  # Exit 2 = blocking signal; Claude re-enters with additionalContext
  cat <<JSON
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "Verification failed. Fix the issues and stop again.\n\n${OUTPUT}"
  }
}
JSON
  exit 2
fi

# Exit 0 = allow Claude to stop
exit 0
```

### destructive-block

```bash
#!/usr/bin/env bash
# Hook: destructive-block for <HOOK_SLUG>
# Event: PreToolUse — denies matching Bash commands (exit 2).
# CRITICAL: exit 2 = deny (blocking). exit 1 = non-blocking warn (permits the action).
# Wrap all deny logic in this script so any unhandled error exits 2, not 1.
set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null || echo "")

# Add patterns to block; use grep -E for regex
if echo "$CMD" | grep -qE '<BLOCK_PATTERN>'; then
  cat <<JSON
{
  "continue": false,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny"
  }
}
JSON
  exit 2
fi

exit 0
```

### audit-log

```bash
#!/usr/bin/env bash
# Hook: audit-log for <HOOK_SLUG>
# Event: PostToolUse — async fire-and-forget; never blocks.
set -euo pipefail

mkdir -p logs
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")
TS=$(date '+%Y-%m-%d %H:%M:%S %Z')

echo "${TS} | ${TOOL} | $(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('tool_input',''))[:200])" 2>/dev/null)" >> logs/audit.log
exit 0
```

Create the directory and make executable:
```bash
mkdir -p hooks
chmod +x hooks/<HOOK_SLUG>.sh
```

## Phase 3 — Wire into .claude/settings.json

Read `.claude/settings.json`. If it does not exist, create it as `{}`.

Add the hook under `hooks`. Use `async: true` for audit-log and subagent-chain
patterns. Use `asyncRewake: true` only for verify-before-stop.

**verify-before-stop:**
```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": false,
        "asyncRewake": true
      }
    ]
  }
}
```

**destructive-block:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "if": "Bash",
        "async": false
      }
    ]
  }
}
```

**audit-log:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": true
      }
    ]
  }
}
```

Read the full existing `.claude/settings.json` as JSON, add the new hook entry
to the appropriate event array (creating the array if absent), then write the
whole file back. Never replace an existing hook array — always append to it.

## Phase 4 — Commit

```bash
mkdir -p hooks
git add hooks/<HOOK_SLUG>.sh .claude/settings.json
git commit -m "feat(hook): add <HOOK_SLUG> (<HOOK_PATTERN>)"
```

## Phase 5 — Report

```
Hook scaffolded ✓

  Pattern  : <HOOK_PATTERN>
  Script   : hooks/<HOOK_SLUG>.sh
  Event    : <HOOK_EVENT>
  Wired in : .claude/settings.json

<HOOK_PATTERN-specific note>
  verify-before-stop: Claude will re-enter with test output as context on
    each failure — fix the failures and stop again to pass the gate.
  destructive-block: matched commands will be denied before execution —
    adjust the BLOCK_PATTERN regex in the script as needed.
  audit-log: all tool calls appended to logs/audit.log asynchronously.

Safety note: exit code 2 = blocking deny. An unhandled exception that exits 1
accidentally permits the denied action. Wrap deny logic in try/catch or set -e.
```
