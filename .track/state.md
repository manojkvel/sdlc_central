# Project state

The runner rewrites the AIDLC_RESUME block after every step. The approval guard
edits BLOCKED_GATE, GATE_RISK and NEXT_ACTION* when a decision is recorded.
Agents never edit this block by hand. Schema: config/schemas/state-resume.schema.json.

## AIDLC_RESUME
CURRENT_PHASE: 01-control-audit-rails
CURRENT_STAGE: review
BLOCKED_GATE: none
GATE_RISK: none
NEXT_ACTION: Review phase 1 on branch aidlc_framework; decide the open items in docs/aidlc/design-invariants.md
NEXT_ACTION_OWNER: human:tech-lead
NEXT_ACTION_INPUTS: docs/aidlc/design-invariants.md, docs/aidlc/hooks.md
DONE: hooks(8), schemas(4), gate-config, profiles, installers, init-track, migrate-specs, runner, plan-check, tests
EVIDENCE: hooks/_test/run.sh 80/80; tests/aidlc-phase1.test.js 46/46; comprehensive_test.sh 80/80
OPEN_RISKS: none

## Phases
| Phase | Stage | Tier | Profile | Risk | Last decision |
| --- | --- | --- | --- | --- | --- |
| 01-control-audit-rails | review | 2 | feature | medium | none |
