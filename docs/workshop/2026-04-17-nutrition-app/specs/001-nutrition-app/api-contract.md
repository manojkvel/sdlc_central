# API Contract Check — NutriKids (001)

> **Skill:** `api-contract-analyzer` | **Auditor:** Vikram | **Date:** 2026-04-17 (workshop sim)
> **Triggered by:** `impl-to-release` strict profile requirement `require_api_contract_check: true`

## Inputs
- `apps/api/openapi.json` (generated from FastAPI at boot)
- `packages/domain/src/openapi-baseline.json` (last-released contract — empty for v1; this is first release)

## Coverage

| Endpoint | Methods | Documented | Auth-tagged | Schema strict |
|----------|---------|-----------|-------------|---------------|
| `/v1/auth/callback` | GET | ✓ | OIDC | ✓ |
| `/v1/consent/sso/acknowledge` | POST | ✓ | required | ✓ |
| `/v1/consent/wet-signature/upload` | POST | ✓ | staff-only | ✓ |
| `/v1/meals/batch` | POST | ✓ | student | ✓ |
| `/v1/meals/from-menu/{menu_version_id}` | POST | ✓ | student | ✓ |
| `/v1/dashboard/{student_id}` | GET | ✓ | student/parent | ✓ (post SEC-002 fix) |
| `/v1/cafeteria/menus/publish` | POST | ✓ | staff | ✓ |
| `/v1/cafeteria/menus/{date}` | GET | ✓ | any auth | ✓ |
| `/v1/badges/weekly/{student_id}` | GET | ✓ | student/parent | ✓ |
| `/v1/coppa/delete-request` | POST | ✓ | parent or admin | ✓ |

10/10 endpoints documented, all auth-tagged, all schemas use `additionalProperties: false`.

## Backwards-compatibility check
N/A — first release.

## Spec-vs-impl drift check
For each endpoint, the route handler signature was compared to the OpenAPI schema. **0 drifts.**

## Findings
- API-001 (LOW): `/v1/coppa/delete-request` doesn't include a 202 + polling pattern — completes synchronously. Acceptable for v1 (low traffic) but flagged for future scaling.

## Verdict
**PASS.** Strict gate requirement satisfied.
