# retro multi-run fixture

`/claude-warp-retro` had only ever been exercised against a loop with a **single** run. Every
N>1 code path — verdict distribution, the last-10 window, trend analysis, sibling-loop
contamination — was unexercised. This fixture closes that gap.

## Build it (zero tokens, pure shell + git)

```bash
bash tests/dogfood/retro-multirun/build.sh /tmp/retro-fixture
```

Produces a repo with **12 runs** of mixed verdicts (`pass` ×5, `fail` ×3, `skip`, `handoff`,
`timeout`, `stopped`), real dated git history, a **sibling loop** (`OTHER_LOOP_LOG.md`) for the
pathspec-contamination case, and a gitignored `logs/…-20260807.log` recording a guard-fired skip
that appears in **neither** the state file nor git history.

## Run the retro against it

```bash
cp -R /tmp/retro-fixture /tmp/retro-run
mkdir -p /tmp/retro-run/.claude/skills/claude-warp-retro
cp skills/claude-warp-retro/SKILL.md /tmp/retro-run/.claude/skills/claude-warp-retro/
cd /tmp/retro-run && claude --permission-mode auto --permission-prompts none --max-turns 40 \
  --allowedTools "Read,Write,Edit,Bash,Glob,Grep" -p "/claude-warp-retro retro-fixture-loop"
```

## Score it

`ANSWER_KEY.md` is the oracle. The five assertions that matter:

| # | Assertion | Defect it exercises |
|---|---|---|
| A1 | The `Runs:` line's buckets **sum to its own stated total** | verdict vocabulary missing `timeout`/`stopped` |
| A2 | The `stopped` run (2026-08-01) is named, distinct from the plain `fail` runs | same |
| A3 | The guard question is answered from `logs/` evidence, or explicitly "not observable" | a guard-fired skip writes neither state nor commit |
| A4 | **No** `other-loop` activity is attributed to `retro-fixture-loop` | pathspec union |
| A5 | The window is runs **#3–#12**, not #1–#10 | append-only file read top-down returns the oldest |

`OBSERVED-RETRO-20260906.md` is the output of the first passing run (all 5/5), kept as the
reference for what a correct multi-run retrospective looks like.
