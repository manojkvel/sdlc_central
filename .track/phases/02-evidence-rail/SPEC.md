# Phase 2 — evidence rail

Source: AIDLC Framework PRD, phase 2 (FR-B1 to FR-B6, FR-D4); Conversion Technical Guide, evidence rail.

## Acceptance criteria
- AC-1: every test, build and lint run can be recorded per task with its output, exit code and the hashes of the files it touched (FR-B1)
- AC-2: VERIFICATION.md is generated, maps every AC and SC to evidence, and fails closed when a criterion has none (FR-B2)
- AC-3: deleting or altering an evidence log fails the criterion it covered
- AC-4: editing source after its evidence marks the evidence stale, and stale evidence does not count (FR-B4)
- AC-5: the suite is re-executed once and a disagreement fails verification (FR-B3)
- AC-6: a hand-written or hand-edited VERIFICATION.md is rejected (W08, C05, H05 seal)
- AC-7: release readiness and the final-verification hook require sealed, complete, fresh evidence (FR-B5)
- AC-8: tier 1 records evidence but does not require VERIFICATION.md (FR-D4)
- AC-9: UAT evidence is recorded and reported the same way (FR-B6)
