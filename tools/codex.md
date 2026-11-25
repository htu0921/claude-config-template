# House rules (all Codex work)

Personal rules, for every project. A repository's own rules are in its `AGENTS.md`
files. These personal rules are built by claude-config's `sync.ps1`: what every AI
tool follows comes from `RULES.md`, the Codex part from `tools/codex.md`. A change
goes into one of those, never into two places.

{{RULES}}

## Codex: usage preflight and paid usage

- Before starting each newly requested task, give a brief preflight with the sizing line: recommended model, current percentage used for each available usage window, and whether paid credits or other metered charges are expected. Use the smallest suitable model and effort; distinguish recommendations from the actual active settings, and never claim to have changed settings unless confirmed.
- Check current account usage with the available usage-limits tool before substantive task work. Report unavailable telemetry honestly; do not invent usage percentages, exact task costs, or a guarantee that work is free. Checking usage and preparing this preflight may precede the report.
- Stop and ask for explicit user approval before work expected to consume paid credits, use a paid API, or incur other additional charges. If included-plan coverage cannot be verified and paid usage is possible, ask before proceeding. Approval must cover the paid action and its scope; ordinary task authorization is not spending approval. Do not buy credits, enable paid fallback, or switch to paid API billing without explicit approval.
- Recheck usage before a substantial scope expansion or costly phase, and when nearing included limits. Pause before continuing into paid usage. State when per-task billing or an exact credit-transition point cannot be determined; these instructions are a behavioral safeguard, not a billing lock.

## Codex: token safety

- Say in the preflight when work will use a lot of Codex usage (long threads, broad scans, many large logs or images, extra-high reasoning), and why. "Finish the goal, then report" still decides the scope: do not stop part way or offer a cheaper menu instead.
- Prefer a fresh thread with a short handoff when the current one is long.
- Do not present file-size or prompt-token estimates as billed Codex usage.
