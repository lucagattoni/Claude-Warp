# Retrospectives

Produced by `/claude-warp-retro`. Read-only analysis — findings here are not auto-applied.

---

## Retro: honesty-riders (goal) — 2026-06-28

**Outcome:** ✅ COMPLETE — 9/9 done conditions met; verifier 24/24, `dev.sh verify` 6/6, residuals R2 clean (HIGH=0).
**Milestones:** 2 execution-log entries (contract+materialise → implement+verify) | rework: none — zero mid-build surprises.

### What worked
- **Phase-2 pre-draft source read paid off.** Reading all three seams (contract Phase 6 + 1.5, harness QA evaluator) *before* drafting meant the contract `action`/`scope` matched reality — no "already present / differently shaped" surprise mid-build. The mandatory-read rule earned its keep on a 3-file change.
- **Type-B routing stayed honest.** The one judgment call (tier-scoping) was surfaced as a `surface_condition` and resolved by the user before any code — not auto-picked. The feature itself encodes the same discipline (severity gating never auto-resolves a hidden Type-B).
- **Worth-it gate correctly skipped.** A concrete settled-scope change went straight to Phase 2; the gate did not tax it with a fuzzy-intent interview.
- **Verifier dodged the known md_has gap on purpose.** Assertions were hand-anchored on single-line tokens + snake_case (`approved_with_notes`) so the recurring `_italic_`/soft-wrap false-negative never fired. 24/24 first run.

### What failed / friction
- **The md_has italic/soft-wrap gap is now a recurring tax** (structural — 4th consecutive PR where the verifier author had to hand-anchor tokens to avoid a known false-negative: PR1 residuals, PR2 bold, PR3 soft-wrap, here pre-empted). It keeps working *because* the author remembers — a fragile guarantee.
- **The instruction-file verifier ceiling recurs** (structural — same note as the converge PR3 retro): the three edited files are LLM-instruction files, so the verifier can only assert each rider's instruction is *present*, not that the rider *behaves*. Re-flagged by hand each time instead of being a named, accepted limitation class.
- **Phase 1.5 rider framing is slightly miscoupled** (minor): the worth-it riders were documented under an "R2+" mental model, but Phase 1.5 runs *before* risk classification — so the R2+ label doesn't cleanly apply to the worth-it verdict (it applies to the post-classification surfaces). The implementation handles it correctly (fuzzy plans always get the riders), but the framing could mislead a future editor.

### Top 3 improvements
1. **`scripts/verifier-lib.sh` — close (or wrap) the `_italic_`/soft-wrap gap** — add an opt-in `md_has_loose` that also strips single-underscore emphasis when not snake_case-adjacent, so verifier authors stop hand-dodging a known defect that has now taxed 4 PRs. Carry the `--self-test` boundary case forward. (Recurring → fix the lib, dedicated PATCH.)
2. **`claude-warp-contract` Phase 6 — name the "instruction-file change" limitation class explicitly** — when a contract's targets are LLM-instruction files, the critical pass should state once that the verifier asserts *presence, not behaviour*, and record it in `decision_log` — so it's a known accepted ceiling, not rediscovered and re-noted every retro.
3. **`claude-warp-contract` Phase 1.5 — decouple the worth-it riders from the R2+ tier label** — clarify that the confidence-cap + Unverified riders apply to *every* worth-it verdict (fuzzy plans are inherently the high-uncertainty case), independent of the R0–R5 class that is only assigned later in Phase 3.

---

## Retro: improve-planning-skills (all goals/loops) — 2026-06-26

**Subject:** one completed **goal** (no recurring loops scaffolded in this repo).
**Period:** the goal's full lifecycle (3 commits: approve → items 2–4 → item 1).
**Outcome:** ✅ COMPLETE — 5/5 done conditions met; `scripts/dev.sh verify` green at every step.

### What worked
- **Vibe → checklist conversion.** "Improve the planning skills" had no checkable done
  condition; the contract's "help me define it" path turned it into 4 concrete, verifiable
  items elicited from observed deficiencies. The goal became gradable.
- **The `surface_condition` gate fired correctly.** Item #1 (artifact rename = external-contract
  change) was auto-detected as a human gate and routed for approval instead of being silently
  applied — maker/checker + human-in-the-loop working on the tool itself.
- **Scope discipline held.** Only `contract` + `new` + `docs/loop-harness.md` were touched, exactly
  the contract's `may_touch`. No drift.
- **Verifier caught regressions early.** `dev.sh verify` ran after each item; green throughout.

### What failed / friction
- **No execution failures.** The friction was structural, not operational: the tooling is
  **loop-centric and strains for one-shot goals.**
  - `/claude-warp-retro` Phase 1 expects a `<!-- state:` header; a doc-30 `GOAL.md` has none, so
    this retro had to adapt by hand.
  - The retro frame (`runs_total`, `consecutive_fails`, per-run verdicts) does not map to a
    one-shot goal that runs once to completion.

### Pattern (systemic)
This is the **second instance** of the same root cause in one session: ClaudeWarp's machinery is
loop-first, and goals are a bolted-on branch. We fixed one instance in v0.13.0 (contract goal-branch
coherence); the retro skill has the identical class of issue. Expect more loop-centric skills to
share it.

### Top 3 improvements
1. **`claude-warp-retro` Phase 1 — add a goal mode — why:** when the state file is a doc-30 `GOAL.md`
   (no loop state header), read done-conditions + execution log and report completion status, instead
   of assuming runs/verdicts. Same goal-vs-loop split just fixed in the contract command.
2. **`claude-warp-retro` Phase 1 — detect schema before reading — why:** don't assume a `<!-- state:`
   header exists; branch on loop-state-header vs goal-schema first, so the skill never silently
   misreads a goal.
3. **Cross-skill goal-coherence sweep — why:** audit the remaining loop-centric skills (retro,
   `inventory` Phase 5 reads state headers, any other) and generalize the goal/loop split once —
   this root cause has now recurred twice and will keep surfacing piecemeal otherwise.

---

## Retro: md-has-italic-gap (goal) — 2026-06-28

**Outcome:** COMPLETE — 9/9 done conditions met
**Milestones:** 2 execution-log entries | rework: none (one mid-build design refinement, caught before any code was applied — not a redo of shipped work)

### What worked
- **Phase-2 pre-draft source read paid off concretely.** Reading `scripts/verifier-lib.sh` in full before drafting surfaced the `_phase` corruption risk *before* writing the regex — the pre-compaction design was a single-sided underscore strip, which would have silently broken leading-underscore identifiers (`_phase`, used by contract drafts). Upgraded to a complete-`_word_`-pair match. The mandatory read is what made this a design refinement instead of a post-merge bug.
- **Two genuinely independent harnesses.** The independent verifier (`working/md-has-italic-gap-verify.sh`, 15/15) used fixtures *distinct* from the in-lib `--self-test`, so the change is asserted by two non-overlapping sets of inputs rather than the same literals twice.
- **The recurring tax is retired.** This batch closed the `md_has` `_italic_`/soft-wrap false-negative that the previous FOUR retros each logged as a top friction item. Verifier authors no longer need to hand-anchor assertions on single-line tokens to dodge it.
- **Boundary-aware fix is provably non-destructive.** Pair-matching (both delimiters flanked by non-word chars) means snake_case, `_phase`, and `__dunder__`/`mcp__` runs are preserved by construction — confirmed by regression asserts in both harnesses. Raw `has()` untouched.

### What failed / friction
- **A one-shot verifier that hard-pins a VERSION line is a latent false-positive.** (structural) The merged honesty-riders verifier asserted `VERSION==0.28.0`; the very next PATCH bumped to 0.28.1, so that verifier "failed" — not a regression (its 22 prose/rider asserts all still passed), purely a stale version pin. It briefly looked like my change broke an existing verifier. Resolved by reading the failure (only the pin line flipped), pruning the merged scratch per convention, and correcting the contract stop.check + GOAL done-condition that had referenced it.
- **Cross-PR coupling via stop.check.** (structural) The contract's stop.check chained a *prior* PR's one-shot verifier as a non-regression gate. That conflated "my prose change is non-regressive" (valid) with "a frozen version pin still holds" (guaranteed to break on the next release). Per-PR verifiers are one-shot gates, not cross-PR regression suites.

### Top 3 improvements
1. **verifier-lib doc / convention — version asserts in per-PR verifiers must target the version that PR ships, and are pruned at merge — why:** a verifier that pins a soon-to-change VERSION becomes a guaranteed false-positive on the next PATCH. State the rule next to the `pr7` reference template so future verifiers don't carry a stale pin forward.
2. **contract Phase 2 (stop.check design) — do not chain a prior PR's one-shot verifier as a non-regression gate — why:** non-regression should be proven by the library's own `--self-test` (which travels with the code) plus `dev.sh verify`, not by re-running a frozen scratch verifier whose assertions (version pins especially) are scoped to a different release. Couples PRs and produces misleading failures.
3. **contract Phase 9 (materialise) — when a goal's `may_touch` lists a gitignored `working/` verifier, note it is auto-pruned at merge — why:** the prune-at-merge lifecycle of scratch verifiers is convention-only; surfacing it in the contract would have pre-empted the mid-batch scramble to prune the stale honesty-riders verifier and fix its two back-references.

---

## Retro: red-team-checker (goal) — 2026-06-28

**Outcome:** COMPLETE — 9/9 done conditions met
**Milestones:** 2 execution-log entries | rework: none (one scoping fork resolved before drafting)

### What worked
- **The prior batch's fix paid off one batch later — dogfooded in anger.** v0.28.1 closed the `md_has` `_italic_`/soft-wrap gap; *this* verifier (`red-team-checker-verify.sh`, 31/31) asserted soft-wrapped prose (`a check that cannot fail proves nothing`, wrapped across physical lines) and asterisk-italic emphasis **directly**, with zero hand-anchoring on single-line tokens. The exact friction the last *four* retros logged is now gone — confirmed by use, not just by self-test. This is the clearest evidence yet that closing a tooling tax compounds: the next builder (here, the same loop one step later) simply doesn't pay it.
- **A delegated decision was resolved by re-reading the source, not by guessing.** The user answered the scoping question with "help me decide." Rather than default, I re-read analysis §6bis (lines 471–472) and found it *explicitly* states Options 1/2/2.5 apply to both seams — so "both reviewers" was the analysis-faithful reading all along, and the table's "one checker" was about *not adding a parallel checker* (Option 3), not a scope limit. The delegation became a research task with a definite answer.
- **Phase-2 pre-draft source read of both seams → zero mid-build surprises** (now a four-batch streak). Reading the contract Phase 6 checker + the new-harness QA evaluator/DOER-CHECKER before drafting placed each charter element correctly the first time and confirmed the v0.28.0 riders' exact location so they could be preserved verbatim.
- **Additive-not-rewrite was made a verifier assertion.** The verifier explicitly checks the v0.28.0 honesty riders still exist at both seams, so "I added the red-team charter without clobbering the riders" is proven, not asserted.

### What failed / friction
- **The accepted static-verifier ceiling held again.** (structural) The three edited files are LLM-instruction files, so the verifier proves each charter element is *present*, not that the red-team behaviour *fires*. The analysis's success_metric for Option 2 — "the R3+ checker produces ≥1 trivially-passing-AC or unverified-load-bearing-claim catch on a real contract" — is only confirmable in live dogfooding. This is the same ceiling logged for Option 1 and converge PR3; it is not a defect, but it means three consecutive instruction-only features now carry an unmeasured behavioural claim.
- **No second source-read for the "help me decide" answer was budgeted up front.** (minor) The scoping question was sent to the user before I had fully exploited the analysis; the answer ("both, per §6bis") was already determinable from the document. The question was still worth asking (blast-radius fork), but a tighter pass would have cited §6bis *in* the question rather than discovering it after.

### Top 3 improvements
1. **A live dogf/verification ledger entry per instruction-only feature — why:** three features (honesty riders, red-team charter, +converge) now assert behaviour that only live use can confirm. A standing "behavioural-claim backlog" (one ledger line: feature → the catch it predicts → unverified-until-dogfooded) would stop the unmeasured claims from silently accumulating, and give the next real R3+ contract a checklist of behaviours to watch the checker actually produce.
2. **contract Phase 4 (interview) — when a scoping question's answer is determinable from a cited source, cite it *in* the question — why:** the "one checker vs both" fork was answerable from analysis §6bis; surfacing that line inside the AskUserQuestion would have let the user ratify the analysis-faithful reading in one step instead of delegating. Ask with the evidence attached, not just the options.
3. **Option 2.5 (reproduction-required) is now the highest-value next build — why:** Options 1+2 have loaded the reviewers with disciplines but every one is same-model; the analysis flags the shared model-family blind spot as the remaining gap, and 2.5 (a finding must be reproduced before it blocks; a PASS must be corroborated) is the cheapest independence proxy that doesn't need cross-vendor wiring. The disciplines are in place — independence is the missing axis.

---
