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

## Retro: reproduction-required (goal) — 2026-06-28

**Outcome:** COMPLETE — 10/10 done conditions met
**Milestones:** 2 execution-log entries | rework: none (one threshold fork resolved autonomously before drafting)

### What worked
- **The previous retro's #3 recommendation was executed next, closing the analysis sequence.** The red-team-checker retro named Option 2.5 as "the highest-value next build"; this batch built exactly that. Options 1 → 2 → 2.5 of the multi-lens-review recommended sequence are now all shipped (v0.28.0 → v0.29.0 → v0.30.0) — the retro→next-build pipeline is working as intended, not drifting.
- **The verifier failed *first*, and the fix was verified-before-loosening.** 8 of 46 asserts FAILed on the initial run — all from a regex double-space trap (a `.` wildcard adjacent to a literal space matches two spaces, but `md_normalize` emits single spaces). Critically, I did **not** just loosen the patterns to make them pass: I ran each corrected pattern against the real file to confirm the content was genuinely present (rc 0) *before* editing the verifier. The fail-closed discipline caught my pattern bugs, and epistemic honesty (P6) kept the fix from becoming verifier theater — the asserts pass because the content is there, not because the patterns were watered down.
- **The b.5 model-diversity upgrade rode in as graceful degradation, not a hard dependency.** `CLAUDEWARP_QA_MODEL` defaults to a different in-house model but falls back to same-model cleanly — the reproduction pass still filters non-reproducible findings without it. Independence is layered, not all-or-nothing, exactly as Decision 3 framed it.
- **md_has dogfooded a third batch running.** The verifier asserts soft-wrapped and `**`/`(paren)`-decorated prose directly (`approved (corroborated)`, `N traceable data points, not headcount` across wraps) — the v0.28.1 fix continues to pay rent with zero hand-anchoring.
- **The threshold fork was resolved autonomously with a recorded rationale.** "auto-on at R2+ vs R3+" was a real cost fork (~2× on the common tier); I resolved it to R3+ auto / R2 opt-in on the prototype-grade-shouldn't-tax-the-common-path basis and logged it in `decision_log`, honoring "iterate autonomously, ask only if needed" without a round-trip.

### What failed / friction
- **The static-verifier ceiling is now FOUR-for-four — the behavioural-claim backlog (recommended last retro) was not built, and is now overdue.** (structural, recurring) honesty-riders, red-team-charter, converge, and now reproduction-required all ship an instruction-level mechanism the verifier proves *present*, not *executing*. The previous retro's #1 improvement ("a behavioural-claim backlog / live-dogfood ledger") was the right call and went unbuilt — so the unmeasured-claim debt grew by one more feature this batch. Recommending an improvement is not implementing it.
- **The md_has double-space regex trap cost 8 false-FAILs on first run.** (occurred 8×, first time logged as a distinct pattern) Verifier authors keep writing `'word. word'` (dot-then-space) expecting "word + decorated-gap + word", but against single-space-normalized text the `.` eats the space and the literal space doubles it. This is a *new, nameable* authoring tax — distinct from the soft-wrap gap md_has already fixed — and it will recur for every future verifier until the idiom is documented or given a helper.

### Top 3 improvements
1. **Build the behavioural-claim backlog now — it has been recommended twice and is the only honest way to discharge the static-verifier ceiling — why:** four consecutive features assert behaviour only live use can confirm; a standing ledger (feature → predicted catch → unverified-until-dogfooded) is cheap, and a single live `--corroborate`/red-team dogfood run on a real R3 contract would convert several of these claims from "present" to "fires." The disciplines are fully built; the missing work is *evidence they work*, not more disciplines.
2. **Add a `phrase` matcher (or a documented idiom) to `scripts/verifier-lib.sh` — why:** the double-space trap bit 8 asserts this batch and will bite every future verifier. A `phrase <words> <file>` helper that matches a word sequence tolerant of any run of whitespace/markdown punctuation between words (or a one-line note in the lib header: "don't put `.` next to a literal space — use `.*` or a plain space") would retire the tax the same way md_has retired the soft-wrap tax.
3. **The cheap-disciplines track is now exhausted — the next step is a genuine fork for the user, not an obvious continuation — why:** Options 1/2/2.5 (all S–M, ride existing seams) are shipped. What remains is either (a) *validate* via live dogfooding (improvement #1) or (b) the held Options 3 (review panel — needs `--review-panel`/fork/worktree plumbing) and 4 (deep-dive plan mode), both heavier and both flagged "hold" in the analysis. There is no longer a clearly-correct autonomous next build; surface the choice with the dogfooding-first recommendation.

---

## Retro: behavioural-claim-backlog (goal) — 2026-06-28

**Outcome:** COMPLETE — 9/9 done conditions met
**Milestones:** 2 execution-log entries (contract → implement) | rework: none

### What worked
- **The dogfood actually fired.** The in-context red-team pass on the planted-defect fixture produced the predicted catch (the `stop.check: "true"` trivial pass), plus the load-bearing-claim and R2 independent-verifier rows — converting the v0.29.0 charter + v0.28.0 honesty-rider claims from *present* to `verified-on-fixture`. The previous retro's #1 improvement (recommended twice) is now discharged, not just re-recommended.
- **The discriminating done-bar held.** Phase 6 caught that "flip a claim to verified-on-fixture" admits a trivially-passing impl (write the status string). Hardening the bar to require an auditable evidence block (planted defect + catch text + firing row + tracked-fixture pointer), asserted by the verifier, meant the dogfood couldn't be faked — the goal practised on itself the exact red-team check it documents.
- **The honesty crux survived contact.** Two claims (/converge, reproduction-required) genuinely could not be honestly dogfooded in one context (they need two independent passes). They were left `unverified` with the reason recorded — the vocabulary's whole purpose (verified-on-fixture ≠ verified-live ≠ unverified) earned its keep on first use rather than collapsing into "all green."
- **Verifier 47/47 first run, zero double-space-trap failures.** Last batch lost 8 asserts to the `.`-next-to-space regex trap; this batch dodged it entirely by writing contiguous single-spaced phrases — last retro's lesson applied, even though improvement #2 (the lib-level fix) is still open.

### What failed / friction
- **The `git ls-files` tracked-check forced an ordering quirk** (structural): the verifier asserts the fixture/runbook are *tracked*, but `git ls-files` only sees staged/committed paths — so the files had to be `git add`-ed before the verifier could pass. Benign here (stage-then-verify is the natural flow) but a fresh author could read a spurious FAIL as a real one. (1 occurrence.)
- **Self-referential validation has a ceiling** (structural): an in-context pass proving ClaudeWarp's own reviewer fires is real evidence the *instructions cause the catch*, but it is the author's model grading the author's fixture. `verified-on-fixture` names this honestly, yet the strong claim still rests on a `verified-live` run that has never been done. The debt is now *labelled* and *smaller*, not gone.

### Top 3 improvements
1. Phase (dogfood) — **Do ONE real `verified-live` run** — convert at least one claim from `verified-on-fixture` to `verified-live` via the RUNBOOK step-3 `CLAUDEWARP_QA_MODEL` spawned pass — why: the backlog now makes the fixture-vs-live gap explicit and two claims sit one rung below the strong status; a single live spawned pass on the existing fixture is the cheapest way to retire the self-referential-ceiling debt this retro names, and it also unblocks /converge + reproduction-required (which need two independent passes by construction).
2. verifier-lib — **Add the `phrase` matcher / tracked-path note to `scripts/verifier-lib.sh`** — why: now flagged by TWO retros. The double-space trap was dodged by hand this batch (didn't bite), but the `git ls-files` tracked-check ordering quirk is new friction in the same file; a small `phrase`/`tracked` helper + a header note would retire both taxes the way `md_has` retired the soft-wrap tax — and unlike a live run it costs no budget.
3. Phase (worth-it / fork) — **The cheap-evidence track is now also exhausting — next is genuinely a fork** — why: the disciplines (Options 1/2/2.5) AND their first fixture-level evidence are shipped. What remains is (a) the live-run validation above, (b) held Options 3 (review panel — `--review-panel`/fork/worktree plumbing) / 4 (deep-dive plan mode), both heavier "hold"-flagged builds. No clearly-correct autonomous next build remains; surface the choice with live-run-first as the recommendation.

---

## Retro: behavioural-claim-backlog — verified-live iteration (D2) — 2026-06-28

**Outcome:** v0.31.1 shipped — 2 claims flipped `verified-on-fixture` → `verified-live` via one live spawned pass; 2 remain `unverified` (two-pass mechanisms).
**Milestones:** 1 execution-log entry (Dogfood D2) | rework: none

### What worked
- **The charter fired under genuine independence.** A spawned Sonnet reviewer (different model, reasoning-blind, no hints) independently named the `stop.check: "true"` trivial pass + the assumed `validateToken()` claim + the self-grading tautology, BLOCK @ 9/10 — converting the strongest honesty claim (verified-live) from empty to real. The whole present→fires arc now has its capstone evidence, not just a fixture proxy.
- **Anti-fabrication held under independence**, the hardest rider to prove: the live reviewer marked budget CLEAN rather than inventing a sixth finding when it had every incentive to look thorough.
- **The verifier caught my own contamination.** The `no-PLANT-tags` honesty assert on the hint-stripped twin failed because my own header comment leaked the literal `PLANT[` — the dogfood-the-dogfood check worked, and the guard is now both tracked (the twin) and mandated (RUNBOOK step 3).

### What failed / friction
- **The honest verdict capped the win at 2 of 4.** /converge and reproduction-required are two-pass mechanisms; one live pass produced one verdict and no non-reproducible finding, so neither could be tested. The vocabulary forced this to be recorded as `unverified` rather than rounded up — correct, but it means the live-evidence story is half-done.
- **Engineering a non-reproducible finding on demand is hard** (structural): testing reproduction-required's *downgrade* needs pass-1 to raise a finding pass-2 won't reproduce — but a competent reviewer won't raise a false finding to order. The scripted "budget missing" plant was correctly ignored by the live reviewer. A genuine two-pass test needs a subtler ambiguity, not a planted falsehood.

### Top 3 improvements
1. Phase (dogfood / fork) — **Decide whether the two-pass dogfoods are worth their cost before building them** — why: flipping #3/#4 to verified-live needs ≥2 spawned passes each, more budget, and (for #4) a hard-to-engineer genuinely-ambiguous finding. This is no longer a cheap obvious continuation; it is a real worth-it call for the user, not an autonomous build.
2. verifier-lib — **Add a `not_has` / absence-assert helper to `scripts/verifier-lib.sh`** — why: D2 needed an "assert pattern ABSENT" check (the hint-stripped honesty guard) and had to define `not_has` inline; it is generally useful (asserting a residual was removed, a placeholder filled) and belongs in the shared lib next to `has`/`md_has`. Now the third verifier-DX item flagged across retros.
3. Phase (worth-it) — **The validation track has reached real diminishing returns** — why: two of four claims are verified-live, the cheap fixture + the one cheap live run are done, and what remains (heavier two-pass dogfoods, or the held Options 3/4 builds) all carry genuine cost. Surface the fork with a clear recommendation rather than auto-continuing.

---

## Retro: verifier-lib-not-has (goal) — 2026-06-28

**Outcome:** COMPLETE — 7/7 done conditions met. v0.31.2 shipped.
**Milestones:** 1 execution-log entry | rework: none

### What worked
- **A retro item became a one-batch goal cleanly.** #2 had been deferred three times as "nice but not urgent"; doing it the moment it became the cheapest worth-it option (rather than another two-pass budget spend) was the right read of diminishing returns. Clean contract→ship, no friction, no risk re-classification.
- **The red-team caught the obvious trap before drafting the verifier.** A `not_has` verifier is the textbook trivially-passing case — `grep -q 'not_has' lib` passes even if the function is broken. Phase 6 forced the verifier to assert *behaviour* (0-on-absent, 1-on-present, chk-composition + the converse), and the self-test mirrors it. The discipline dogfooded itself on a feature *about* the dogfood machinery.
- **The honesty wrinkle was documented, not hidden.** `not_has` is not fail-closed (missing file → absent-0); rather than quietly shipping an inconsistency with `has`/`md_has`, it's called out in the lib header, the docs bullet, and the decision_log — so a future author can't misread it as a presence guard.

### What failed / friction
- **None of substance** (structural: a small, well-scoped additive change). The only judgment call was whether a frictionless PATCH still warrants a full retro — it does for the ledger trail, but the analysis is necessarily thin; that's honest, not a gap.

### Top 3 improvements
1. Phase (worth-it / cadence) — **The validation + verifier-DX track is now genuinely complete for this cycle** — why: 2/4 claims verified-live, both cheap evidence runs done, and the last flagged DX item (not_has) shipped. What remains (two-pass live dogfoods for #3/#4, or the held Options 3/4) all carry real budget/scope cost. Stop and surface, don't manufacture another batch.
2. verifier-lib — **`not_has` should now replace the inline inversion in the existing self-test cases** — why: the self-test still hand-rolls `[ "$(has …)" -ne 0 ] && echo 0 || echo 1` in ~6 places that `not_has` now formalizes; a follow-up could DRY them, but only if it doesn't weaken the "raw grep MISSES it" defect-demonstration (those assert a *defect*, not a clean absence — keep them legible). Low priority, legibility-gated.
3. Phase (retro) — **A frictionless PATCH deserves a lean retro, not a skipped one** — why: the ledger trail matters more than the per-entry depth; recording "clean, no friction" honestly is the right outcome, and over-investing analysis in a trivial goal would be its own theater.

---

## Retro: dogfood-converge-d3 (goal) — 2026-06-28

**Outcome:** COMPLETE — 7/7 done conditions met
**Milestones:** 1 execution-log entry | rework: none (the "two-verdict" claim correction was the *point* of the batch, not rework of this batch's own output)

### What worked
- **The honesty gate paid for itself a second time.** The contract's Phase-2 mandatory source read
  (`skills/claude-warp-converge/SKILL.md`) caught that claim #3 had been factually wrong in the backlog
  for four releases — describing `/converge` as a reviewer-verdict reconciler when it reconciles repo
  state vs intent. Setting up a dogfood *corrected a latent doc defect* before producing any evidence.
- **Live D3 fired cleanly under genuine independence.** A spawned Sonnet agent (different model,
  reasoning-blind) classified both designed gaps (`missing` doc, `contradicts` must_not_touch), surfaced
  the breach as Type-B, and reported NOT converged — with no fabricated gaps. The predicted catch held.
- **The behaviour-not-presence verifier discipline carried over.** The working verifier asserts the
  *recorded catch* (the agent named both gaps + NOT-converged) and the fixture's three designed
  conditions, with `not_has` guarding the hint-strip — not a grep that a banner string merely exists.

### What failed / friction
- **My verifier regex over-anticipated backticks (3 FAILs on first run).** I wrote patterns with a `.`
  placeholder for backticks that `md_has` strips, so `STATUS: .verified-live` never matched
  `STATUS: verified-live`. Structural: easy to repeat whenever asserting against markdown that
  `md_has` normalizes. The content was correct; only the patterns were wrong.
- **The agent under-rated the contradicts severity (R0 vs the skill's "top severity").** It still
  *surfaced* the breach (the load-bearing behaviour), but the numeric severity diverged. A real, if
  minor, honesty blemish — recorded, not glossed.
- **A housekeeping push to main was correctly blocked mid-flow.** The combined merge+prune+tag script
  tried to push the prune commit direct-to-main; the classifier refused the whole script. No harm, but
  it cost a round-trip — the prune should have been planned as a PR from the start.

### Top 3 improvements
1. Phase 2 (verifier authoring) — when asserting via `md_has`, write patterns against the *normalized*
   text (backticks/emphasis already stripped); never add a `.` placeholder for a backtick `md_has`
   removes — why: it caused all 3 first-run FAILs this batch and is a repeatable trap.
2. Phase 9/10 (ship choreography) — never combine a PR-merge with a direct-to-main housekeeping push in
   one script; plan the post-merge prune as its own PR up front — why: the classifier (correctly) refuses
   the mixed script, wasting a round-trip every time.
3. Phase 6 (red-team) — when a dogfood's evidence is a live agent's *severity rating*, assert only the
   load-bearing behaviour (did it surface?) and record numeric-severity divergence as a caveat, not a
   pass/fail — why: severity is a judgment call; gating on it would make the dogfood brittle and tempt
   relabelling.

---

## Retro: dogfood-repro-d4 (goal) — 2026-06-28

**Outcome:** COMPLETE — 6/6 done conditions met
**Milestones:** 1 execution-log entry | rework: one in-flight re-spawn (the contaminated first pass-2 run, caught by the verifier and re-run clean — caught pre-merge, not post-ship)

### What worked
- **The whole backlog is closed honestly (4/4 verified-live).** The hardest claim — a genuinely
  two-pass mechanism — flipped by recognising that the mechanism under test is *pass-2*, and making
  pass-2 the live independent agent while pass-1 is a constructed planted-finding artifact. The catch
  was two-directional (kept the reproducible blocker, downgraded the non-reproducible one), so a lazy
  agent couldn't pass.
- **The verifier caught my own contamination.** The first `pass1-findings.md` carried a setup note that
  hinted one finding was false; the `not_has` hint-strip assertion failed loudly, I stripped the note
  and re-spawned pass-2 clean. The contamination guard the project built caught its own author — the
  second time (D2's PLANT self-leak was the first). This is the dogfood discipline paying for itself.
- **Behaviour-not-presence held under the hardest claim.** The verifier asserts the recorded
  two-directional disposition (A reproduced/kept, B not-reproduced/downgraded, `[pass-2/sonnet]`) plus
  the fixture's true/false-by-construction (twin really has `check: "true"` AND `loop_max_usd: 5`), not
  a banner string.

### What failed / friction
- **I contaminated my own fixture on the first pass (caught, corrected).** A meta-note explaining the
  test setup leaked into the artifact the live agent reads. Structural: when an evidence file documents
  *why* it exists, that rationale can leak the answer. The fix is the same each time — the explanation
  belongs in `BEHAVIOURAL-CLAIMS.md`/the verifier, never in the artifact under review.
- **The backtick-strip regex trap recurred (again).** Three D4 verifier patterns used `.` placeholders
  for backticks `md_has` strips. Identical to the D3 retro's #1 improvement — the lesson hadn't been
  encoded anywhere a future verifier-author would see it before writing patterns.
- **Index hygiene: a stray `git add -A` during verification swept the whole batch into the contract
  commit.** Required a soft reset + re-split into contract + feat commits. Running the verifier with
  `git add -A` mid-flow pollutes the index for the eventual structured commit.

### Top 3 improvements
1. Phase 2 (fixture authoring) — never put test-setup rationale ("one of these is false", "planted
   defect", PLANT tags) inside the artifact the live agent reviews; keep it in the backlog/verifier —
   why: it leaked into pass-1 here and into the D2 twin before; same root cause twice.
2. Tooling — encode the `md_has` normalization rule where verifier-authors hit it (a header comment in
   `scripts/verifier-lib.sh` near `md_has`, or a one-line `--self-test` note): *assert against
   backtick/emphasis-stripped text; no `.` placeholder for a stripped backtick* — why: this trap has now
   cost first-run FAILs in three consecutive batches (D3, and twice in D4).
3. Phase 9 (commit hygiene) — stage explicitly (`git add <paths>`) for structured commits; never rely
   on a `git add -A` that a verification step may have already run — why: it merged the contract and
   feat commits here and forced a soft-reset recovery.

---

## Retro: mdhas-pattern-guard (goal) — 2026-06-28

**Outcome:** COMPLETE — 5/5 done conditions met
**Milestones:** 1 execution-log entry | rework: none — first-run clean (self-test, working verifier, dev.sh, CI all green on the first attempt)

### What worked
- **Retro-to-fix closure.** D4 retro improvement #2 ("encode the `md_has` normalization rule where verifier-authors hit it") became a shipped guardrail in the very next batch. The lesson moved out of `RETRO.md` and into the helper authors actually read (`--help`) plus a live `--self-test` assert — documentation that is *enforced*, not just written.
- **Behaviour-not-presence verifier.** The `working/` check asserted the self-test *PASSES* (so the placeholder-FAILS case actually held), not merely that the note string exists — the P6 discipline carried over correctly.
- **The irony landed clean.** The batch that fixes the `.`-for-a-stripped-backtick trap had **zero first-run FAILs** — the first such batch in a while. Staging was explicit (retro #3), the two commits were structured (contract + feat), and the matcher-semantics guard ("def intact") confirmed no behavioural drift.

### What failed / friction
- **None structural.** The change was small and self-contained; the established rhythm (contract → implement → verify → PR → CI → merge → tag → release → retro) absorbed it without incident. The only judgement call — whether a comment+test change warrants the full contract ceremony — was resolved in favour of consistency with the repo's own dogfood discipline.

### Top 3 improvements
1. Phase 2 (verifier-lib authoring) — **the guard now exists; the next lever is discoverability at write-time, not read-time.** A future nicety: a `--lint-pattern '<pat>' <file>` mode that warns if a pattern contains a literal backtick or a `.` adjacent to where normalization would strip one — catching the slip as the author types it, before the verifier even runs. Low priority; the self-test + `--help` note already close the recurring failure.
2. Phase 9 (ship) — **consider a "trivial-PATCH" express lane.** A comment+test change to a non-merge-gating helper carried a full contract.yaml + GOAL.md + working verifier. That ceremony is *correct dogfooding* but heavy for a one-line-class fix; a documented threshold (e.g. R0 doc/comment-only → skip the GOAL anchor, keep the verifier) would right-size the rhythm without losing rigor where it matters.
3. Milestone hygiene — **nothing to fix; record the clean run as the baseline.** This batch is the template for a low-risk PATCH: explicit staging, two structured commits, behaviour-asserting verifier, semantics-untouched guard. Future batches that regress from this (stray `git add -A`, presence-only asserts) should be measured against it.

---

## Retro: corroboration-rigor (goal) — 2026-06-28

**Outcome:** COMPLETE — 6/6 done conditions met
**Milestones:** 2 execution-log entries (contract @ 86dc53c, feat @ 9aa000d) | rework: one verifier FAIL on first run (the `4/5` literal lived only in docs, not yet in `BEHAVIOURAL-CLAIMS.md`) — fixed in a single edit, no logic change.

### What worked
- **Adapt-not-invent paid off.** All three mechanics (`[CMD_*]` tags, the same-family label, the porcelain+digest guard) were lifted from prior art whose exact specs were already in hand from the earlier deep repo-search, so the build was transcription + scoping, not design. Zero mid-build surprises.
- **The behaviour-leaning verifier earned its keep at R2.** It didn't just grep for the new tags — it *ran* `reviewer-guard --self-test` (proving the guard fires: read-only passes, mutation fails) and asserted claim #5 is registered `unverified` (not silently asserted) and that claims #1–#4 were **not** relabeled (`grep -cE '^### [1-4]\..*verified-live' == 4`). That last guard is the one that would have caught an accidental over-claim.
- **Honest ledger discipline held.** A new instruction-only feature (command-verification) shipped `unverified` and moved the backlog 4/4 → **4/5**, rather than asserting a `verified-live` it hadn't earned. The deterministic guard (#3) correctly carries *no* behavioural claim (it's self-tested).
- **Credits landed exactly with the influence** — agent-review-panel / dementev-dev / llm-council / NABAOS were added to the prior-art table in the same PR that shipped their mechanics, mapped to specific rows.

### What failed / friction
- **Doc/ledger count drift (1×):** the `4/5` honest-count literal was written into `docs/loop-harness.md` but not into `BEHAVIOURAL-CLAIMS.md`, so the first verifier run FAILed. Structural: a count that must appear in two files is a single fact with two homes — the verifier caught the omission (working as designed), but authoring missed it once.
- **`reviewer-guard.sh` is not wired into `scripts/dev.sh` step 6** ("shared executables fail closed" currently tests only `verifier-lib` + `ledger`). The new shared executable is self-tested via the working verifier + `stop.check`, but it falls outside the standing CI self-test net — a deliberate scope hold, not a gap closed.

### Top 3 improvements
1. Phase 2 (draft) — **single-source the backlog count.** When a fact like "N/M verified-live" must appear in ≥2 files, state it once and have the others reference it, or add a verifier cross-check that the count matches across files — so a count update can't half-land. The verifier caught it this time; make it impossible to author wrong.
2. Phase (next batch) — **wire `reviewer-guard.sh` into `dev.sh verify` step 6.** It's now a shipped shared executable with a `--self-test`; fold it into the "shared executables fail closed" CI check (a 1-line addition, out of *this* batch's scope) so it's covered by CI on every change, not only when a working/ verifier happens to run it.
3. Phase (follow-up) — **schedule Dogfood D5 to flip claim #5.** Command-verification ships `unverified`; the honest next step is a live spawned pass fed a command-falsifiable false blocker, recording whether it actually runs the command and demotes. Until then the backlog correctly reads 4/5 — don't let the `unverified` sit indefinitely (the same anti-pattern the backlog exists to prevent).

---

## Retro: devsh-hardening (goal) — 2026-06-29

**Outcome:** COMPLETE — 5/5 done conditions met
**Milestones:** 2 execution-log entries (contract @ 075d45c, feat @ c3a8604) | rework: none — first-run verifier PASS (15/15), `dev.sh verify` 7/7 on the first run.

### What worked
- **Closing a retro item the very next batch worked as intended.** The corroboration-rigor retro flagged exactly these two gaps and explicitly held them out of scope; this PATCH picked them up directly — the retro → next-contract handoff did its job (no item left to rot).
- **Computing the count from the registry, not hard-coding it, is the right shape.** Step 7 derives `expected="$verified/$total"` from the claim headings, so the check FAILS when the real count drifts — it can't become a check-that-can't-fail (the agent-review-panel control-validation discipline applied to our own tooling). The first run proved it computes `4/5` and finds it in both files.
- **The behaviour-leaning verifier ran the real thing.** `working/devsh-hardening-verify.sh` didn't just grep for the new function — it executed `dev.sh verify` and asserted `[7/7]`, `count coherent: 4/5`, and the reviewer-guard line all appeared. That's the strongest form of the working/ verifier pattern.
- **`replace_all` on `/6] → /7]`** renumbered all six labels safely in one edit (the string was unique to the check labels).

### What failed / friction
- **None functional.** The only friction was a transient harness "file not read" guard on `CHANGELOG.md` (edited earlier this session) — a re-Read cleared it; no content issue.
- **Scope-shape note (not a failure):** this goal was a chore/hardening change with no charter impact, yet still ran the full contract→verifier→PR→release→retro rhythm. Correct for traceability, but it's the lightest-weight batch the rhythm is applied to — worth noting that the ceremony cost is fixed regardless of change size.

### Top 3 improvements
1. Phase (meta) — **a "trivial-PATCH express lane" is now twice-flagged** (mdhas-pattern-guard retro #2, and again here). Two consecutive sub-30-line, no-charter PATCHes ran the full rhythm. Consider a documented lighter path (still: branch + verifier + CI + release, but a one-line contract) for changes that touch only `scripts/dev.sh`/docs/tooling with `must_not_touch: skills/**`. Don't drop rigor — drop ceremony proportional to blast radius.
2. Phase 2 (draft) — **the count-coherence check could extend to other single-sourced facts.** The same compute-and-cross-check pattern would catch drift in the skill count ("15 skills" appears in several docs) or the VERSION across manifest/docs. A small follow-up could generalise step 7 into a "derived-facts coherence" check.
3. Phase (retro hygiene) — **record the first-run-clean baseline again.** Two of the last three goals (mdhas-pattern-guard, devsh-hardening) were first-run clean; corroboration-rigor had one caught-and-fixed FAIL. The trend is healthy — the behaviour-leaning verifier + Phase-2 reads are holding. Keep measuring regressions against this.

---
