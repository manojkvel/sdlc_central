<!-- generated-by: aidlc-evidence-verifier sha256:2c8b695582d97f080722418f30e22e260453fe5838da857b93c4e5ce2770ef75 -->
# VERIFICATION — 03-governance-knowledge

## Summary
- **Result:** COMPLETE
- **Criteria:** 9 pass, 0 fail, of 9
- **Stale evidence entries:** 2
- **Evidence index:** `evidence/index.json` sha256:43d91898b28976d617163a79cfbc97cf583fa6d1d86cae24af501e362aa0e689
- **Spec:** `SPEC.md` sha256:348a0ee2e08c74aeaea8a60c550e14010763a6ddf452c4bb2122c2120ad4f1e6
- **Mode:** verify · **Tier:** 2 · **Generated:** 2026-09-24T19:27:55Z

Claims under review (from SUMMARY.md, not evidence): none

## Criteria

| Criterion | Description | Result | Evidence | Notes |
| --- | --- | --- | --- | --- |
| AC-1 | the scorecard blocks naming the exact dimension and owner when any inp | PASS | E-012 (TASK-001, exit 0), E-011 (TASK-001, exit 0) | fresh, exit 0 |
| AC-2 | SCORECARD.md is sealed, cannot be hand-written or edited, and release  | PASS | E-012 (TASK-001, exit 0), E-011 (TASK-001, exit 0) | fresh, exit 0 |
| AC-3 | install-role release-manager installs its skills, the integration-rele | PASS | E-004 (TASK-002, exit 0) | fresh, exit 0 |
| AC-4 | eight personas ship in the universal format and are emitted natively p | PASS | E-002 (TASK-003, exit 0) | fresh, exit 0 |
| AC-5 | metrics are computed from artifacts with counts, nulls where unmeasure | PASS | E-006 (TASK-004, exit 0) | fresh, exit 0 |
| AC-6 | the wiki is linted for citations, ownership, freshness and contradicti | PASS | E-007 (TASK-005, exit 0) | fresh, exit 0 |
| AC-7 | a read-only, self-contained console is built from the track root, and  | PASS | E-008 (TASK-006, exit 0) | fresh, exit 0 |
| AC-8 | installed hooks are verifiable against a manifest, and overdue gates e | PASS | E-009 (TASK-007, exit 0) | fresh, exit 0 |
| AC-9 | the catalog lists every skill once with agents and hooks, and every te | PASS | E-005 (TASK-008, exit 0) | fresh, exit 0 |
| RERUN | `node --test tests/aidlc-phase3.test.js` | PASS | .track/phases/03-governance-knowledge/evidence/_verify/rerun-20260924T192744Z.out | fresh run agrees with recorded evidence |

## Rejected evidence

These entries mask their own exit code, so they cannot fail and do not count:
- E-003 (TASK-008): `node --test --test-name-pattern="Registry integrity" tests/aidlc-phase3.test.js tests/skill-manifest.test.js; exit 0`

## VERIFICATION COMPLETE
