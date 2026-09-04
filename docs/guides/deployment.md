# Guide — Deployment posture

Before scheduling a loop unattended, choose how much it's allowed to do without a human.
This is separate from *what* the loop does — it's the safety boundary around it. ClaudeWarp's
autonomy levels (`L1`/`L2`/`L3`, assigned by `/claude-warp-new-loop` and `/claude-warp-contract`)
map to three deployment patterns:

| Autonomy | Deployment pattern | How to run it |
|---|---|---|
| **L1** report-only | **Approval-First** | Run interactively or with `--permission-mode plan`; the loop proposes, you approve. No unattended writes. For a headless read-only loop, `--restricted` (v2.1.248+) is the strictest fence: it removes Bash and the other code-running tools plus WebFetch, keeps file tools inside the working directory, and ignores user/project/local settings files — so hooks configured there don't load either (only managed settings and `--settings` still apply); use it for report-only work that needs no gate. |
| **L2** assisted | **Curated Allow-list + hard deny** | `--permission-mode auto --permission-prompts none` with an `--allowedTools` list, a `--disallowedTools` deny for the destructive set, and a `destructive-block` hook; safe non-production paths only. |
| **L3** unattended | **Sandboxed Full-Auto** | Everything in L2, run in an isolated environment (container, dedicated OS user, or worktree) with network/filesystem limits — never full-auto directly on production. Fence reads as well as writes: `"permissions": {"blockReadsOutsideWorkingDirectories": true}` (v2.1.257+) makes the file tools refuse reads outside the working directories in every mode. |

Two control layers enforce this: **in-process** controls (hooks, `--permission-mode`,
allowed/disallowed tools — see [`/claude-warp-new-hook`](../reference/skills.md)) and **out-of-process** controls
(the OS user, container, or network boundary the loop runs inside). L3 loops need both. Full detail:
Claude-Loops [§2.3 Harness vs Environment Engineering](https://lucagattoni.github.io/Claude-Loops/24-harness-patterns/).

## Fail-closed by construction

Every runner ClaudeWarp scaffolds passes the same three permission flags to `claude -p`, and they
do three different jobs:

| Flag | What it does | What it does **not** do |
|---|---|---|
| `--permission-mode auto` | A classifier model approves routine tool calls so the loop isn't stuck on prompts | Guarantee safety — Anthropic's own docs say so |
| `--permission-prompts none` (v2.1.259+) | Anything the classifier would have **asked a human** about is denied automatically — nobody is at the terminal | Change what auto mode itself decides |
| `--disallowedTools "…"` | A **hard deny** that holds even under auto mode | — |

Two things the flags above are often assumed to do, and don't:

- **`--allowedTools` is not a deny-list.** It pre-approves; under auto mode the classifier can still
  approve a tool the list never named. Claude-Loops' own two-stage pipeline learned this in
  production — its search stage ran the entire integrate stage (KB writes, a release, a push)
  inside itself with `Bash` and `git` absent from `--allowedTools`, and a strongly-worded prose
  "stop here" did not prevent the recurrence; `--disallowedTools` did
  ([Headless Mode → a skill can't tell interactive from headless](https://lucagattoni.github.io/Claude-Loops/09-headless-mode/)).
  ClaudeWarp's two-stage runner carries that deny on its search stage, plus a zero-cost wrapper
  check that skips the integrate stage if its commit already landed.
- **`--dangerously-skip-permissions` is the opposite of unattended-safe.** It fails *open*: a prompt
  becomes a yes. `--permission-prompts none` fails *closed*: a prompt becomes a no, the run
  surfaces it in the log, and the runner's safe-to-retry guard decides what happens next.

**Put the mode on the command line, not in the repo.** Since v2.1.207 (`auto`) and v2.1.257
(`bypassPermissions`), a `defaultMode` in `.claude/settings.json` / `.claude/settings.local.json`
is ignored — repo-resident settings can no longer grant themselves elevated trust (the same
release train moved `sandbox.ripgrep` out of project settings, v2.1.232). A loop that relied on a
committed `"defaultMode": "auto"` now silently starts in Manual mode, where an unattended `-p` run
has nobody to answer its prompts. The scaffolded runners pass `--permission-mode` explicitly for
exactly this reason. The runners probe `claude --help` once and omit `--permission-prompts` on a
CLI older than v2.1.259, so a scaffold still runs there — with the pre-v2.1.259 prompt behaviour.

---

**Next:** [schedule it](scheduling.md) · [monitor it once it's running](monitoring.md).
