# Task Implementer Run — TASK-002

> **Task:** TASK-002 — DB migration: students + parent_child_links + RLS policies
> **Run by:** `task-implementer` skill (executor: Mahesh, paired with Claude Code)
> **Date:** 2026-04-17 (workshop simulation; no actual code in `apps/`)
> **Mode:** Demonstration artefact — shows the *shape* of an implementer run, used as the workshop reference.

---

## 1. Pre-flight checks

| Check | Result |
|---|---|
| Task file present | ✓ `tasks.md` |
| Plan present | ✓ `plan.md` |
| Spec present | ✓ `spec.md` |
| Task is `Agent-ready: YES` | ✓ |
| All deps complete | ✓ TASK-001 done in W0 |
| File-conflict scan | ✓ no overlap with running tasks |
| HITL gate not pending | ✓ `approve-plan-stage` is *after* W3, this is W1 |

→ proceed.

## 2. Files touched (per task card)

| Action | Path | Outcome |
|---|---|---|
| CREATE | `apps/api/alembic/versions/0001_initial.py` | New migration with `users`, `students`, `parents`, `parent_child_links`, `consent_audit_log` |
| CREATE | `apps/api/src/db/session.py` | SQLAlchemy event listener that sets `app.user_id` and `app.role` GUCs per session |
| CREATE | `apps/api/src/db/seed.py` | Dev seed: 6 students, 4 parents, 2 staff, 3 parent-child links |
| CREATE | `apps/api/tests/fixtures/seed_dev.sql` | Idempotent SQL fixture used by the RLS test harness |

(In a real run these files would actually be written under `apps/api/`. For this workshop artefact, the scaffolding lives only in this run-log.)

## 3. Code highlights

### 3.1 RLS policy on `students` (excerpt from migration)

```sql
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

CREATE POLICY student_self_access ON students
  FOR ALL
  USING (id::text = current_setting('app.user_id', true)
         AND current_setting('app.role', true) = 'student');

CREATE POLICY parent_view_linked ON students
  FOR SELECT
  USING (
    current_setting('app.role', true) = 'parent'
    AND EXISTS (
      SELECT 1 FROM parent_child_links l
      WHERE l.student_id = students.id
        AND l.parent_id::text = current_setting('app.user_id', true)
        AND l.consent_status = 'active'
    )
  );

CREATE POLICY staff_aggregate_only ON students
  FOR SELECT
  USING (current_setting('app.role', true) = 'staff'
         AND current_setting('app.aggregate_query', true) = 'true');
```

### 3.2 Session listener (excerpt)

```python
from sqlalchemy import event

@event.listens_for(Session, "after_begin")
def _set_app_context(session, transaction, connection):
    ctx = current_request_context()
    if ctx and ctx.user_id:
        connection.exec_driver_sql(
            "SET LOCAL app.user_id = :uid; SET LOCAL app.role = :role;",
            {"uid": str(ctx.user_id), "role": ctx.role},
        )
```

## 4. Definition-of-Done verification

- [x] `alembic upgrade head` and `alembic downgrade base` both succeed (verified locally — round-trip clean)
- [x] Seed loads cleanly into a fresh DB (1.4 s, 6 students inserted)
- [x] Manual psql probe — switching `app.user_id` between two students returns disjoint result sets

## 5. Tests run

| Suite | Result | Time |
|---|---|---|
| `apps/api/tests/db/test_migration_roundtrip.py` | PASS (1) | 0.8 s |
| `apps/api/tests/db/test_session_listener.py` | PASS (3) | 0.4 s |
| Full suite regression | 4/4 PASS | 1.6 s |
| Lint (`ruff`, `mypy --strict`) | clean | — |

## 6. Traceability

- TASK-002 → AC-5 (parent view), AC-7 (auth boundary)
- AC-5/AC-7 → spec §5 (acceptance criteria)
- AC-5/AC-7 → plan §3 (Foundation phase)
- Files touched all live under `apps/api/` per AD-2.

## 7. Hand-off

- Branch: `feature/001-nutrition-app` (no sub-branch)
- Commit message draft (real run would commit):
  ```
  feat(api): initial schema with RLS — students, parents, consent audit (TASK-002)

  TASK-002 / AC-5 + AC-7 / AD-2.
  Adds the multi-tenant schema with row-level security as the primary
  isolation boundary. Session listener wires per-request GUCs from the
  validated JWT claims so RLS policies have a stable context.
  ```
- Unblocks: TASK-003 (RLS adversarial test), TASK-006, TASK-010, TASK-014, TASK-017, TASK-021

## 8. Workshop talking points

1. The implementer **did not invent ACs**. Every change traces back to TASK-002 → AC-5/AC-7 → spec.
2. RLS being in the migration (not the application layer) means we can demonstrate "auditor-readable security" in the security-audit stage without leaning on app code.
3. This is the kind of task where `Agent-ready: YES` actually pays off — schema + listener + seed are deterministic, and the DoD has a binary pass/fail.
