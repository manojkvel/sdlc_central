# Governance scorecard and release

`hooks/_bin/aidlc-scorecard.sh` (skill `/governance-scorecard`, persona aidlc-governance-reviewer)
decides whether a phase may reach `APPROVE RELEASE`. Binary, computed, sealed.

| # | Dimension | Passes when | Owner of a failure |
| --- | --- | --- | --- |
| D1 | Requirements & traceability | traceability check returns T00 | aidlc-plan-checker (architect) |
| D2 | Artifact completeness & hygiene | artifacts required by tier and profile exist; hygiene clean | aidlc-delivery-manager |
| D3 | Human approval audit | every HITL gate before release has an accepted HD record for the phase; consistency X00 | aidlc-governance-reviewer (tech lead) |
| D4 | Evidence rail proof | VERIFICATION.md sealed, COMPLETE, no stale evidence | aidlc-verifier (developer / QA) |
| D5 | Contract & workstream alignment | tier 3: consumed contracts APPROVED, no release-claims exclusion | aidlc-governance-reviewer (architect) |
| D6 | Security, NFR & risk | REVIEW.md with no open CRITICAL/HIGH; every open risk signed by an HD | aidlc-security-standards-reviewer |

Required artifacts: tier 1 `unit.md`; tier 2 `SPEC, PLAN, PLAN_CHECK, TASKS, VERIFICATION, REVIEW`;
tier 3 adds `TECHNICAL_DESIGN` (and `CONTRACT_EVIDENCE` when the unit produces a contract);
the work-type profile in `config/profiles.yaml` adds or skips artifacts.

Output: `<phase>/SCORECARD.md`, first line `<!-- generated-by: aidlc-scorecard sha256:<hash> -->`,
ending `## GOVERNANCE APPROVED` or `## GOVERNANCE BLOCKED`; an entry in `gate-history.json`
(`type: release-scorecard`) that the metrics use for first-pass rate. Hand writes are blocked
(W08, C05) and hand edits detected (H05); `git tag` and deploys need the sealed, approved
scorecard (F03).

Asserted identity at high or release risk is reported as advisory in D3. It becomes blocking when
the decision bot (phase 4) provides authenticated identity.

## Release role and pipelines

- Role `release-manager` (`install-role.sh release-manager`): governance-scorecard,
  release-readiness-checker, rollback-assessor, gate-briefing, release-notes,
  aidlc-evidence-verifier, risk-tracker, aidlc-decision-guard, quality-gate, changelog-plain,
  aidlc-metrics-extract; template `templates/CLAUDE.md.release-manager`.
- `release-manager/integration-release`: scorecard → rollback-assessor → release-readiness-checker →
  APPROVE RELEASE checkpoint → release-notes.
- `product-owner/release-signoff` and `qa/release-validation` run the scorecard before their release gate.
- `quality-gate` transition `release-scorecard`.
