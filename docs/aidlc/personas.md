# AIDLC personas

Eight built-in personas, defined once in `agents/<name>/agent.yaml` + `prompt.md` and emitted
per agent by the installers. A persona is a constrained context: the skills it may use, what it
reads, what it may write, and the completion markers it must end with.

| Persona | Stages | Skills | Writes | Markers |
| --- | --- | --- | --- | --- |
| aidlc-orchestrator | routing | run-pipeline, quality-gate, gate-briefing, auto-triage, aidlc-decision-guard | state.md, lineage.md, runs/, roadmap.md | ROUTE READY · CHECKPOINT REQUIRED · GATE BLOCKED |
| aidlc-product-strategist | intake, spec | feature-balance-sheet, user-story-refiner, spec-gen, scope-tracker | requirements.md, SPEC.md | STRATEGY READY · CHECKPOINT REQUIRED |
| aidlc-domain-expert | source, spec | source-extract, codebase-qa, spec-review, board-sync | CONTEXT.md, SPEC.md, wiki | CONTEXT READY · CONTEXT GAPS |
| aidlc-plan-checker | planning | plan-check, impact-analysis, risk-tracker | PLAN_CHECK.md | PLAN CHECK PASSED · GATE BLOCKED |
| aidlc-delivery-manager | execution, released | pipeline-monitor, progress-summary, drift-detector, board-sync, wave-scheduler, aidlc-metrics-extract, doc-gen, release-notes | roadmap.md, docs/aidlc | DELIVERY STATUS · CHECKPOINT REQUIRED |
| aidlc-verifier | verification | aidlc-evidence-verifier, regression-check, test-gen | VERIFICATION.md, UAT.md, CONTRACT_EVIDENCE.md | VERIFICATION COMPLETE · VERIFICATION FAILED |
| aidlc-governance-reviewer | governance | governance-scorecard, aidlc-decision-guard, release-readiness-checker, rollback-assessor, release-notes | SCORECARD.md, gate-history.json | GOVERNANCE APPROVED · GOVERNANCE BLOCKED |
| aidlc-security-standards-reviewer | design, review | security-audit, security-audit-deep, design-review, license-compliance-audit, risk-tracker, review | REVIEW.md, risks.md | SECURITY REVIEW CLEAR · SECURITY REVIEW BLOCKED |

The orchestrator's routing table (in its prompt) maps each stage and marker to the next persona.
Output without a completion marker is treated as `## AIDLC GATE BLOCKED`.

## Output per agent

| Agent | File | Notes |
| --- | --- | --- |
| claude-code | `.claude/agents/<name>.md` | Subagent frontmatter: `name`, `description`, `tools` (plain tool names), `model` from `adapters/claude-code/model-mappings.yaml` (reasoning → opus, standard → sonnet, fast → haiku) |
| cursor | `.cursor/rules/<name>.mdc` | `alwaysApply: false`; invoke by rule reference |
| copilot | `.github/agents/<name>.agent.md` | Custom agent |
| others | `.sdlc/agents/<name>.md` + `README.md` index | Advisory: the model adopts a persona by reading its file |

## Known limit

The write manifests (`writes:`) are enforced by prompt only. The hooks cannot tell which persona
is writing, so hygiene code H04 stays reserved until an agent passes persona identity in its hook
payload. The hard guarantees that do not depend on persona identity (W05, W07, W08, C03-C05, H05)
are enforced for every writer.
