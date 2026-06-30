# Claude-Warp (ClaudeWarp) — Agent Instructions

ClaudeWarp is a **loop harness for Claude Code** — loop scaffolding, scheduling guards, headless runners, readiness gates, and a self-pruning mechanism that retires components as Claude Code absorbs them. It is intentionally thin: anything Claude Code already provides (subagents, worktrees, memory, code review, scheduling runtime) is *referenced, not reimplemented*. Read `README.md` and the docs site before working.

## Repository map

| Path | What it is |
|---|---|
| `skills/` · `templates/` | The harness skills and scaffolding templates |
| `scripts/` | Dev / verify tooling |
| `docs/` · `mkdocs.yml` · `site/` | Documentation (published via MkDocs) |
| `tests/` · `VERSION` · `CHANGELOG.md` · `plans/` | Tests, version, history, plans |

## Python: always uv

Use **uv** for everything Python — never `pip`, `venv`, `virtualenv`, or `poetry`. Local: `uv run`, `uv sync`, `uv venv`. CI: `astral-sh/setup-uv` (with caching), never `actions/setup-python` + `pip`. A single-tool `requirements-*.txt` consumed via `uv run --with-requirements` is acceptable (e.g. the docs build).

## Git workflow — PR only

- **Never commit to `main`.** Every change goes on its own branch with a PR; the permission classifier enforces this.
- **Seeds / dogfood / follow-up artifacts ride in a PR**, never a direct-to-`main` chore. Prefer gitignoring pure runtime data (e.g. a ledger) over committing it.
- **Delete merged branches:** `gh pr merge <n> --squash --delete-branch`, then `git branch -d <branch>` locally; `git fetch --prune` to drop stale refs.
- **Always pull before changing anything.**

## Releases

After each implementation batch, cut a versioned release before declaring work done: promote `CHANGELOG.md` → bump `VERSION` → annotated git tag → `git push origin --tags` → `gh release create` with notes. Follow the global SemVer rule for bump levels.

## External-source update workflow

When asked to "scan GitHub / external sources for X": **scan → filter for ClaudeWarp relevance internally → implement all relevant gaps autonomously (pre/post review per gap, commit each gap separately) → cut a release.** Do not stop to report scan findings; only ask the user when human input is genuinely required.

## Docs & attribution

- **Update docs in the same change.** Any new/changed skill, template, script, or capability updates the relevant docs (README skills/docs tables, the reference/architecture docs under `docs/`) and `CHANGELOG.md` in the same batch — docs are part of "done." Run the repo's `verify` check (see `scripts/` and `.github/workflows/verify.yml`) before marking work complete.
- **Link, don't copy.** Reference external docs/repos/pages with a link; explain the concept concisely in your own words so it's clear *without* clicking; never paste large verbatim blocks. Reserve inline quotes for short, load-bearing phrases.
- **Credit external sources.** When work adapts or borrows from an external project, credit it by **full name + author + link**, mapped to exactly what it influenced (a "Prior art & acknowledgements" section). Adapt critically — state where their assumptions don't transfer.

## Interaction defaults

Cross-project working defaults — think critically about proposals (don't just implement), give honest pros/cons when asking the user to choose, let the user have the last word, and inspect git state (`git status` / `git reflog`) before any corrective `git reset` — live in the global `~/.claude/CLAUDE.md`.
