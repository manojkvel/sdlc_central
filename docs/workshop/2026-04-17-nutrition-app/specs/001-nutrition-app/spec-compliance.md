# Spec Compliance Review — NutriKids (001)

> **Skill:** `spec-review` | **Reviewer:** Anita (QA) | **Date:** 2026-04-17
> **Inputs reviewed:** `spec.md`, `plan.md`, `decision-log.md`, `tasks.md`, `wave-schedule.md`
> **Profile:** standard (will re-run under `strict` at `approve-impl` per PO Condition B)

---

## 1. AC ↔ Plan ↔ Tasks coverage

| AC | In Spec | In Plan (phase) | In Tasks | Tested by | Verdict |
|----|---------|----------------|----------|-----------|---------|
| AC-1 (3-tap log) | ✓ | Phase 2, 4, 6 | TASK-011, 019, 025 | TASK-012 | **PASS** |
| AC-2 (offline ≤60s) | ✓ | Phase 2, 6 | TASK-011, 024, 030 | TASK-012 | **PASS** |
| AC-3 (dashboard) | ✓ | Phase 3, 6 | TASK-014, 015, 026, 027 | TASK-016 | **PASS** |
| AC-4 (weekly badges) | ✓ | Phase 5 | TASK-021, 022 | TASK-023 | **PASS** |
| AC-5 (parent view) | ✓ | Phase 1, 6 | TASK-002, 028 | TASK-003 | **PASS** |
| AC-6 (cafeteria publish) | ✓ | Phase 4 | TASK-017, 018, 019, 029 | TASK-016 + TASK-012 | **PASS** |
| AC-7 (SSO Google) | ✓ | Phase 1, 6 | TASK-004, 027 | TASK-005 | **PASS** |
| AC-8 (3-yr Android TTI) | ✓ | Phase 7 | TASK-031, 032 | TASK-032 | **PASS w/ caveat** |
| AC-9 (WCAG 2.1 AA) | ✓ | Phase 7 | TASK-033 | TASK-033 | **PASS** |
| AC-10 (COPPA delete) | ✓ | Phase 7 | TASK-034 | TASK-034 | **PASS** |

**Coverage:** 10/10. No orphan ACs. No untraced tasks.

## 2. Edge case coverage (spec §9)

| # | Edge case | Plan/Task addressing it | Verdict |
|---|-----------|--------------------------|---------|
| 1 | Recipe corrected after publish | AD-5 + TASK-020 (reattach job) | ✓ |
| 2 | Two devices logging same meal | AD-4 + TASK-011 (UNIQUE constraint) + TASK-012 | ✓ |
| 3 | Offline >24h | AD-4 + TASK-024 14-day TTL | ✓ |
| 4 | Parent revokes consent mid-week | TASK-006 (consent_audit_log) | **PARTIAL — needs explicit task** |
| 5 | Student moves grade | not addressed | **GAP** |
| 6 | Clock skew adversarial | AD-9 + TASK-013 | ✓ |
| 7 | Cafeteria publishes after 12pm | TASK-018, 020 | ✓ |
| 8 | Empty intake (sick day) | dashboard handles 0 logs gracefully | **PARTIAL — needs test** |
| 9 | Maximum logs/day | TASK-011 enforces ≤8 entries/slot/day | ✓ |
| 10 | Misclassified food (e.g., yogurt) | manual correction flow | **GAP — no task** |

**Edge case findings:**
- **Gap #1 (Edge 5):** Mid-year grade-bracket transition isn't planned. Add task before W3.
- **Gap #2 (Edge 10):** No path for nurse/staff to correct a misclassified menu item post-publish. AD-5 makes menus immutable, so correction = republish. Acceptable, but make it explicit in tasks.

## 3. Business rule coverage

| BR | Description | Where enforced | Test |
|----|-------------|----------------|------|
| BR-1 | Student data only visible to that student + linked parent + staff aggregate | TASK-002 (RLS) | TASK-003 |
| BR-2 | No data collection without active parental consent | TASK-006/007/008 | TASK-009 |
| BR-3 | Badges retrospective only, never predictive | TASK-022 (Sunday cron) | TASK-023 |
| BR-4 | Logged nutrition is immutable once written | AD-5 + TASK-017 | implicit in TASK-020 |
| BR-5 | Parent can read but never write child's data | RLS policy SELECT-only | TASK-003 |
| BR-6 | Targets driven by age bracket only | TASK-014 + AD-7 | TASK-016 |
| BR-7 | Sodium/sugar ceilings, fibre/veg floors | TASK-014 + dashboard | TASK-016 |

**All BRs covered.** BR-4 test coverage is implicit; recommend an explicit assertion test.

## 4. Open questions status

| OQ | Status | Owner | Blocker for |
|----|--------|-------|-------------|
| OQ-1 (consent mechanism) | OPEN — legal due 2026-04-19 | Priya | merge-to-develop |
| OQ-2 (food DB licensing) | RESOLVED — USDA FoodData Central (public domain) | Arjun | — |
| OQ-3 (target review cadence) | RESOLVED — quarterly nurse review | Priya | — |
| OQ-4 (badge inventory v1) | RESOLVED — Rainbow Plate + Steady Fuel only | Priya | — |

**OQ-1 still BLOCKING.** Plan/tasks correctly handle this via AD-6 dual-build.

## 5. Findings & recommendations

| ID | Severity | Finding | Recommendation |
|----|----------|---------|---------------|
| F-1 | MED | Edge case #5 (grade transition) has no plan/task coverage | Add a task to Phase 1 or Phase 7 |
| F-2 | LOW | Edge case #10 (misclassified food) implicit in republish; not explicit | Add to tasks.md as a documentation task |
| F-3 | MED | BR-4 immutability test is implicit | Add explicit `test_meal_log_immutability.py` to TASK-012 |
| F-4 | LOW | Spec §8 doesn't specify token rotation cadence for HMAC student-ID hashing (AD-10) | Add to plan §6 risks or AD-10 |
| F-5 | INFO | TASK-008 (wet-signature) UX has no design mockup yet | Designer involvement before W2 |

## 6. Verdict

**PASS WITH FINDINGS** — handoff to Mahesh to absorb F-1, F-3 into tasks.md before W2 starts. F-2, F-4, F-5 can be tracked as backlog items.

This compliance review will re-run after `security-audit` (Stage E) and again pre-release.

---
*Next QA action: generate test scaffolds for TASK-003 (RLS isolation) via `test-gen` — `spec-test-rls-isolation.md`.*
