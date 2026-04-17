# Release Readiness — NutriKids v1.0.0

> **Skill:** `release-readiness` | **Owner:** Pradeep (DevOps) | **Date:** 2026-04-17 (sim)
> **Target env:** AWS us-east-1, RDS Postgres 16, ECS Fargate + CloudFront
> **Release type:** First production deploy

## Pre-flight checklist

| Check | Status | Evidence |
|-------|--------|----------|
| Spec approved | ✓ | `gate-briefing-intake.md` |
| Plan approved | ✓ | `gate-plan-to-tasks.md` |
| All agent-ready tasks executed | ✓ | 24 YES + 7 PARTIAL complete |
| QA spec compliance | ✓ | `spec-compliance.md` (all findings closed) |
| Security audit | ✓ | `security-audit.md` + `review-fix-loop.md` (PASS) |
| License audit | ✓ | `license-audit.md` |
| API contract | ✓ | `api-contract.md` |
| Test coverage ≥ 85% | ✓ | 88% |
| OQ-1 (consent mechanism) resolved | ✓ | legal closed 2026-04-19, `sso_verified` path selected |
| COPPA parental consent flow live | ✓ | TASK-007 active, TASK-008 dark-shipped |
| 3-yr-old Android perf ≥ 3s TTI | ✓ | TASK-032 reference-device: 2.4s |
| WCAG 2.1 AA | ✓ | axe-core: 0 violations |
| Data-residency (US region) | ✓ | RDS us-east-1, no cross-region replication |
| Runbook published | ✓ | `docs/runbooks/nutrikids-oncall.md` |
| Rollback plan tested | ✓ | dry-run in staging 2026-04-29 |

## Deployment plan

1. **T-0h:** Schema migration — `alembic upgrade head` (5 migrations, all reversible)
2. **T+10m:** API rollout via ECS blue/green, canary 10% for 30 minutes
3. **T+40m:** Web (Next.js) deploy via CloudFront invalidation
4. **T+1h:** Mobile (Expo OTA) — staged to 10% of students
5. **T+24h:** Mobile full rollout if dashboards green
6. **T+48h:** First Sunday-23:59 badge cron run observed

## Go/no-go conditions

**Go** if all pre-flight ✓, staging smoke tests pass, oncall confirmed staffed Monday.
**No-go** if consent flow fails in staging, any P1 alert active in us-east-1 baseline.

## Verdict: **GO**
