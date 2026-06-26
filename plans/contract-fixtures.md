# Contract Command — Golden Fixtures & Validation Traces

Acceptance fixtures for `/claude-warp-contract` (plan: [contract-command.md](contract-command.md)).
Each fixture is a goal string with the expected Phase 0 branch, final risk class, and the
critical-pass findings that must fire. The traces below are paper validations of the
skill logic in `skills/claude-warp-contract/SKILL.md` — replayed live during verification
(metrics C2/C3/C5/C6).

| # | Goal string | Branch | Risk | Critical pass must catch |
|---|---|---|---|---|
| F1 | "summarise new GitHub issues every morning" | Loop | R0 | — (clean; ≤3 questions) |
| F2 | "every 15 min, auto-merge any green PR" | Loop | R3 | missing escalation gate; auto-merge is Type B |
| F3 | "migrate lib/auth to v2; done when /auth tests pass" | Goal | R2 | needs independent verifier |
| F4 | "keep the codebase clean (read-only)" + ACTION "commit fixes" | Loop | R1 | SCOPE/ACTION contradiction (over-reach) |
| F5 | "nightly DROP of stale rows in prod DB" | Loop | R4 | irreversible; force human-approval step |
| F6 | "improve the UI" | Goal | R1 | vibe STOP → gradable conversion, not flat-reject |

---

## Validation traces (paper dry-run, step 2 of build)

### F1 — "summarise new GitHub issues every morning"  ✅ matches
- **Phase 0:** "every morning" recurs → `kind: loop`. ✓
- **Phase 1 draft:** trigger cron `0 9 * * *`; scope may_touch `[GitHub Issues (read), ISSUES_LOG.md]`, must_not_touch `[src/]`; action "append summary of new issues to log"; stop check `grep "$(date +%F)" ISSUES_LOG.md`.
- **Phase 2 risk:** only writes a log file, no code/infra → **R0**. ✓
- **Phase 3:** light posture — confirm budget + stop, ≤3 questions. ✓
- **Phase 5:** no check fires (scope/action consistent, stop is a command, report on delta). Clean. ✓
- **Phase 6:** LCR 6/6 ≥ 5/6 → pass.
- **Result:** Loop / R0 / clean / ≤3 Q — **as expected.**

### F2 — "every 15 min, auto-merge any green PR"  ✅ matches
- **Phase 0:** recurs → `kind: loop`. ✓
- **Phase 1 draft:** trigger cron `*/15 * * * *`; action "merge PRs whose CI is green"; scope touches PRs + `main`.
- **Phase 2 risk:** merges to `main` → prod-adjacent → **R3**. ✓
- **Phase 5 critical pass fires:**
  - *Escalation gate defined (R3+)?* → none drafted → **fires** ("add a Surface condition"). ✓
  - *Type B work routed to human?* → "is this PR safe to merge" is a judgment call → **fires**. ✓
  - *TRIGGER has work to do?* → most 15-min ticks have no green PR → polling-loop nudge toward an event trigger.
- **Phase 6:** R3 demands LCR 6/6 + `verifier.independent: true` + ≥1 `surface_conditions` → forces them in before passing.
- **Result:** Loop / R3 / catches missing escalation + Type B auto-merge — **as expected.**

### F4 — "keep the codebase clean (read-only)" + ACTION "commit fixes"  ✅ matches
- **Phase 0:** ongoing upkeep → `kind: loop`. ✓
- **Phase 1 draft:** faithfully mirrors the user's contradiction — scope `may_touch` read-only, action "commit fixes".
- **Phase 2 risk:** commits fixes = reversible write → **R1**. ✓
- **Phase 5 critical pass fires:**
  - *SCOPE ⊇ ACTION writes?* → ACTION commits but SCOPE is read-only → **fires** over-reach ("which is wrong?"). ✓
- **Result:** Loop / R1 / catches the seeded contradiction — **as expected.**

### F6 — "improve the UI"  ✅ matches
- **Phase 0:** one-shot improvement, not triggered → `kind: goal` (skill asks if ambiguous). ✓
- **Phase 1 draft:** objective "improve the UI"; no checkable stop.
- **Phase 2 risk:** reversible UI edits → **R1**. ✓
- **Phase 5 critical pass:** *STOP is a command, not a vibe?* → "improve the UI" has no exit-code done → **fires**. Subjective-STOP branch: offer doc-04 four-dimension gradable conversion (Quality / Originality / Craft / Functionality) → turn into measurable criteria. **Not** a flat reject. ✓
- **Phase 6:** pre-conversion objective clarity = 0 → **G0, gate blocks**; post-conversion it becomes checkable and can reach G2. ✓
- **Result:** Goal / R1 / vibe STOP converted not rejected — **as expected.**

---

## Outcome

All four traced fixtures (F1, F2, F4, F6) produce the expected branch, risk class, and
critical-pass behaviour against the skill as written. No design gap surfaced during the
dry-run. F3 and F5 remain for live verification (independent-verifier requirement and
irreversible-action human-approval step, respectively).
