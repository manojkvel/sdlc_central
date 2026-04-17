# Deploy Verify — NutriKids v1.0.0

> **Skill:** `deploy-verify` | **Run by:** Pradeep | **Date:** 2026-05-02T14:00Z (sim)
> **Verifies:** production deploy meets the spec's acceptance criteria under real traffic

## Smoke suite

| Check | Endpoint / surface | Result |
|-------|--------------------|--------|
| Health | `GET /healthz` | 200, <50ms |
| DB connectivity | migration version = 0011 | ✓ |
| OIDC flow | student login end-to-end via test account | ✓ |
| RLS live probe | forged-context SELECT returns 0 | ✓ |
| Meal log happy path | `POST /v1/meals/batch` from staging student account | 201 |
| Offline replay | airplane-mode → online → sync in 18s | ✓ (AC-2 budget = 60s) |
| Dashboard | `GET /v1/dashboard/{me}` matches logs | ✓ |
| Cafeteria publish | staff account publishes a menu | 201, version_id incremented |
| 1-tap from menu | student logs via menu | 201 |
| Parent view (SSO) | parent logs in, sees linked child only | ✓ |
| Delete-request | submit + verify table scan | ✓, 0 PII survivors |
| Badge cron | manually trigger Sunday job | 0 errors, expected badge counts |

## Canary metrics (first 30 min @ 10%)

- p95 latency `/v1/meals/batch`: 142ms (budget 400ms) ✓
- p95 latency `/v1/dashboard/*`: 210ms ✓
- Error rate: 0.04% (budget 1%) ✓
- Offline sync success: 99.8% ✓

## Promotion
Canary → 100% at T+40m. No regression, no P1 alert.

## Post-deploy

| Action | Status |
|--------|--------|
| Update feature flag `consent.mechanism = sso_verified` | ✓ |
| Announcement in school Slack + parent newsletter | ✓ |
| On-call handoff doc linked in runbook | ✓ |
| Schedule 7-day post-release review | 2026-05-09 |

## Verdict: **DEPLOY VERIFIED**
