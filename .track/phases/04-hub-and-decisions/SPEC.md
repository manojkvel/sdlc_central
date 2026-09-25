# Phase 4 — hub-and-spoke contracts and decision bot

Source: AIDLC Framework PRD phase 4 (FR-E1..E6, FR-C4); Conversion Technical Guide hub-and-spoke, management UI write path, design recommendations (identity).

## Acceptance criteria
- AC-1: a hub registers workstreams and DRAFT contracts and regenerates the registry and dependency map (FR-E1, FR-E2)
- AC-2: a tier 3 consumer is blocked from source writes while a consumed contract is DRAFT, BREACHED or unregistered (FR-E4, W09)
- AC-3: a WITH RISK contract decision lets the consumer build with release claims excluded; a plain approval needs a green contract test (FR-E4)
- AC-4: a green test verifies a risk-accepted contract, and LIFT EXCLUSION restores the consumer's release claims
- AC-5: a producer change that breaks an approved contract marks it BREACHED and blocks consumers until restored (FR-E5)
- AC-6: the scorecard's D5 reflects contract status and exclusions; approved-artifact detection ignores registry-maintained fields only
- AC-7: the decision bot records authenticated decisions through the same guard, refuses gate races and unauthorised deciders (A06), and can make authenticated identity mandatory at high and release risk (A05)
- AC-8: plan-gen, design-review, spec-gen and api-contract-analyzer carry the tier 3 and REQ rules (FR-E5, FR-E6, FR-C4)
