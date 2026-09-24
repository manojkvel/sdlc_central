# Project state

The runner rewrites the AIDLC_RESUME block after every step. The approval guard
edits BLOCKED_GATE, GATE_RISK and NEXT_ACTION* when a decision is recorded.
Agents never edit this block by hand. Schema: config/schemas/state-resume.schema.json.

## AIDLC_RESUME
CURRENT_PHASE: 02-evidence-rail
CURRENT_STAGE: review
BLOCKED_GATE: none
GATE_RISK: none
NEXT_ACTION: Review phases 1 and 2 on branch aidlc_framework; phase 1 is committed (81b4949), phase 2 is uncommitted; decide the open items in docs/aidlc/design-invariants.md
NEXT_ACTION_OWNER: human:tech-lead
NEXT_ACTION_INPUTS: .track/phases/02-evidence-rail/VERIFICATION.md, docs/aidlc/evidence.md, docs/aidlc/design-invariants.md
DONE: phase 1 (committed), phase 2 recorder, verifier, W08/C05/H05, skills, pipelines, tests
EVIDENCE: .track/phases/02-evidence-rail/evidence/index.json
OPEN_RISKS: none

## Phases
| Phase | Stage | Tier | Profile | Risk | Last decision |
| --- | --- | --- | --- | --- | --- |
| 01-control-audit-rails | review | 2 | feature | medium | none |
| 02-evidence-rail | review | 2 | feature | medium | none |
