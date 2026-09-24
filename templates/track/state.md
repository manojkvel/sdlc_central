# Project state

The runner rewrites the AIDLC_RESUME block after every step. The approval guard
edits BLOCKED_GATE, GATE_RISK and NEXT_ACTION* when a decision is recorded.
Agents never edit this block by hand. Schema: config/schemas/state-resume.schema.json.

## AIDLC_RESUME
CURRENT_PHASE: none
CURRENT_STAGE: intake
BLOCKED_GATE: none
GATE_RISK: none
NEXT_ACTION: Start a unit of work with /run-pipeline aidlc/unit-of-work "<request>"
NEXT_ACTION_OWNER: human:any
NEXT_ACTION_INPUTS: none
DONE: none
EVIDENCE: none
OPEN_RISKS: none

## Phases
| Phase | Stage | Tier | Profile | Risk | Last decision |
| --- | --- | --- | --- | --- | --- |
