# Review-Fix Loop — Round 1

> **Skill:** `review-fix` | **Date:** 2026-04-17
> **Triggered by:** `impl-to-release` gate FAIL (security-audit.md)
> **Inputs:** `security-audit.md` findings SEC-001 (CRITICAL), SEC-002 (HIGH)
> **Loop budget:** 3 attempts before HITL escalation

This is the workshop's hero artefact for the recursive recovery story. It shows that finding → patch → re-test → re-gate is a tight loop, not a manual ticket-shuffle.

---

## Round 1 — Attempt 1

### SEC-001 — CRITICAL — Patch proposal

**Diff plan:**

```
apps/api/alembic/versions/0011_redact_consent_audit.py    [CREATE]
apps/api/src/consent/audit.py                              [MODIFY: hash email at write]
apps/api/src/coppa/delete.py                               [MODIFY: assert no plaintext email after delete]
apps/api/tests/security/test_coppa_deletion.py             [MODIFY: add assertion for hashed-only]
```

**Patch summary:**
1. New migration redacts existing `consent_audit_log.parent_email` → `parent_email_hash` (HMAC-SHA256, salt from KMS).
2. Write path now hashes at insert; column `parent_email` dropped after backfill.
3. COPPA delete path now asserts via `pg_class` introspection that no remaining column carries the email value.
4. `test_coppa_deletion.py` adds: after delete, scan all tables for the deleted email value; expect 0 hits.

**Verification:**
- `pytest -m security` → 27/27 PASS (was 26/27)
- `coverage` → 88% (+1)

### SEC-002 — HIGH — Patch proposal

**Diff plan:**

```
apps/api/src/dashboard/router.py                           [MODIFY: enforce path == JWT user_id or linked]
apps/api/tests/api/test_dashboard_authz.py                 [CREATE]
```

**Patch summary:**
1. Add `_assert_student_accessible(jwt, student_id)` guard at handler entry.
2. Returns 404 (not 403) for non-linked → indistinguishable from non-existent.
3. New test covers: student-self, parent-linked, parent-not-linked, parent-revoked, staff-aggregate-path.

**Verification:**
- `pytest tests/api/test_dashboard_authz.py` → 5/5 PASS
- Manual probe via `httpie` confirms 404 on non-linked.

---

## Round 1 — Re-run security-audit

| Finding | Round 1 result |
|---------|---------------|
| SEC-001 | **RESOLVED** (rerun confirms no plaintext email survives delete) |
| SEC-002 | **RESOLVED** (404 on non-linked path; response shape no longer leaks) |
| SEC-003 (MED) | OPEN — assigned to Karan, deferred to next wave |
| SEC-004 (MED) | OPEN — assigned to Mahesh, deferred to next wave |
| SEC-005 (LOW) | INFO only |
| SEC-006 (LOW) | OPEN — deferred |

## Round 1 — Re-run impl-to-release gate (strict)

| Threshold | Required | Actual | Pass? |
|-----------|----------|--------|-------|
| `max_critical_findings` | 0 | 0 | ✓ |
| `max_high_findings` | 0 | 0 | ✓ |
| `min_test_coverage_percent` | 85 | 88 | ✓ |
| `require_spec_compliance` | true | ✓ | ✓ |
| `require_security_audit` | true | ✓ | ✓ |
| `require_license_audit` | true | **MISSING** | ✗ |
| `require_api_contract_check` | true | **MISSING** | ✗ |

**Verdict: STILL FAIL** — but for a different reason now (license + API contract checks not yet run). This is the loop signalling the workshop a real gap: the strict profile demands two checks that no pipeline currently invokes (matches finding #5 in `03-pipeline-test-report.md`).

## Round 2 — Mahesh runs the missing audits

- `license-compliance-audit` skill on the dependency tree → output: `license-audit.md`
- `api-contract-analyzer` on the OpenAPI spec → output: `api-contract.md`

(See Stage F artefacts.)

After both audits pass cleanly, the gate is re-evaluated → **PASS**.

---

## Loop summary

| Round | Findings opened | Findings closed | Gate verdict | Patches authored |
|-------|----------------|-----------------|--------------|------------------|
| 0 (audit) | 6 | 0 | FAIL (1 CRIT, 1 HIGH) | — |
| 1 (review-fix) | 0 | 2 | FAIL (gap: 2 missing audits) | 6 files / ~120 LOC |
| 2 (run missing audits) | 0 | 2 | **PASS** | 0 (gap was process, not code) |

**Loop budget used:** 2 of 3 attempts. No HITL escalation needed.

## Workshop talking points

1. The loop is **scoped** — it doesn't endlessly retry. After 3 attempts it escalates.
2. Round 1 fixed two findings but the gate failed for a *new* reason (missing audits). This is the system being honest: the gate is the source of truth, not the auditor's word.
3. The "missing audit" gap matched a finding from the dry-run pipeline test report — proof that the simulated test caught a real workshop talking point.
4. License + API-contract audits are demonstrated as **separate skills**, not bundled. This keeps the audit findings independently triageable.

---
*Output gate state: PASS. Handoff to DevOps (Vikram → Pradeep) for release.*
