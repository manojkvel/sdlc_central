# Project state

The runner rewrites the AIDLC_RESUME block after every step. The approval guard
edits BLOCKED_GATE, GATE_RISK and NEXT_ACTION* when a decision is recorded.
Agents never edit this block by hand. Schema: config/schemas/state-resume.schema.json.

## AIDLC_RESUME
CURRENT_PHASE: 04-hub-and-decisions
CURRENT_STAGE: review
BLOCKED_GATE: none
GATE_RISK: none
NEXT_ACTION: Human decisions needed: APPROVE SPEC and APPROVE PLAN for phases 01-04 (or BACKFILLED), a human review of each REVIEW.md, and validation of hub-and-spoke on a real second workstream. Phases 1-3 committed; phase 4 verified 8/8 and uncommitted.
NEXT_ACTION_OWNER: human:tech-lead
NEXT_ACTION_INPUTS: .track/phases/04-hub-and-decisions/VERIFICATION.md, .track/phases/04-hub-and-decisions/REVIEW.md, docs/aidlc/hub-and-spoke.md, docs/aidlc/decision-bot.md
DONE: phase 1 (committed), phase 2 recorder, verifier, W08/C05/H05, skills, pipelines, tests
EVIDENCE: .track/phases/04-hub-and-decisions/evidence/index.json
OPEN_RISKS: none

## Phases
| Phase | Stage | Tier | Profile | Risk | Last decision |
| --- | --- | --- | --- | --- | --- |
| 01-control-audit-rails | review | 2 | feature | medium | none |
| 02-evidence-rail | review | 2 | feature | medium | none |
| 03-governance-knowledge | review | 2 | feature | medium | none |
| 04-hub-and-decisions | review | 2 | feature | medium | none |
