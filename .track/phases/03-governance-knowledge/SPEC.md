# Phase 3 — scorecard, personas, metrics, knowledge, console

Source: AIDLC Framework PRD phase 3 (FR-F1..F6, FR-A4, FR-G1, FR-G2, FR-G4); Conversion Technical Guide persona, metrics, knowledge and management UI layers.

## Acceptance criteria
- AC-1: the scorecard blocks naming the exact dimension and owner when any input is missing, and approves when all six pass (FR-F1, FR-F2)
- AC-2: SCORECARD.md is sealed, cannot be hand-written or edited, and release commands need the approved one (FR-F3, FR-F5)
- AC-3: install-role release-manager installs its skills, the integration-release pipeline and its template; release pipelines run the scorecard first (FR-G1, FR-F6)
- AC-4: eight personas ship in the universal format and are emitted natively per agent (guide persona layer)
- AC-5: metrics are computed from artifacts with counts, nulls where unmeasured, and per-squad baselines; first-pass rate comes from gate history (FR-G4)
- AC-6: the wiki is linted for citations, ownership, freshness and contradictions, and indexed for search (guide knowledge layer)
- AC-7: a read-only, self-contained console is built from the track root, and repos merge into a department view (guide management UI)
- AC-8: installed hooks are verifiable against a manifest, and overdue gates escalate by SLA (design recommendations)
- AC-9: the catalog lists every skill once with agents and hooks, and every test role list includes release-manager
