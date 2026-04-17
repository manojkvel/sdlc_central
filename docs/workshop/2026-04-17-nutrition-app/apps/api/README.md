# NutriKids API — Phase 1 (Foundation)

Real code produced by the workshop roleplay for tasks **TASK-001**, **TASK-002**, **TASK-003**.

## What's in here

- `alembic/versions/0001_initial.py` — schema + Postgres row-level security (RLS) policies for `students` and `parent_child_links`. This is the primary tenant-isolation boundary (plan AD-2).
- `src/nutrikids/db/session.py` — SQLAlchemy engine + session factory with an `after_begin` listener that sets `app.user_id`, `app.role`, and `app.aggregate_query` GUCs from the current request context. This is how RLS policies see the right identity.
- `src/nutrikids/db/seed.py` — idempotent dev seed (6 students, 4 parents, 3 active + 1 revoked + 1 pending link, 2 staff).
- `src/nutrikids/auth/context.py` — `contextvars`-backed request context (replaces the JWT middleware that will ship in TASK-004).
- `tests/security/test_rls_isolation.py` — **TASK-003**: 10 adversarial test cases including a forged-JWT scenario. Marked `@pytest.mark.security` — CI must block release on any failure here.
- `docker-compose.yml` — Postgres 16 for dev (`:5432`) and test (`:5433`).

## Run the tests

```bash
cd docs/workshop/2026-04-17-nutrition-app/apps/api
make install          # pip install -e '.[dev]'
make up               # docker compose up -d (dev + test postgres)
make test             # runs the adversarial RLS suite
```

Expected output:

```
tests/security/test_rls_isolation.py::TestStudentIsolation::... PASSED
tests/security/test_rls_isolation.py::TestParentBoundary::... PASSED
tests/security/test_rls_isolation.py::TestStaffScope::... PASSED
tests/security/test_rls_isolation.py::TestForgedJWT::test_forged_claim_loses_to_db_guc PASSED
```

## How this maps to the roleplay

| Artefact | Stage | File(s) |
|----------|-------|---------|
| spec.md AC-5 (parent view) | PO | drives migration's `parent_view_linked` policy |
| spec.md AC-7 (SSO auth boundary) | PO | drives the `app.role` GUC convention |
| plan.md AD-2 (RLS as primary isolation) | Architect | `0001_initial.py` uses `FORCE ROW LEVEL SECURITY` |
| plan.md AD-3 (OIDC) | Architect | `auth/context.py` is the seam; TASK-004 fills in JWT validation |
| tasks.md TASK-002 | Dev | migration + session listener + seed |
| tasks.md TASK-003 | Dev | `tests/security/test_rls_isolation.py` |
| spec-compliance.md F-3 (BR-4 immutability) | QA | NOT addressed here — still pending for Phase 2 |
| security-audit.md SEC-001 (consent_audit_log) | Security | `consent_audit_log.parent_email_hash` (not plaintext) reflects the fix proposed in `review-fix-loop.md` round 1 |

## What this vertical slice does NOT include

Per the wave schedule, the following tasks are **not** in this commit — they depend on TASK-002 and are scheduled in later waves:

- TASK-004 (OIDC middleware)
- TASK-006/007/008 (consent flow — dual-build under `consent.mechanism` flag)
- TASK-010+ (meal logs, dashboard, menu, badges, clients)

The web and mobile clients (`apps/web`, `apps/mobile`) are not scaffolded here either.

---

*Produced by the 2026-04-17 NutriKids workshop roleplay. See `../../run-log.md` for the full flow.*
