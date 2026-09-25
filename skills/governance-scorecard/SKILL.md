---
name: governance-scorecard
description: Evaluate the six governance dimensions (traceability, artifact hygiene, human approvals, evidence, contracts, security and risk) and write the sealed SCORECARD.md that gates APPROVE RELEASE, naming the owner of every blocked dimension
argument-hint: "[.track/phases/NN-slug] (defaults to the current phase)"
allowed-tools: Read, Grep, Glob, Bash(bash, shasum, jq, ls, find, date)
---
# Governance Scorecard

Decide whether a phase may go to its release gate. You act as the **aidlc-governance-reviewer**. The verdict is binary and computed: **GOVERNANCE APPROVED** unlocks the `APPROVE RELEASE` checkpoint; **GOVERNANCE BLOCKED** routes each gap to the role that owns it.

## AIDLC contract

- Track root: read `track_root` from the agent's `sdlc-central.json`; default `.track/`.
- Before writing: read `<track root>/state.md`. If `BLOCKED_GATE` is not `none`, stop and end with `## AIDLC GATE BLOCKED`.
- After writing an artifact: append one lineage line to `<track root>/lineage.md`:
  `<ISO time> | - | <family.event>: <detail> | <artifact path> | sha256:<hash> | model=<model id> | sdlc=<version>`
- End with exactly one completion marker from this skill's `markers`.
- Never cite `SUMMARY.md`, a summary, or a file's existence as proof of behaviour. Cite command output or an evidence entry.
- Never write `human-decisions.md`. Decisions are recorded only by `aidlc-human-approval-guard`.
- Never read `evidence/index.json`, `lineage.md` or `guardrail-log.md` whole; they grow with every run. Use `aidlc-evidence.sh summary` or `list`, the summary block at the top of `VERIFICATION.md` or `SCORECARD.md`, and `grep '<phase>' lineage.md | tail -20`.
- Never write `SCORECARD.md` by hand. The script writes it sealed; the hooks block hand edits (W08, C05, H05).

## CRITICAL RULES

1. **Run the script; do not score by reading.** Every dimension is computed from artifacts, hooks and the decision log.
2. **No partial approval.** One failed dimension blocks. Advisory notes (for example asserted identity at high risk) are reported but do not change the result.
3. **Route, don't fix.** Name the owner and the exact gap for each failed dimension. The owner fixes it; you re-run.

## Phase 1 — Run

```bash
bash <agent-dir>/hooks/_bin/aidlc-scorecard.sh [--phase NN-slug]
```

| # | Dimension | Passes when | Owner |
|---|---|---|---|
| D1 | Requirements & traceability | `aidlc-traceability-check` returns T00 | aidlc-plan-checker (architect) |
| D2 | Artifact completeness & hygiene | every artifact required by the tier and profile exists, hygiene clean | aidlc-delivery-manager |
| D3 | Human approval audit | every HITL gate before release has an accepted HD record for this phase; state and lineage consistent | aidlc-governance-reviewer (tech lead) |
| D4 | Evidence rail proof | `VERIFICATION.md` sealed, COMPLETE, no stale evidence | aidlc-verifier (developer / QA) |
| D5 | Contract & workstream alignment | tier 3: every consumed contract APPROVED and no release-claims exclusion | aidlc-governance-reviewer (architect) |
| D6 | Security, NFR & risk | `REVIEW.md` has no open CRITICAL/HIGH; every open risk carries a signing HD | aidlc-security-standards-reviewer |

Exit 0 means approved, 2 means blocked. The result is also appended to `gate-history.json` (type `release-scorecard`) for first-pass-rate reporting.

## Phase 2 — Report

- The result line.
- For each FAIL: dimension, gap, owner, and the one action that clears it (for example "record APPROVE PLAN for 01-calc", "re-record TASK-004 after the change to src/api.ts and re-run the verifier", "sign RISK-009 with APPROVE WITH RISK or mitigate it").
- Advisory notes.

When approved, tell the orchestrator to publish the `approve-release` checkpoint with `SCORECARD.md` in `NEXT_ACTION_INPUTS`, so the release decision records the scorecard's hash.

End with the marker the file ends with.
