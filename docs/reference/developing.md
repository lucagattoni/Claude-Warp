# Reference — Developing ClaudeWarp

How to work on the harness itself: the dev tool, the self-host model, writing per-PR verifiers, and
the external prior art ClaudeWarp credits. For the skill reference see [Skills](skills.md); for the
architecture see [Architecture](architecture.md).

---

## `scripts/dev.sh`

`scripts/dev.sh` is the developer tool for working on the harness itself (not installed into
consumer projects):

| Command | What it does |
|---|---|
| `scripts/dev.sh selfhost` | Symlinks every skill into `.claude/skills/` so they run as live `/claude-warp-*` commands **in this repo** (next session). Single source of truth — editing `skills/X` updates the live command; symlinks are gitignored so the repo stays a pure distribution source. |
| `scripts/dev.sh unhost` | Removes those symlinks. |
| `scripts/dev.sh verify` | Eight deterministic checks (no LLM, no tokens): source integrity, the setup-is-dynamic regression guard, the install copy contract, setup-template placeholder fill, docs coherence (every skill has a `### `/<skill>`` section in `docs/reference/skills.md` + a README row), the shared-executable self-tests (`verifier-lib.sh` + `ledger.sh` + `reviewer-guard.sh` each run their own `--self-test`), behavioural-claim count coherence (the `M/N` verified-live count is computed from the registry and asserted identical in `BEHAVIOURAL-CLAIMS.md` and `docs/reference/architecture.md`), and plugin-manifest version coherence (`.claude-plugin/plugin.json` version equals `VERSION` — the read-only release gate never edits it, so this pins it). Exits non-zero on failure — suitable for CI. |
| `scripts/dev.sh verify --live` | Additionally runs the real `/claude-warp-setup` (`claude -p`) into a throwaway repo for full fidelity. Costs tokens; opt-in. |

The non-`--live` `verify` runs in CI on every PR and on push to `main` (`.github/workflows/verify.yml`), so the eight deterministic checks gate merges automatically.

**Self-host safety.** Every skill is safe to run in this self-hosted repo (which has no
`harness-manifest.json`): the scaffolders (`new-loop`/`new-goal`/`new-harness`/`new-agent`)
skip manifest registration when it is absent (the artifact still works; `inventory` finds it by
scanning), `/claude-warp-sync` no-ops with "nothing to sync", and `/claude-warp-update`
**refuses** to run (it would overwrite the symlinks with GitHub copies — edit `skills/` directly
instead). So you can `/claude-warp-contract` a plan and let it scaffold here without
`--no-scaffold` if you actually want the artifacts.

**Scope of `verify`:** it checks source integrity and the install *copy contract* — it cannot
reproduce the LLM behaviour of `/claude-warp-setup` itself (that is non-deterministic). Use
`--live` when you need to exercise the actual setup skill end to end.

---

## Writing per-PR verifiers: `scripts/verifier-lib.sh`

Each implementation batch carries an independent verifier (kept gitignored in `working/`, e.g.
`working/pr7-verify.sh`) that asserts the change landed. These verifiers grep the changed files —
and grepping markdown is where they kept failing. The same **false-negative** bit four consecutive
PRs: a phrase the verifier *correctly* asserted was present, but raw `grep` missed it because
markdown had split or decorated the phrase — `**bold**` markers between words, an `inline code`
span, or a prose line **soft-wrapped** across two physical lines so the multi-word pattern never
matched on a single line. PRs that dodged it only did so by hand-anchoring asserts on short
single-line tokens, which is fragile.

`scripts/verifier-lib.sh` is the shared, tested fix. Source it from a verifier and use the matcher
that fits each assertion:

```bash
source scripts/verifier-lib.sh

chk "release skill exists"        "$(has   '^name: claude-warp-release' skills/claude-warp-release/SKILL.md)"  # structural → raw
chk "documents the no-target case" "$(md_has 'no existing target code'    skills/claude-warp-contract/SKILL.md)" # prose phrase → markdown-aware
```

- **`has <pat> <file>`** — the original raw `grep -qiE` idiom. Use it for structural or
  line-anchored patterns: `^name:`, a SemVer like `^0\.23\.0$`, JSON keys, exact tokens.
- **`md_has <pat> <file>`** — normalizes the file first (strips `` `inline code` ``, `**bold**`
  and `*italic*` asterisk markers **and `_italic_` underscore emphasis**, then joins soft-wrapped
  lines into one whitespace-collapsed stream) before matching. Use it for **prose phrases** that
  markdown may decorate or wrap. Underscore stripping is **boundary-aware** — only a complete
  `_word_` emphasis pair flanked by non-word chars is removed, so `snake_case` identifiers,
  leading-underscore names (`_phase`), and `__dunder__` / `mcp__tool__` runs all survive.
- **`not_has <pat> <file>`** — the **absence** assert (inverse of `has`): echoes `0` when the
  pattern is **absent**, `1` when present. Use it to prove a residual was removed, a placeholder
  filled, or a hint-stripped fixture carries no leak tags — instead of hand-rolling
  `[ "$(has …)" -ne 0 ] && echo 0 || echo 1`. ⚠ Unlike `has`/`md_has` it is **not fail-closed**: over
  a missing file grep finds nothing, so `not_has` reports absent-`0`. It answers *"is this gone?"*,
  not *"does the file exist and lack it?"* — when presence is what matters, use `has`/`md_has`.
- **`chk <label> <rc>`** — the assertion printer; all three matchers echo their exit code so they
  drop straight into `chk "label" "$(...)"`.

**Convention for new verifiers:** every new per-PR verifier should begin with
`source scripts/verifier-lib.sh` and use `md_has` for prose asserts / `has` for structural ones,
rather than redefining a raw-grep `has()`. **`working/pr7-verify.sh` is the reference template.**
(Per-PR verifiers are one-shot gates kept in gitignored `working/`; once a PR merges its scratch
is pruned, with `pr7` retained as the canonical example.)

**`_italic_` gap — closed (v0.28.1):** a phrase split by *underscore* emphasis (`the _alpha_ omega`)
is now reunited by `md_has` via boundary-aware stripping, after the gap had taxed verifier authors on
four consecutive PRs (each hand-anchoring tokens to dodge it). The `--self-test` now asserts the gap
is **closed** (md_has finds the split phrase; raw `has` still misses it) **and** that `snake_case`,
`_phase`, and `__dunder__` runs still survive — so the fix is regression-guarded, not just documented.
Residual edge: two *adjacent* emphasis spans (`_a_ _b_`) may strip only the first — rare in prose;
anchor on a single undecorated token with `has` if you ever hit it.

Both matchers **fail closed**: a match over a missing file yields a non-zero (no-match) result, so
a verifier can never read a NOT-RUN as a pass. The library proves all of this on itself:

```bash
bash scripts/verifier-lib.sh --self-test   # bold / soft-wrap / inline-code defects + the _italic_ known gap
```

The self-test plants each historical defect as a fixture and asserts `md_has` finds the phrase
**while raw `grep` misses it** — so it demonstrates both the fix and the defect it retires — plus a
known-gap pair asserting both matchers miss an `_italic_`-split phrase.

> The shared epistemic-honesty gate `scripts/check-ai-residuals.sh` is already markdown-aware in
> the other direction (it skips code-construct HIGH patterns for `.md`/`.markdown`/`.txt`, so quoted
> sample code in docs doesn't false-*positive*). `verifier-lib.sh` addresses the complementary
> false-*negative* class in the per-PR verifiers.

---

## Prior art and acknowledgements

Several of ClaudeWarp's design decisions were sharpened by studying mature open-source projects that
tackle the same problem — turning a fuzzy intent into a verifiable, closed loop. We adapt their ideas
**critically** (diverging where their assumptions don't hold for an agent-based, budget-governed infra
layer), and credit them here. The documentation structure itself follows the **Diátaxis** model
([Daniele Procida](https://diataxis.fr)) — a tutorial / how-to / reference / explanation split, adapted
critically: a small CLI tool does not need every quadrant heavily populated, so the beginner tutorial
([quickstart](../quickstart.md)) and the expert reference (this folder) carry most of the weight.

| Project | Author | Influenced |
|---|---|---|
| [**PAUL** — *Plan · Apply · Unify Loop*](https://github.com/ChristopherKahler/paul) | Christopher Kahler | Diagnostic failure routing on `--retry` (v0.26.0); per-task acceptance criteria (v0.18.0); the richer `done_with_concerns` / `needs_context` / `blocked` task-status enum |
| [**claude-code-harness** — *CCH TeamAgent Debate*](https://github.com/Chachamaru127/claude-code-harness) | Chachamaru127 | The AI-residuals epistemic-honesty scan (`scripts/check-ai-residuals.sh`); reconcile-and-re-ticket closure (`claude-warp-converge`); the severity→verdict gating honesty rider (v0.28.0); the red-team / Skeptic "try-to-break" reviewer charter + trivially-passing-AC check (v0.29.0) |
| [**idea-to-ship-skills**](https://github.com/nelsonwerd/idea-to-ship-skills) | nelsonwerd | The worth-it gate — `success_metric` + `kill_criterion` (contract Phase 1.5, v0.20.0); the epistemic-honesty rule-set ("NOT RUN ≠ pass", v0.17.0); the confidence-capped-by-verified-ratio honesty rider (v0.28.0) |
| [**devils-advocate**](https://github.com/brandonsimpson/devils-advocate) | brandonsimpson | The anti-fabrication rule ("'no blockers' is a valid result") and the "Unverified" set in verdict outputs — honesty riders (v0.28.0); the reasoning-blind reviewer gate — judge the artifact, not the author's defence (v0.29.0) |
| [**llm-council**](https://github.com/karpathy/llm-council) | Andrej Karpathy (→ `/council`) | The anonymized-author rider — blind author identity before ranking another agent's output to remove self-preference bias (v0.28.0); the single fresh-context reviewer pass (no debate loop) in the red-team checker (v0.29.0); the *unanimous ≠ independent* caution behind the same-family-corroboration label (v0.32.0) |
| [**agent-review-panel**](https://github.com/wan-huiyan/agent-review-panel) | wan-huiyan | The control-validation rule in the QA evaluator's red-team charter — *a check that can't fail proves nothing*: a passing `cmd:` must be confirmed to fail on a deliberately broken implementation (v0.29.0); read-only command-verification of checkable predicates (`[CMD_CONFIRMED]`/`[CMD_CONTRADICTED]`) + the static-inference-consensus caution (same-lines agreement ≠ corroboration) in the reproduction pass (v0.32.0) |
| [**/ultrareview**](https://www.shareuhack.com/en/posts/claude-code-pr-review-subagents-guide) | Anthropic (`/code-review ultra`) | Reproduction-required corroboration — a finding counts only if a second pass reproduces it; the `--corroborate` reproduce-before-block gate on the QA evaluator (v0.30.0) |
| [**adversarial-review**](https://github.com/alecnielsen/adversarial-review) · [(ng fork)](https://github.com/ng/adversarial-review) | alecnielsen · ng | Consensus-gating — a finding needs corroboration to count, a solo pass ≠ confirmed; the corroborated-vs-uncorroborated merge-gating PASS (v0.30.0) |
| [**adversarial-review**](https://github.com/robertoecf/adversarial-review) | robertoecf | Provenance tags (`[pass-N / model]` — agreement as N traceable data points, not headcount) and graceful-degradation-loud (a missing corroborator fails loud, never silently treated as corroborated) (v0.30.0) |
| [**adversarial-review**](https://github.com/dementev-dev/adversarial-review) | dementev-dev | The read-only-reviewer integrity guard (`scripts/reviewer-guard.sh`) — `git status --porcelain` + content-digest snapshot before/after a spawned review pass, hard-stop-loud on any mutation, proving the reviewer was truly read-only (v0.32.0) |
| [**Strive_Engineering**](https://github.com/krishddd/Strive_Engineering) | krishddd | Provenance-binding of cited git artifacts — re-checking a finding's cited commit/tag/blob against the object store (`git cat-file -e <sha>^{object}`, read-only) and tagging `[SHA_CONFIRMED]`/`[SHA_MISSING]` so a citation that names a non-existent object is rejected, not trusted (v0.33.0, claim #6) |
| [**Harness / "The RIG"**](https://github.com/grapheneaffiliate/Harness) | grapheneaffiliate | Convergent prior art for the provenance-binding tier — a model-agnostic self-verifying harness whose deterministic verification gates ground the same "re-check the cited artifact, don't trust the assertion" discipline (v0.33.0) |
| [**flywheel**](https://github.com/kok1eee/flywheel) | kok1eee | Convergent prior art for the provenance-binding tier — a sensors-first / harness-driven loop engine where checks read ground truth rather than a prior step's claim (v0.33.0) |
| [**spec-kit**](https://github.com/github/spec-kit) | GitHub | The standing project constitution (`.claudewarp/constitution.md`, v0.17.0); plan-vs-actual reconciliation (`/converge`, v0.19.0) |
| [**Diátaxis**](https://diataxis.fr) | Daniele Procida | The documentation framework — tutorial / how-to / reference / explanation — behind this docs restructure (quickstart + nested `reference/` + `guides/`, v0.34.3) |

Beyond the projects above, the command-verification discipline (v0.32.0) draws research grounding from
**NABAOS / "tool receipts"** ([arXiv 2603.10060](https://arxiv.org/abs/2603.10060)) — distinguishing what a
reviewer *observed* (a command's output) from what it *inferred* — and from the recall-vs-precision
**find/verify** framing of the /ultrareview ecosystem (pass-1 finds; pass-2 verifies by executing).

Where a specific mechanism is borrowed, the relevant skill or doc names its source inline (for
example, the `--retry` routing credits PAUL's `apply-phase.md`). ClaudeWarp's own framing —
the two-axis shape × risk (R0–R5) classification, budget governance, independent verifiers, and the
agent/fork execution model — is where it deliberately diverges from each of these.
