# Security Policy

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately through GitHub's built-in flow:

**[Report a vulnerability](https://github.com/lucagattoni/Claude-Warp/security/advisories/new)**
(repo → **Security** tab → **Report a vulnerability**)

This opens a private security advisory visible only to the maintainers. Please include:

- what the issue is and its impact,
- steps to reproduce (a minimal case if possible),
- the ClaudeWarp version (`VERSION`) and your Claude Code version (`claude --version`).

You can expect an initial acknowledgement within a few days. Coordinated disclosure is
appreciated — we'll agree on a timeline before any public write-up.

## Supported versions

ClaudeWarp is a fast-moving single-track project: **only the latest released version** (see
[`VERSION`](VERSION) / the newest [GitHub release](https://github.com/lucagattoni/Claude-Warp/releases))
receives security fixes. Please reproduce on the latest version before reporting.

## Scope

ClaudeWarp installs skills, hooks, templates, and scripts into *your own* project and does not touch
anything outside the target directory. Relevant areas for reports:

- the installer (`install.sh`) and setup flow,
- the shipped shell scripts (`scripts/*.sh`) and Git/Claude Code **hooks**,
- the CI workflows under `.github/workflows/`,
- any way a scaffolded loop/harness could exfiltrate secrets, escape its declared scope, or run
  outside its budget/guardrails.

**Out of scope:** vulnerabilities in Claude Code itself (report those to Anthropic), and issues that
require an already-compromised local machine.

## Good to know

- ClaudeWarp is **manifest-free safe**: skills degrade gracefully when a `harness-manifest.json` or
  constitution is absent, and read-only checks fail *closed* (an unrun check is never counted green).
- Supply-chain posture is tracked publicly via **OpenSSF Scorecard** (`.github/workflows/scorecard.yml`).
- Never commit secrets, tokens, or personal data into a project ClaudeWarp manages — the scaffolds
  assume `scope.must_not_touch` and `.gitignore` keep credentials out of tracked files.
