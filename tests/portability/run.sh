#!/usr/bin/env bash
# Portability suite for the ClaudeWarp runner templates.
#
# WHY THIS EXISTS: the runners branch on what the environment provides — `timeout` (absent on stock
# macOS, present on Linux), `python3` (absent on a slim container), where `claude` lives. Those
# branches had only ever executed on one machine. This fills a template, stubs `claude`, and asserts
# the OBSERVED exit codes in whatever environment it is run in, so the same file is the macOS test
# and the Linux test.
#
# Usage:
#   bash tests/portability/run.sh              # run here (host)
#   bash tests/portability/run.sh --docker     # also run inside debian, with and without python3
#
# Every exit status is captured BARE, never through a pipe: a pipeline reports its LAST stage's
# status, which has silently inverted results in this repo more than once.
set -uo pipefail
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)}"

build_fixture() {  # build_fixture <dir>
  local d="$1"
  mkdir -p "$d/repo/scripts" "$d/repo/logs" "$d/repo/.claude/skills/probe" "$d/home/.local/bin"
  printf 'x\n' > "$d/repo/.claude/skills/probe/SKILL.md"
  local t
  for t in run-headless run-fanout; do
    sed -e 's|{{SKILL_NAME}}|probe|g' -e 's|{{SKILL_SLUG}}|probe|g' -e 's|{{MAX_TURNS}}|3|g' \
        -e 's|{{MAX_BUDGET_USD}}|1.00|g' -e 's|{{EFFORT}}|high|g' -e 's|{{ALLOWED_TOOLS}}|Read|g' \
        -e 's|{{DISALLOWED_TOOLS}}|Bash(rm -rf *)|g' -e "s|{{TASK_LIST_COMMAND}}|printf 'a\\\\nb\\\\nc'|g" \
        -e 's|{{TASK_PROMPT_PREFIX}}|Do|g' \
        "$REPO_ROOT/templates/$t.sh.tpl" > "$d/repo/scripts/$t.sh"
  done
  sed -e 's|{{SKILL_NAME}}|probe|g' -e 's|{{STATE_FILE}}|PROBE_LOG.md|g' \
      "$REPO_ROOT/templates/guard.sh.tpl" > "$d/repo/scripts/guard.sh"
  # a state file whose last run HANDED OFF — the day must stay open for a retry
  printf '# probe\n\n<!-- state:\nlast_run: %s 10:00 UTC\nlast_verdict: handoff\n-->\n\n## %s — handoff\n' \
    "$(date '+%Y-%m-%d')" "$(date '+%Y-%m-%d')" > "$d/repo/PROBE_LOG.md"
  printf '#!/bin/bash\ncase "$1" in\n  --help) echo "  --permission-prompts <target>";;\n  agents) echo "[]";;\n  --bg) echo "backgrounded · deadbeef";;\n  stop) :;;\n  *) echo STUB-OK;;\nesac\n' > "$d/home/.local/bin/claude"
  chmod +x "$d/home/.local/bin/claude"
  grep -q '{{' "$d/repo/scripts/run-headless.sh" && { echo "fixture has unfilled placeholders"; return 1; }
  return 0
}

run_suite() {  # run_suite <dir>
  local d="$1" pass=0 fail=0 rc out
  cd "$d/repo" || return 1
  export HOME="$d/home"; PATH="$HOME/.local/bin:$PATH"; export PATH
  git init -q . 2>/dev/null
  git -c user.email=a@b -c user.name=a add -A >/dev/null 2>&1
  git -c user.email=a@b -c user.name=a commit -q -m init >/dev/null 2>&1
  mkdir -p "$d/alt" "$d/emptyhome"
  echo "env: bash=${BASH_VERSION}  timeout=$(command -v timeout || echo ABSENT)  python3=$(command -v python3 || echo ABSENT)"
  chk() { if [ "$2" = "$3" ]; then echo "  PASS $1 ($2)"; pass=$((pass+1)); else echo "  FAIL $1: got '$2' want '$3'"; fail=$((fail+1)); fi; }

  rc=0; bash scripts/run-headless.sh --max-minutes 1 >/dev/null 2>&1 || rc=$?
  chk "headless runs clean" "$rc" "0"

  # The wall-clock cap must either be ENFORCED or LOUDLY declared unenforced — never silently absent.
  if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
    grep -q 'cap is NOT enforced' logs/probe-*.log 2>/dev/null && chk "timeout present: no NOTIFY" "notify" "none" || chk "timeout present: no NOTIFY" "none" "none"
  else
    grep -q 'cap is NOT enforced' logs/probe-*.log 2>/dev/null && chk "timeout absent: NOTIFY fires" "notify" "notify" || chk "timeout absent: NOTIFY fires" "none" "notify"
  fi

  rc=0; ( HOME="$d/emptyhome" PATH=/usr/bin:/bin bash scripts/run-headless.sh --max-minutes 1 >/dev/null 2>&1 ) || rc=$?
  chk "missing claude -> 127" "$rc" "127"

  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo "Unknown command: /probe"; exit 0;; esac\n' > "$d/alt/claude"; chmod +x "$d/alt/claude"
  rm -f logs/*.log; rc=0; CLAUDE_BIN="$d/alt/claude" bash scripts/run-headless.sh --max-minutes 1 >/dev/null 2>&1 || rc=$?
  chk "unknown-command -> 4" "$rc" "4"

  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo "Error: Exceeded USD budget (0.25)"; exit 1;; esac\n' > "$d/alt/claude"
  rm -f logs/*.log; rc=0; CLAUDE_BIN="$d/alt/claude" bash scripts/run-headless.sh --max-minutes 1 >/dev/null 2>&1 || rc=$?
  chk "budget -> 6 (a cap, not transient)" "$rc" "6"
  chk "budget: exactly one attempt" "$(grep -c 'Starting probe' logs/probe-*.log 2>/dev/null)" "1"

  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo OVERRIDE;; esac\n' > "$d/alt/claude"
  rm -f logs/*.log; CLAUDE_BIN="$d/alt/claude" bash scripts/run-headless.sh --max-minutes 1 >/dev/null 2>&1
  rc=0; grep -q OVERRIDE logs/probe-*.log 2>/dev/null || rc=1
  chk "CLAUDE_BIN outranks a native install" "$rc" "0"

  if command -v python3 >/dev/null 2>&1; then
    out=$(bash scripts/run-fanout.sh --max-minutes 1 2>&1)
    chk "fanout counts an unterminated last task" "$(printf '%s' "$out" | grep -oE 'Tasks generated: [0-9]+' | grep -oE '[0-9]+')" "3"
    chk "fanout launches all 3" "$(printf '%s' "$out" | grep -c 'Launching: ')" "3"
  else
    rc=0; bash scripts/run-fanout.sh --max-minutes 1 >/dev/null 2>&1 || rc=$?
    chk "fanout FATALs without python3" "$rc" "127"
  fi

  rc=0; bash scripts/guard.sh >/dev/null 2>&1 || rc=$?
  chk "guard reopens the day after a handoff" "$rc" "0"

  echo "RESULT pass=$pass fail=$fail"
  [ "$fail" -eq 0 ]
}

# Internal entry point used by the docker variants: build a fixture and run the suite in <dir>.
# Invoked as a subcommand rather than sourced, so the container needs nothing but this one file.
if [ "${1:-}" = "__suite" ]; then
  build_fixture "$2" || exit 1
  run_suite "$2"
  exit $?
fi

main() {
  local status=0 d
  d="$(mktemp -d)"
  echo "=== host ($(uname -s)) ==="
  build_fixture "$d" && run_suite "$d" || status=1
  rm -rf "$d"
  if [ "${1:-}" = "--docker" ]; then
    command -v docker >/dev/null 2>&1 || { echo "=== docker: not installed, skipping ==="; return "$status"; }
    docker info >/dev/null 2>&1 || { echo "=== docker: daemon down, skipping ==="; return "$status"; }
    local dd; dd="$(mktemp -d)"
    cp "$SCRIPT_PATH" "$dd/run.sh"; mkdir -p "$dd/templates"; cp "$REPO_ROOT"/templates/*.tpl "$dd/templates/"
    local variant pkgs label
    for variant in "git python3|with python3" "git|without python3"; do
      pkgs="${variant%%|*}"; label="${variant##*|}"
      echo "=== docker debian ($label) ==="
      docker run --rm -v "$dd:/w" -w /w debian:stable-slim bash -lc \
        "apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq $pkgs >/dev/null 2>&1; \
         REPO_ROOT=/w bash /w/run.sh __suite /w/fixture" || status=1
      rm -rf "$dd/fixture"
    done
    rm -rf "$dd"
  fi
  return "$status"
}
main "${1:-}"
