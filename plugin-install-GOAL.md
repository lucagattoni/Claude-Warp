# Goal: Install ClaudeWarp as a Claude Code plugin

## Objective
Make ClaudeWarp installable as a Claude Code plugin via
`/plugin marketplace add lucagattoni/Claude-Warp` + `/plugin install claude-warp@claude-warp`,
reusing the existing repo-root `skills/` tree as the plugin's skill set. Additive — the curl
`install.sh` path stays untouched. Done when `claude plugin validate .` exits 0, the plugin
installs and exposes all skills under the `/claude-warp:` namespace, and the install docs cover
the new path.

## Done conditions
- [ ] `.claude-plugin/plugin.json` exists with `name: claude-warp`, `description`, `version` (from VERSION), `author`
- [ ] `.claude-plugin/marketplace.json` exists listing the `claude-warp` plugin with `source: "."`
- [ ] `claude plugin validate .` exits 0
- [ ] User-facing literal command slugs audited so they read correctly under both `/claude-warp:<skill>` and bare `/claude-warp-<skill>` forms (no logic changes to skill bodies)
- [ ] `docs/install.md` and `README.md` document the plugin install path alongside the curl one-liner

## Guardrails
- Must not touch: `install.sh` (curl path stays as-is), `templates/`, `.claude/` (self-host symlinks)
- `skills/**/SKILL.md` may be touched for the slug audit ONLY — namespace-neutral wording, never logic changes
- Budget: --max-turns 30 --max-budget-usd $5.00

## Verifier
```bash
claude plugin validate . && test -f .claude-plugin/plugin.json && test -f .claude-plugin/marketplace.json
```
Exit 0 = done. Any non-zero = not done.

## Readiness
✓ Readiness: G2 — objective clear, GOAL.md state file present, budget defined. Verifier
independence (G1 axis) is unscored: at R1 a deterministic CLI check (`claude plugin validate`)
is sufficient and no independent grader is required.

## Execution log
<!-- Append entries at meaningful milestones — do not delete entries -->
- [2026-06-26 19:55 IST] Goal scaffolded from approved contract.yaml (risk R1, readiness G2)
