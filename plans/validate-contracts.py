#!/usr/bin/env python3
"""Live executable test of /claude-warp-contract logic against golden fixtures.

For each fixture we encode two contract states:
  - draft    : the Phase 1 best-guess (carries the seeded problem, if any)
  - approved : the Phase 8 contract after the critical pass forced fixes

A correct skill means: the validator (which encodes the schema + critical-pass
checks + readiness gate) REJECTS the draft with the expected finding, and ACCEPTS
the approved contract. Clean fixtures (no seeded problem) pass directly.
"""

RISK_ORDER = {f"R{i}": i for i in range(6)}


def critical_pass(c):
    """Return the list of findings the Phase 5 critical pass should raise."""
    findings = []
    risk = RISK_ORDER[c["risk"]]
    scope = c.get("scope", {})
    action = (c.get("action") or "").lower()

    # over-reach: ACTION writes/commits but SCOPE is read-only
    writes = any(w in action for w in ("commit", "merge", "write", "delete", "drop", "fix"))
    read_only = scope.get("may_touch_mode") == "read-only"
    if writes and read_only:
        findings.append("over-reach: ACTION writes but SCOPE is read-only")

    # cost runaway: no budget
    b = c.get("budget") or {}
    if not b.get("loop_max_usd") and not b.get("step_max_budget_usd"):
        findings.append("cost-runaway: no budget cap")

    # no stopping condition / verifier theater: STOP not a command
    stop = c.get("stop") or {}
    if not stop.get("check") or stop.get("check") in ("looks done", "improve", None):
        findings.append("no-stopping-condition: STOP is not a runnable check")

    # reviewer bias: R2+ needs an independent verifier
    if risk >= 2 and not (c.get("verifier") or {}).get("independent"):
        findings.append("reviewer-bias: R2+ requires independent verifier")

    # dark factory: R3+ needs an escalation/surface gate
    if risk >= 3 and not c.get("surface_conditions"):
        findings.append("dark-factory: R3+ requires a surface/escalation gate")

    # irreversible: R4+ needs an explicit human-approval surface condition
    if risk >= 4:
        sc = " ".join(c.get("surface_conditions") or []).lower()
        if "approval" not in sc and "approve" not in sc:
            findings.append("irreversible: R4+ requires explicit human-approval step")

    # infinite fix loop: no attempt cap
    if not (c.get("escalation") or {}).get("after_attempts"):
        findings.append("infinite-fix-loop: no attempt cap")

    return findings


def readiness(c):
    """LCR (loop) or G-score (goal) + gate decision."""
    risk = RISK_ORDER[c["risk"]]
    if c["kind"] == "loop":
        scope = c.get("scope", {})
        b = c.get("budget") or {}
        pts = 0
        pts += bool((c.get("trigger") or {}).get("type"))
        pts += bool(scope.get("may_touch") and scope.get("must_not_touch"))
        pts += bool(c.get("action"))
        pts += bool(b.get("loop_max_usd") and b.get("step_max_budget_usd") and b.get("max_turns"))
        pts += bool((c.get("stop") or {}).get("check"))
        pts += bool((c.get("report") or {}).get("on") == "delta")
        need = 6 if risk >= 3 else 5
        ok = pts >= need
        if risk >= 3:
            ok = ok and (c.get("verifier") or {}).get("independent") and bool(c.get("surface_conditions"))
        return f"LCR {pts}/6 (need {need})", ok
    else:
        g = 0
        stop = c.get("stop") or {}
        g += bool(stop.get("check"))                       # objective clarity (checkable)
        g += bool((c.get("verifier") or {}).get("independent"))
        g += bool(c.get("state_file"))
        b = c.get("budget") or {}
        g += bool(b.get("max_turns") and (b.get("loop_max_usd") or b.get("step_max_budget_usd")))
        need = 4 if risk >= 3 else 3
        return f"G{g}/4 (need {need})", g >= need


# ── Fixtures: (label, expected_branch, expected_risk, expected_draft_findings, draft, approved)
FIXTURES = [
    ("F1 summarise issues", "loop", "R0", [],
     {  # draft == approved (clean)
        "kind": "loop", "risk": "R0",
        "trigger": {"type": "cron", "schedule": "0 9 * * *"},
        "scope": {"may_touch": ["ISSUES_LOG.md"], "must_not_touch": ["src/"]},
        "action": "append a summary of new issues to the log",
        "budget": {"loop_max_usd": 0.10, "step_max_budget_usd": 0.10, "max_turns": 10},
        "stop": {"check": "grep \"$(date +%F)\" ISSUES_LOG.md"},
        "report": {"on": "delta"}, "escalation": {"after_attempts": 3},
     },
     None),

    ("F2 auto-merge green PR", "loop", "R3", ["dark-factory", "reviewer-bias"],
     {  # draft: R3, no surface gate, no independent verifier
        "kind": "loop", "risk": "R3",
        "trigger": {"type": "cron", "schedule": "*/15 * * * *"},
        "scope": {"may_touch": ["PRs", "main"], "must_not_touch": ["release/*"]},
        "action": "merge PRs whose CI is green",
        "budget": {"loop_max_usd": 1.0, "step_max_budget_usd": 0.5, "max_turns": 20},
        "stop": {"check": "gh pr list --search 'status:success' --json number"},
        "report": {"on": "delta"}, "escalation": {"after_attempts": 3},
     },
     {  # approved: + independent verifier + surface gate
        "kind": "loop", "risk": "R3",
        "trigger": {"type": "event", "event": "CI green webhook"},
        "scope": {"may_touch": ["PRs", "main"], "must_not_touch": ["release/*"]},
        "action": "merge PRs whose CI is green",
        "budget": {"loop_max_usd": 1.0, "step_max_budget_usd": 0.5, "max_turns": 20},
        "stop": {"check": "gh pr list --search 'status:success' --json number"},
        "verifier": {"independent": True, "mechanism": "CI status check"},
        "surface_conditions": ["any PR touching auth/ or migrations/ — human approves merge"],
        "report": {"on": "delta"}, "escalation": {"after_attempts": 3},
     }),

    ("F3 migrate auth (goal)", "goal", "R2", ["reviewer-bias"],
     {  # draft: goal, no independent verifier
        "kind": "goal", "risk": "R2",
        "scope": {"must_not_touch": ["lib/auth/legacy"]},
        "action": "migrate lib/auth to v2",
        "budget": {"loop_max_usd": 5.0, "max_turns": 50},
        "stop": {"check": "pytest tests/auth -q"},
        "state_file": "GOAL.md", "escalation": {"after_attempts": 3},
     },
     {  # approved: + independent verifier
        "kind": "goal", "risk": "R2",
        "scope": {"must_not_touch": ["lib/auth/legacy"]},
        "action": "migrate lib/auth to v2",
        "budget": {"loop_max_usd": 5.0, "max_turns": 50},
        "stop": {"check": "pytest tests/auth -q"},
        "verifier": {"independent": True, "mechanism": "CI pytest job"},
        "state_file": "GOAL.md", "escalation": {"after_attempts": 3},
     }),

    ("F4 read-only + commit", "loop", "R1", ["over-reach"],
     {  # draft: contradiction (read-only scope, committing action)
        "kind": "loop", "risk": "R1",
        "trigger": {"type": "cron", "schedule": "0 2 * * *"},
        "scope": {"may_touch": ["src/"], "may_touch_mode": "read-only", "must_not_touch": ["prod/"]},
        "action": "commit fixes for lint warnings",
        "budget": {"loop_max_usd": 0.2, "step_max_budget_usd": 0.1, "max_turns": 15},
        "stop": {"check": "ruff check . && git diff --quiet || true"},
        "report": {"on": "delta"}, "escalation": {"after_attempts": 3},
     },
     {  # approved: scope made writable (contradiction resolved)
        "kind": "loop", "risk": "R1",
        "trigger": {"type": "cron", "schedule": "0 2 * * *"},
        "scope": {"may_touch": ["src/"], "may_touch_mode": "write", "must_not_touch": ["prod/"]},
        "action": "commit fixes for lint warnings",
        "budget": {"loop_max_usd": 0.2, "step_max_budget_usd": 0.1, "max_turns": 15},
        "stop": {"check": "ruff check ."},
        "report": {"on": "delta"}, "escalation": {"after_attempts": 3},
     }),

    ("F5 nightly DROP prod", "loop", "R4", ["dark-factory", "irreversible"],
     {  # draft: R4, no surface/approval
        "kind": "loop", "risk": "R4",
        "trigger": {"type": "cron", "schedule": "0 3 * * *"},
        "scope": {"may_touch": ["prod-db"], "must_not_touch": ["backups/"]},
        "action": "drop stale rows from prod db",
        "budget": {"loop_max_usd": 0.5, "step_max_budget_usd": 0.5, "max_turns": 10},
        "stop": {"check": "psql -c 'select count(*) from stale' | grep -q '^ *0'"},
        "report": {"on": "delta"}, "escalation": {"after_attempts": 3},
     },
     {  # approved: + human-approval surface condition + independent verifier
        "kind": "loop", "risk": "R4",
        "trigger": {"type": "cron", "schedule": "0 3 * * *"},
        "scope": {"may_touch": ["prod-db"], "must_not_touch": ["backups/"]},
        "action": "drop stale rows from prod db",
        "budget": {"loop_max_usd": 0.5, "step_max_budget_usd": 0.5, "max_turns": 10},
        "stop": {"check": "psql -c 'select count(*) from stale' | grep -q '^ *0'"},
        "verifier": {"independent": True, "mechanism": "row-count diff vs backup"},
        "surface_conditions": ["always: human must approve the DELETE before execution"],
        "report": {"on": "delta"}, "escalation": {"after_attempts": 3},
     }),

    ("F6 improve the UI (goal)", "goal", "R1", ["no-stopping-condition"],
     {  # draft: vibe stop
        "kind": "goal", "risk": "R1",
        "scope": {"must_not_touch": ["backend/"]},
        "action": "improve the UI",
        "budget": {"loop_max_usd": 3.0, "max_turns": 30},
        "stop": {"check": None},
        "state_file": "GOAL.md", "escalation": {"after_attempts": 3},
     },
     {  # approved: gradable conversion → checkable criteria
        "kind": "goal", "risk": "R1",
        "scope": {"must_not_touch": ["backend/"]},
        "action": "improve the UI to meet 4 graded dimensions",
        "budget": {"loop_max_usd": 3.0, "max_turns": 30},
        "stop": {"check": "node scripts/ui-audit.js  # contrast>=4.5, type-scale consistent, no placeholder, all interactive elements respond"},
        "verifier": {"independent": True, "mechanism": "ui-audit script"},
        "state_file": "GOAL.md", "escalation": {"after_attempts": 3},
     }),
]


def run():
    rows = []
    all_ok = True
    for label, exp_branch, exp_risk, exp_findings, draft, approved in FIXTURES:
        # branch + risk
        branch_ok = draft["kind"] == exp_branch
        risk_ok = draft["risk"] == exp_risk

        # critical pass on draft: every expected finding category must appear
        draft_findings = critical_pass(draft)
        cats = {f.split(":")[0] for f in draft_findings}
        catch_ok = all(any(e == c for c in cats) for e in exp_findings)
        _, draft_pass = readiness(draft)
        # draft must be REJECTED if it had seeded findings
        draft_rejected_ok = (not exp_findings) or (draft_findings != [] and (not draft_pass or cats))

        # approved must pass cleanly
        target = approved or draft
        appr_findings = critical_pass(target)
        appr_rubric, appr_pass = readiness(target)
        # approved is OK if readiness passes and no *blocking* findings remain
        blocking = [f for f in appr_findings if f.split(":")[0] in
                    ("over-reach", "no-stopping-condition", "reviewer-bias", "dark-factory", "irreversible")]
        approved_ok = appr_pass and not blocking

        ok = branch_ok and risk_ok and catch_ok and approved_ok
        all_ok &= ok
        rows.append((label, exp_branch, exp_risk,
                     "✓" if branch_ok else "✗",
                     "✓" if risk_ok else "✗",
                     ",".join(sorted(cats)) or "—",
                     "✓" if catch_ok else "✗MISS",
                     appr_rubric,
                     "✓" if approved_ok else "✗",
                     "PASS" if ok else "FAIL"))

    w = [22, 6, 5, 4, 4, 34, 6, 16, 4, 6]
    hdr = ["fixture", "brnch", "risk", "br", "rk", "draft findings (caught)", "catch", "approved rubric", "appr", "result"]
    print("  ".join(h.ljust(w[i]) for i, h in enumerate(hdr)))
    print("  ".join("-" * w[i] for i in range(len(w))))
    for r in rows:
        print("  ".join(str(c).ljust(w[i]) for i, c in enumerate(r)))
    print()
    print("ALL FIXTURES PASS ✓" if all_ok else "SOME FIXTURES FAILED ✗")
    return all_ok


if __name__ == "__main__":
    import sys
    sys.exit(0 if run() else 1)
