---
name: claude-warp-update
description: Pull the latest ClaudeWarp skills from GitHub into this project's .claude/skills/ and update harness-manifest.json
---

Update the ClaudeWarp skills installed in this project to the latest version from
the ClaudeWarp GitHub repo.

## Phase 0 — Refuse in a self-hosted source repo

If `.claude/skills/` entries are **symlinks** into a sibling `skills/` directory, this is the
ClaudeWarp **source repo** self-hosted via `scripts/dev.sh selfhost` — not a consumer install.
**Stop immediately** and print:
`self-hosted source repo — do not run update here. It would overwrite the symlinks (and your
local source edits) with GitHub copies. Edit skills/ directly; the symlinks are already live.`

```bash
# detect: first .claude/skills entry is a symlink AND a sibling skills/ exists
[ -d skills ] && [ -L "$(ls -d .claude/skills/*/ 2>/dev/null | head -1 | sed 's:/$::')" ] && echo SELF_HOST
```

Otherwise continue.

## Phase 1 — Get current state

1. Get local time:
   ```bash
   date '+%Y-%m-%d %H:%M %Z'
   ```

2. Read `harness-manifest.json` if present — get current top-level `version` (treat as "unknown"
   if there is no manifest). **Note the schema:** `harness` is the *string* `"ClaudeWarp"`, and
   `version` / `last_update` are its top-level **siblings**, not fields under it. Writing
   `harness.version` would replace the identity string with an object.

3. List skills currently installed in this project:
   ```bash
   ls .claude/skills/
   ```
   Record as `INSTALLED_SKILLS`.

## Phase 2 — Fetch skill list from GitHub

**Fetch with `curl`, not `WebFetch`.** Phase 3 requires a *byte* diff ("not LLM judgment"), and
`WebFetch` passes content through a summarising model — a contract it cannot satisfy. Use Bash:

```bash
REPO="lucagattoni/Claude-Warp"
RAW="https://raw.githubusercontent.com/$REPO/main"
LIST="$(curl -fsSL "https://api.github.com/repos/$REPO/contents/skills" 2>/dev/null)" || LIST=""
```

**Validate before trusting it.** Unauthenticated `api.github.com` is rate-limited to 60 requests
per hour and answers with **403** (bad credentials give 401) and a JSON *object* describing the
error. `curl -f` already turns those into a non-zero exit and an empty `LIST`, but the validation
below is what makes the failure *safe* rather than merely likely: any body that is not a JSON
**array** — an error object, truncated output, or an unexpected schema — parses without error and
contains no `type: "dir"` entries, and treating it as the remote list marks every installed skill
an orphan:

```bash
REMOTE_SKILLS="$(printf '%s' "$LIST" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
if not isinstance(d,list): sys.exit(1)          # an error object, not a listing
print('\n'.join(e['name'] for e in d if e.get('type')=='dir'))
" 2>/dev/null)" || REMOTE_SKILLS=""
```

If `REMOTE_SKILLS` is empty: **stop the whole skill**, change nothing, and print
`could not reach GitHub (rate limit, network, or unexpected response) — nothing changed`.
An empty remote list is never a reason to touch a local file.

Then the released version:

```bash
REMOTE_VERSION="$(curl -fsSL "$RAW/CHANGELOG.md" 2>/dev/null \
  | grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | tr -d '## []')"
```
If `REMOTE_VERSION` is empty, keep going but record it as `unknown` — do **not** stamp the
manifest with an empty value.

## Phase 3 — Compare

For each skill in `INSTALLED_SKILLS`:

```bash
BODY="$(curl -fsSL "$RAW/skills/<name>/SKILL.md" 2>/dev/null)" || BODY=""
```

Mark it **fetch-failed** — and do **NOT** overwrite the local copy — when any of these hold:
- `curl` failed (network error, 404, 5xx: `-f` makes those non-zero), **or**
- the body is empty, **or**
- the body does not begin with `---` and contain a `name:` line.

That last condition is not paranoia: a 200 response with an empty or truncated body matches
neither "fetch failed" nor "HTTP error", so without it the body "differs" from the local file, is
marked *update available*, and Phase 4 replaces a working skill with nothing.

Otherwise compare byte-for-byte with the local `.claude/skills/<name>/SKILL.md`
(`diff -q`, not LLM judgment):
- differs → **update available**
- identical → up to date
- not present in `REMOTE_SKILLS` → **orphan** (removed upstream)

For each skill in `REMOTE_SKILLS` not in `INSTALLED_SKILLS`: fetch its `SKILL.md` by the same
rule above and, if it passes, mark it **new skill available**. (A skill cannot be installed in
Phase 4 without having been fetched here first.)

## Phase 4 — Apply updates

For each skill marked **update available**: overwrite the local copy with the
fetched remote content.

For each skill marked **new skill available**: install it:
```bash
mkdir -p .claude/skills/<name>
```
Write the fetched SKILL.md content to `.claude/skills/<name>/SKILL.md`.

For each skill marked **orphan**: do NOT delete — report it and let the user decide.

## Phase 5 — Update manifest

If `harness-manifest.json` is **absent** (a hand-installed project): skip this phase and say so in
the report. Do not create one — `/claude-warp-setup` owns that file's shape.

If present, update the two **top-level** fields (see the schema note in Phase 1):
- `version` → `REMOTE_VERSION` (skip if it came back `unknown`)
- `last_update` → current local timestamp

Stamp `last_update` on **every completed check**, including one that found nothing to update —
its meaning is "when did we last verify against the remote", which is exactly the fact a no-op run
establishes. Leaving it null after a successful check makes a working install look like it has
never been checked.

Write it back.

## Phase 6 — Commit

```bash
git add .claude/skills/
if [ -f harness-manifest.json ]; then git add harness-manifest.json; fi
git commit -m "chore(claude-warp-update): sync skills to ClaudeWarp v<REMOTE_VERSION>"
```

Add the two paths in **separate** `git add` calls. The combined form
`git add .claude/skills/ harness-manifest.json` is atomic: in a project without a manifest it
fails with `fatal: pathspec 'harness-manifest.json' did not match any files`, exits 128, and
stages **nothing** — so a run that had already rewritten skill files on disk loses the entire
commit. (Reproduced.)

Use an `if` rather than `[ -f … ] && …` for the second add: the AND-list returns 1 when the
manifest is absent, which would abort a `set -e` script on its last statement.

If no skill changed but the manifest was stamped, commit the manifest alone. If nothing changed at
all, print "ClaudeWarp skills are up to date — no changes." and skip the commit.

## Phase 7 — Report

```
claude-warp-update complete ✓

Remote      : https://github.com/lucagattoni/Claude-Warp
Version     : <LOCAL_VERSION> → <REMOTE_VERSION>

Skills updated  : <N>  (<names>)
Skills added    : <M>  (<names>)
Orphans found   : <K>  (<names — no action taken, review manually>)
```
