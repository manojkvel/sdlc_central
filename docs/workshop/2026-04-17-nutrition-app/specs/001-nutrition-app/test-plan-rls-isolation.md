# Test Plan — RLS Isolation (TASK-003)

> **Skill:** `test-gen` | **Author:** Anita (QA) | **Date:** 2026-04-17
> **Source task:** TASK-003 (Adversarial RLS test harness)
> **Traces to:** AC-5, AC-7, BR-1, BR-2, BR-5
> **Risk addressed:** plan §6 — *RLS policy bug allows cross-student read* (CRITICAL severity)

This is the deepest test in the suite by intent. If RLS ever weakens, this file should scream — even before any application-layer code is exercised.

---

## 1. Threat model under test

| Adversary | Goal | Defence under test |
|-----------|------|--------------------|
| Student A with valid JWT | Read student B's meal logs | RLS policy + `current_setting('app.user_id')` |
| Parent of student A | Read student B (no link) | RLS `parent_view_linked` policy with `consent_status = active` check |
| Parent with revoked consent | Read previously-linked student | RLS policy must check `consent_status` at query time |
| Cafeteria staff | Read individual student rows | RLS `staff_aggregate_only` policy |
| Compromised JWT (forged claims) | Read any student | App-layer JWT validation + RLS as backstop |

---

## 2. Test cases (12)

### Group A — Student isolation
| # | Setup | Action | Expected | Maps to |
|---|-------|--------|----------|---------|
| A1 | Session set as student_001 | `SELECT * FROM students WHERE id = student_002` | 0 rows | AC-5, BR-1 |
| A2 | Session as student_001 | `SELECT * FROM meal_logs WHERE student_id = student_002` | 0 rows | AC-5, BR-1 |
| A3 | Session as student_001 | `UPDATE students SET grade = 8 WHERE id = student_002` | 0 rows updated, no error | BR-1 |
| A4 | Session as student_001 | `INSERT INTO meal_logs (student_id, ...) VALUES (student_002, ...)` | RLS WITH CHECK violation → 42501 | BR-1 |

### Group B — Parent boundary
| # | Setup | Action | Expected | Maps to |
|---|-------|--------|----------|---------|
| B1 | Parent_A linked to student_001 (active) | `SELECT * FROM students WHERE id = student_001` | 1 row | AC-5 |
| B2 | Parent_A NOT linked to student_002 | `SELECT * FROM students WHERE id = student_002` | 0 rows | AC-5, BR-5 |
| B3 | Parent_A linked to student_001 with `consent_status = 'revoked'` | `SELECT * FROM meal_logs WHERE student_id = student_001` | 0 rows | BR-2, BR-5 |
| B4 | Parent_A linked active | `UPDATE meal_logs SET calories = 0 WHERE student_id = student_001` | 0 rows updated (parent role is SELECT-only) | BR-5 |

### Group C — Staff scope
| # | Setup | Action | Expected | Maps to |
|---|-------|--------|----------|---------|
| C1 | Staff session WITHOUT `app.aggregate_query=true` | `SELECT * FROM students LIMIT 1` | 0 rows | BR-1 |
| C2 | Staff session WITH `app.aggregate_query=true` | `SELECT count(*) FROM students` | scalar count | (analytics path) |
| C3 | Staff session | `SELECT * FROM meal_logs WHERE student_id = student_001` | 0 rows | BR-1 |

### Group D — Forged-JWT attack
| # | Setup | Action | Expected | Maps to |
|---|-------|--------|----------|---------|
| D1 | JWT claims `user_id=student_002`, but DB session GUC set to `student_001` (simulates app-layer bug) | `SELECT * FROM students` | returns student_001 only — RLS wins regardless of forged claim | AC-7 + plan §6 CRITICAL |

---

## 3. Pytest skeleton (excerpt)

```python
# apps/api/tests/security/test_rls_isolation.py
import pytest
from sqlalchemy import text
from tests.fixtures.identities import as_student, as_parent, as_staff

@pytest.mark.parametrize("attacker, victim", [
    ("student_001", "student_002"),
    ("student_002", "student_001"),
])
def test_student_cannot_read_other_student(db_session, attacker, victim):
    with as_student(db_session, attacker):
        rows = db_session.execute(
            text("SELECT id FROM students WHERE id = :v"),
            {"v": victim},
        ).fetchall()
    assert rows == [], f"{attacker} read {victim} — RLS BREACH"

def test_revoked_parent_cannot_read_logs(db_session):
    # Setup: parent_A linked to student_001 then revoked
    set_consent_status(db_session, "parent_A", "student_001", "revoked")
    with as_parent(db_session, "parent_A"):
        rows = db_session.execute(
            text("SELECT count(*) FROM meal_logs WHERE student_id = 'student_001'"),
        ).scalar()
    assert rows == 0

def test_forged_jwt_loses_to_rls(db_session):
    # JWT claims student_002 but session GUC set to student_001 (simulated app bug)
    db_session.execute(text("SET LOCAL app.user_id = 'student_001'"))
    db_session.execute(text("SET LOCAL app.role = 'student'"))
    rows = db_session.execute(text("SELECT id FROM students")).fetchall()
    assert all(r.id == "student_001" for r in rows)
```

## 4. CI integration

- Marked with `@pytest.mark.security` so we can run the security subset in <5 s on every PR.
- Failure of any case in this file blocks merge — wired into the `impl-to-release` gate (`max_critical_findings: 0`).

## 5. Out of scope (call-outs)

- This file does NOT test JWT validity itself — that lives in TASK-005 (authn integration tests).
- This file does NOT exercise consent flow happy-path — that lives in TASK-009.
- Penetration testing (manual probe by external firm) is scheduled for Phase 7 + a re-run pre-launch — out of scope here.

---
*Generated by `test-gen`. Plays at gate `impl-to-release` under `require_security_audit: true`.*
