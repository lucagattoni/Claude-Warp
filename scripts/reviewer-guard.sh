#!/usr/bin/env bash
# reviewer-guard.sh — prove a spawned reviewer pass was READ-ONLY.
#
# Why: ClaudeWarp's `verified-live` dogfoods *assert* the spawned reviewer only reads the artifact +
# repo, but never *enforce* it — a reviewer that quietly edits the tree would invalidate the evidence
# without anyone noticing. This guard snapshots the working tree before a review dispatch and re-checks
# it after; ANY tracked-file mutation, new untracked file, or deletion fails the guard LOUD.
#
# Adapted critically from dementev-dev/adversarial-review (https://github.com/dementev-dev/adversarial-review)
# — its `git status --porcelain` + sha256 before/after snapshot with a hard-stop on mutation. We diverge
# by digesting tracked CONTENT (`git diff HEAD`) as well as the path set, so a content change to an
# already-dirty file is caught too, and by ignoring the gitignored `working/` scratch area.
#
# Usage:
#   eval "$(scripts/reviewer-guard.sh snapshot)"     # captures REVIEWER_GUARD_DIGEST into the env
#   …spawn the reasoning-blind reviewer pass…
#   scripts/reviewer-guard.sh verify "$REVIEWER_GUARD_DIGEST"   # exit 0 read-only, 3 = MUTATED (loud)
# or, file-based:
#   scripts/reviewer-guard.sh snapshot --file .rg.state   # writes the digest to a file
#   scripts/reviewer-guard.sh verify  --file .rg.state    # compares against it
#
#   scripts/reviewer-guard.sh --self-test    # prove the guard fires (read-only passes, mutation fails)
#
# Exit codes: 0 = unchanged (read-only). 3 = tree MUTATED (integrity violation). 2 = usage/error.

set -u

_sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi; }

# rg_digest <repo_dir> — one hash over: the porcelain path-set + tracked content vs HEAD + untracked
# file contents. The gitignored working/ scratch area is excluded (reviewers may legitimately write there).
rg_digest() {
  local d="$1"
  git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "NOT-A-GIT-REPO"; return 0; }
  {
    git -C "$d" -c core.quotepath=false status --porcelain=v1 -- . ':!working' 2>/dev/null
    git -C "$d" diff HEAD -- . ':!working' 2>/dev/null
    # untracked, non-ignored files: hash their contents so a brand-new file changes the digest
    git -C "$d" ls-files --others --exclude-standard -- . ':!working' 2>/dev/null | sort | while read -r f; do
      [ -f "$d/$f" ] && printf '%s:' "$f" && _sha < "$d/$f"
    done
  } | _sha
}

cmd="${1:-}"; shift || true
REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
FILE=""
if [ "${1:-}" = "--file" ]; then FILE="${2:-}"; fi

case "$cmd" in
  snapshot)
    dig="$(rg_digest "$REPO")"
    if [ -n "$FILE" ]; then printf '%s\n' "$dig" > "$FILE"; echo "reviewer-guard: snapshot → $FILE"
    else echo "REVIEWER_GUARD_DIGEST=$dig; export REVIEWER_GUARD_DIGEST"; fi
    ;;
  verify)
    local_expected=""
    if [ -n "$FILE" ]; then local_expected="$(cat "$FILE" 2>/dev/null)"; else local_expected="${1:-}"; fi
    [ -n "$local_expected" ] || { echo "reviewer-guard: no baseline digest given" >&2; exit 2; }
    now="$(rg_digest "$REPO")"
    if [ "$now" = "$local_expected" ]; then
      echo "reviewer-guard: PASS — tree unchanged (reviewer was read-only)"; exit 0
    else
      echo "reviewer-guard: FAIL — tree MUTATED during the review (integrity violation)" >&2
      git -C "$REPO" status --porcelain=v1 -- . ':!working' >&2
      exit 3
    fi
    ;;
  --self-test|self-test)
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    git -C "$tmp" init -q && git -C "$tmp" config user.email t@t && git -C "$tmp" config user.name t
    printf 'alpha\n' > "$tmp/a.txt"; git -C "$tmp" add -A && git -C "$tmp" commit -qm init
    PASS=1
    base="$(rg_digest "$tmp")"
    # (1) no change → digest stable
    [ "$(rg_digest "$tmp")" = "$base" ] && echo "ok   read-only leaves digest stable" || { echo "FAIL stable"; PASS=0; }
    # (2) modify a tracked file → digest changes (mutation caught)
    printf 'alpha-EDITED\n' > "$tmp/a.txt"
    [ "$(rg_digest "$tmp")" != "$base" ] && echo "ok   tracked-file edit changes digest" || { echo "FAIL edit"; PASS=0; }
    # (3) revert → digest returns to baseline
    printf 'alpha\n' > "$tmp/a.txt"
    [ "$(rg_digest "$tmp")" = "$base" ] && echo "ok   revert restores digest" || { echo "FAIL revert"; PASS=0; }
    # (4) a NEW untracked file → digest changes (a reviewer writing a file is caught)
    printf 'new\n' > "$tmp/b.txt"
    [ "$(rg_digest "$tmp")" != "$base" ] && echo "ok   new untracked file changes digest" || { echo "FAIL untracked"; PASS=0; }
    rm -f "$tmp/b.txt"
    # (5) a write under working/ is IGNORED (scratch area is allowed)
    mkdir -p "$tmp/working"; printf 'scratch\n' > "$tmp/working/scratch.txt"
    [ "$(rg_digest "$tmp")" = "$base" ] && echo "ok   working/ scratch write is ignored" || { echo "FAIL working-ignored"; PASS=0; }
    if [ "$PASS" -eq 1 ]; then echo "reviewer-guard self-test: PASS"; exit 0; else echo "reviewer-guard self-test: FAIL"; exit 1; fi
    ;;
  -h|--help|"")
    grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)
    echo "reviewer-guard: unknown command '$cmd' (snapshot|verify|--self-test)" >&2; exit 2 ;;
esac
