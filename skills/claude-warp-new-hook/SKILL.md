---
name: claude-warp-new-hook
description: Scaffold a Claude Code hook — 8 named patterns: verify-before-stop, destructive-block, audit-log, subagent-chain, security-scan, evidence-gate, kill-switch, steer; writes script and wires into .claude/settings.json
---

Scaffold a hook for: `$ARGUMENTS`

If `$ARGUMENTS` is empty, stop and print:
`Usage: /claude-warp-new-hook "describe what the hook should do"`
Examples:
- `"verify-before-stop: block turn end until npm test passes"`
- `"block destructive commands: deny rm -rf and git push --force"`
- `"audit log: record all Bash tool calls to logs/audit.log"`
- `"security scan: check for hardcoded secrets and --no-verify bypasses"`
- `"evidence gate: block state file writes unless a matching Read happened first"`
- `"kill switch: block all tool calls when AGENT_STOP file exists"`
- `"steer: inject STEER.md content as context once, then clear it"`

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
| **security-scan** | `PostToolUse` | Never (async) | Detect hardcoded secrets, `--no-verify` bypasses, broad `rm -rf` |
| **evidence-gate** | `PreToolUse` | Write/Edit to state file if no prior Read | Prevent false-positive completions: agent cannot write results it hasn't read |
| **kill-switch** | `PreToolUse` | All tool calls when `AGENT_STOP` file exists | Operator mid-run halt without killing the process |
| **steer** | `UserPromptSubmit` | Never (context injection) | Mid-run redirection: surfaces `STEER.md` once as context, then clears file |

Derive:
- `HOOK_PATTERN` — one of the eight above
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

### security-scan

```bash
#!/usr/bin/env bash
# Hook: security-scan for <HOOK_SLUG>
# Event: PostToolUse — async; never blocks; logs findings to logs/security-scan.log.
# Detects: hardcoded secrets (API keys, tokens), --no-verify bypasses, broad destructive
# patterns (rm -rf /, DROP TABLE without WHERE, push --force to main).
set -euo pipefail

mkdir -p logs
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")
CONTENT=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('tool_input','')))" 2>/dev/null || echo "")
TS=$(date '+%Y-%m-%d %H:%M:%S %Z')
FOUND=0

# Secret patterns: adjust regex to your project's key formats
if echo "$CONTENT" | grep -qE '(sk-[a-zA-Z0-9]{32,}|ghp_[a-zA-Z0-9]{36}|AKIA[A-Z0-9]{16}|eyJhbGciO[a-zA-Z0-9_-]{20,})'; then
  echo "${TS} | SECURITY | WARN | possible hardcoded secret in ${TOOL} output" >> logs/security-scan.log
  FOUND=1
fi

# Bypass detection
if echo "$CONTENT" | grep -qE '(--no-verify|--force-with-lease|--allow-unrelated-histories|git push.*--force)'; then
  echo "${TS} | SECURITY | WARN | git safety bypass detected in ${TOOL}: $(echo "$CONTENT" | grep -oE '(--no-verify|--force[^ ]*)')" >> logs/security-scan.log
  FOUND=1
fi

# Broad destructive patterns
if echo "$CONTENT" | grep -qE '(rm -rf /[^/]|DROP TABLE [^W]|DELETE FROM [^ ]+ *;)'; then
  echo "${TS} | SECURITY | WARN | potentially unsafe destructive pattern in ${TOOL}" >> logs/security-scan.log
  FOUND=1
fi

if [ "$FOUND" -eq 1 ]; then
  echo "${TS} | SECURITY | review logs/security-scan.log for flagged items" >> logs/security-scan.log
fi

exit 0
```

### evidence-gate

```bash
#!/usr/bin/env bash
# Hook: evidence-gate for <HOOK_SLUG>
# Event: PreToolUse — blocks Write/Edit to <STATE_FILE> unless a Read of that
# file has been recorded in the session transcript. Prevents false-positive
# completions where the agent writes a pass verdict without reading state first.
# CRITICAL: exit 2 = deny. exit 1 = warn only (accidentally permits).
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
TARGET=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# Only gate writes to the state file
STATE_FILE="<STATE_FILE>"
if [[ "$TOOL" =~ ^(Write|Edit)$ ]] && [[ "$TARGET" == *"$STATE_FILE"* ]]; then
  # Check session read log (append Read events via audit-log or companion PostToolUse hook)
  if ! grep -q "Read.*$STATE_FILE" logs/session-reads.log 2>/dev/null; then
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
fi

exit 0
```

### kill-switch

```bash
#!/usr/bin/env bash
# Hook: kill-switch
# Event: PreToolUse — blocks ALL tool calls when AGENT_STOP file exists.
# To halt a running loop: touch AGENT_STOP  (remove it to resume: rm AGENT_STOP)
# CRITICAL: exit 2 = deny. exit 1 = warn only (accidentally permits).
set -euo pipefail

if [ -f "AGENT_STOP" ]; then
  REASON=$(cat AGENT_STOP 2>/dev/null | head -1 || echo "operator halt")
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

### steer

```bash
#!/usr/bin/env bash
# Hook: steer
# Event: UserPromptSubmit — if STEER.md exists, prepend its content as additional
# context and delete the file so it only fires once.
set -euo pipefail

if [ -f "STEER.md" ]; then
  CONTENT=$(cat STEER.md)
  rm -f STEER.md
  cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Operator steering note (read once, then cleared):\n\n${CONTENT}"
  }
}
JSON
fi

exit 0
```

Create the directory and make executable:
```bash
mkdir -p hooks
chmod +x hooks/<HOOK_SLUG>.sh
```

## Phase 3 — Wire into .claude/settings.json

Read `.claude/settings.json`. If it does not exist, create it as `{}`.

Add the hook under `hooks`. Use `async: true` for audit-log, subagent-chain, and
security-scan patterns. Use `asyncRewake: true` only for verify-before-stop.

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

**security-scan:**
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

**evidence-gate / kill-switch:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": false
      }
    ]
  }
}
```

**steer:**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": false
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
