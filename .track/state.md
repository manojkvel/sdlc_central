# Project state

The runner rewrites the AIDLC_RESUME block after every step. The approval guard
edits BLOCKED_GATE, GATE_RISK and NEXT_ACTION* when a decision is recorded.
Agents never edit this block by hand. Schema: config/schemas/state-resume.schema.json.

## AIDLC_RESUME
CURRENT_PHASE: 03-governance-knowledge
CURRENT_STAGE: review
BLOCKED_GATE: none
GATE_RISK: none
NEXT_ACTION: Human decisions needed: APPROVE SPEC and APPROVE PLAN for phases 01-03 (or record them as BACKFILLED with the approval guard), and the open items in docs/aidlc/design-invariants.md. Phases 1-2 are committed; phase 3 is verified 9/9 and uncommitted.
NEXT_ACTION_OWNER: human:tech-lead
NEXT_ACTION_INPUTS: .track/phases/03-governance-knowledge/VERIFICATION.md, .track/phases/03-governance-knowledge/SCORECARD.md, .track/phases/03-governance-knowledge/REVIEW.md
DONE: phase 1 (committed), phase 2 recorder, verifier, W08/C05/H05, skills, pipelines, tests
EVIDENCE: .track/phases/03-governance-knowledge/evidence/index.json
OPEN_RISKS: none

## Phases
| Phase | Stage | Tier | Profile | Risk | Last decision |
| --- | --- | --- | --- | --- | --- |
| 01-control-audit-rails | review | 2 | feature | medium | none |
| 02-evidence-rail | review | 2 | feature | medium | none |
| 03-governance-knowledge | review | 2 | feature | medium | none |
