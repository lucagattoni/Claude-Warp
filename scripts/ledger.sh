#!/usr/bin/env bash
# ledger.sh — persistent cross-session closure ledger for ClaudeWarp.
#
# A chronological, append-only log of CLOSURE events across sessions — what shipped, what was
# surfaced for a human, what a converge pass reconciled. It is NOT the memory system (semantic
# facts/preferences) and NOT native cross-run loop state — it is the "what happened, in order,
# queryable" half of closure (COMPETITIVE-FINDINGS gap #3).
#
# Storage: .claudewarp/ledger.jsonl — one JSON object per line, append-only. JSON-lines (not a
# markdown SUMMARY) so `query` filters on structured fields and never has to grep markdown — the
# false-negative class verifier-lib.sh exists to avoid. Append-only is git-merge-friendly and
# mirrors converge's ethos (never rewrite history, only add).
#
# Self-host safe (constitution P4): no .claudewarp/ ⇒ `record` creates it; `query` on a missing or
# empty ledger prints "(ledger empty)" and exits 0 — never errors, never needs a manifest.
#
# Usage:
#   scripts/ledger.sh record --kind <goal|loop|harness> --slug <slug> --event <event> \
#                            [--version X.Y.Z] [--verdict <verdict>] [--surfaced "<text>"] \
#                            [--note "<text>"]
#   scripts/ledger.sh query  [--kind K] [--slug S] [--event E] [--since YYYY-MM-DD] [--raw]
#   scripts/ledger.sh --self-test
#
# `event` is free text but the intended vocabulary is: shipped | surfaced | converged | parked |
# blocked. `query` with no filters renders the whole ledger as a table (newest last); --raw emits
# the matching jsonl lines verbatim (for piping to jq).

set -u
LEDGER="${CLAUDEWARP_LEDGER:-.claudewarp/ledger.jsonl}"

# json_escape <string> — minimal JSON string escaping (backslash, quote, tab, newline→space).
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g' | tr '\n' ' '
}

# field <jsonl-line> <key> — extract a top-level string field's value (best-effort, no jq dep).
field() {
  printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p"
}

cmd_record() {
  local kind="" slug="" event="" version="" verdict="" surfaced="" note=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --kind) kind="$2"; shift 2 ;;
      --slug) slug="$2"; shift 2 ;;
      --event) event="$2"; shift 2 ;;
      --version) version="$2"; shift 2 ;;
      --verdict) verdict="$2"; shift 2 ;;
      --surfaced) surfaced="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      *) echo "ledger record: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [ -z "$kind" ] || [ -z "$slug" ] || [ -z "$event" ]; then
    echo "ledger record: --kind, --slug and --event are required" >&2; return 2
  fi
  mkdir -p "$(dirname "$LEDGER")"
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"ts":"%s","kind":"%s","slug":"%s","event":"%s","version":"%s","verdict":"%s","surfaced":"%s","note":"%s"}\n' \
    "$ts" "$(json_escape "$kind")" "$(json_escape "$slug")" "$(json_escape "$event")" \
    "$(json_escape "$version")" "$(json_escape "$verdict")" "$(json_escape "$surfaced")" \
    "$(json_escape "$note")" >> "$LEDGER"
  echo "ledger: recorded $event for $kind/$slug${version:+ v$version}"
}

cmd_query() {
  local f_kind="" f_slug="" f_event="" f_since="" raw=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --kind) f_kind="$2"; shift 2 ;;
      --slug) f_slug="$2"; shift 2 ;;
      --event) f_event="$2"; shift 2 ;;
      --since) f_since="$2"; shift 2 ;;
      --raw) raw=1; shift ;;
      *) echo "ledger query: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [ ! -s "$LEDGER" ]; then echo "(ledger empty)"; return 0; fi

  local matched=0 out=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ -n "$f_kind" ]  && [ "$(field "$line" kind)"  != "$f_kind" ]  && continue
    [ -n "$f_slug" ]  && [ "$(field "$line" slug)"  != "$f_slug" ]  && continue
    [ -n "$f_event" ] && [ "$(field "$line" event)" != "$f_event" ] && continue
    if [ -n "$f_since" ]; then
      # lexical compare works on ISO-8601 timestamps; compare date prefix.
      [ "$(field "$line" ts)" \< "$f_since" ] && continue
    fi
    matched=$((matched + 1))
    if [ "$raw" -eq 1 ]; then
      out="${out}${line}"$'\n'
    else
      out="${out}$(printf '%-20s  %-8s  %-22s  %-10s  %-8s  %s' \
        "$(field "$line" ts)" "$(field "$line" kind)" "$(field "$line" slug)" \
        "$(field "$line" event)" "$(field "$line" version)" "$(field "$line" note)")"$'\n'
    fi
  done < "$LEDGER"

  if [ "$matched" -eq 0 ]; then echo "(no matching entries)"; return 0; fi
  if [ "$raw" -eq 1 ]; then printf '%s' "$out"; else
    printf '%-20s  %-8s  %-22s  %-10s  %-8s  %s\n' "TS" "KIND" "SLUG" "EVENT" "VERSION" "NOTE"
    printf '%s' "$out"
  fi
}

self_test() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  local PASS=1
  chk() { if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; PASS=0; fi; }
  export CLAUDEWARP_LEDGER="$tmp/sub/ledger.jsonl"   # note: sub/ does NOT exist yet (self-init test)

  # 1. query on a MISSING ledger is empty + exit 0 (self-host safe, never errors).
  out="$("$0" query 2>&1)"; rc=$?
  chk "query on missing ledger exits 0"   "$rc"
  chk "query on missing ledger says empty" "$([ "$out" = "(ledger empty)" ] && echo 0 || echo 1)"

  # 2. record self-initializes the dir + appends.
  "$0" record --kind goal --slug alpha --event shipped --version 1.0.0 --note "first" >/dev/null 2>&1
  chk "record self-creates the ledger dir" "$([ -f "$CLAUDEWARP_LEDGER" ] && echo 0 || echo 1)"
  chk "ledger now has exactly 1 line"      "$([ "$(wc -l < "$CLAUDEWARP_LEDGER")" -eq 1 ] && echo 0 || echo 1)"

  # 3. append-only: a second record adds a line, never rewrites the first.
  "$0" record --kind harness --slug beta --event surfaced --note "needs review" >/dev/null 2>&1
  chk "second record appends (2 lines)"    "$([ "$(wc -l < "$CLAUDEWARP_LEDGER")" -eq 2 ] && echo 0 || echo 1)"
  chk "first line preserved byte-for-byte" "$(head -1 "$CLAUDEWARP_LEDGER" | grep -q '"slug":"alpha"' && echo 0 || echo 1)"

  # 4. query round-trip: the recorded entry comes back.
  chk "query renders the shipped entry"    "$("$0" query --slug alpha | grep -q 'alpha' && echo 0 || echo 1)"
  chk "query --kind filters correctly"     "$([ "$("$0" query --kind harness --raw | grep -c .)" -eq 1 ] && echo 0 || echo 1)"
  chk "query --event filters correctly"    "$("$0" query --event surfaced | grep -q 'beta' && echo 0 || echo 1)"
  chk "filter with no matches is graceful" "$("$0" query --slug nonesuch | grep -q 'no matching' && echo 0 || echo 1)"

  # 5. required-args validation fails closed.
  "$0" record --kind goal --slug x >/dev/null 2>&1
  chk "record without --event fails (rc 2)" "$([ "$?" -eq 2 ] && echo 0 || echo 1)"

  # 6. injection safety: a quote/newline in --note doesn't break the JSON line count.
  "$0" record --kind goal --slug gamma --event shipped --note 'has "quotes" and
newline' >/dev/null 2>&1
  chk "quoted/newline note stays one line"  "$([ "$(wc -l < "$CLAUDEWARP_LEDGER")" -eq 3 ] && echo 0 || echo 1)"

  if [ "$PASS" -eq 1 ]; then echo "ledger self-test: PASS"; return 0
  else echo "ledger self-test: FAIL"; return 1; fi
}

case "${1:-}" in
  record) shift; cmd_record "$@" ;;
  query)  shift; cmd_query "$@" ;;
  --self-test) self_test ;;
  -h|--help|"") grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "ledger: unknown command '$1' (use record | query | --self-test)" >&2; exit 2 ;;
esac
