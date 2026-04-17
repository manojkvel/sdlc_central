# Wave Schedule — NutriKids (001)

> **Source:** `tasks.md` (38 tasks)
> **Generated:** 2026-04-17 by Mahesh (Developer) via `wave-scheduler`
> **Config:** `max_parallel=3` (team size), `prefer_test_first=true`, `hitl_before_human_tasks=true`
> **HITL split point:** TASK-007 / TASK-008 cannot merge to `develop` until OQ-1 (consent mechanism) closes 2026-04-19. Schedule treats this as a wave boundary at `approve-impl`.

---

## Wave Plan (3 engineers, parallelism cap = 3)

| Wave | Tasks (parallel) | Owner suggestion | Wall-clock | Notes |
|------|------------------|------------------|-----------|-------|
| W0 | TASK-001 | Mahesh | 0.5d | Bootstrap blocks everything; one person, fast |
| W1 | TASK-002, TASK-006, TASK-014 | Mahesh / Anita / Mahesh | 0.5d | All migrations against fresh schema; no conflicts |
| W2 | TASK-003, TASK-004, TASK-007, TASK-008 | Anita / Karan / Mahesh / Karan | 1.5d | RLS test + authn + both consent branches |
| W3 | TASK-005, TASK-009, TASK-010, TASK-017, TASK-021 | Anita / Karan / Mahesh / Karan / Mahesh | 1.0d | Test coverage + remaining migrations |
| **GATE** | **`approve-plan-stage` HITL** (Arjun reviews Phase 1 surface) | Arjun | — | Workshop demo: PO-pinned condition still open; gate signals it |
| W4 | TASK-011, TASK-013, TASK-018 | Mahesh / Mahesh / Karan | 1.0d | Logging + clamp + menu publish (no file overlap) |
| W5 | TASK-012, TASK-015, TASK-019, TASK-022 | Anita / Mahesh / Karan / Karan | 1.0d | Idempotency test + dashboard + 1-tap + badge cron |
| W6 | TASK-016, TASK-020, TASK-023 | Anita / Karan / Anita | 0.5d | Contract tests + reattach job + cron fixture |
| W7 | TASK-024, TASK-027, TASK-030 | Karan / Mahesh / Mahesh | 1.5d | Mobile sync + web SSR + web queue (parallel surfaces) |
| W8 | TASK-025, TASK-026, TASK-028, TASK-029 | Karan / Karan / Mahesh / Anita | 1.5d | UI screens; PARTIAL agent-readiness — needs UX review |
| W9 | TASK-031, TASK-033, TASK-034 | Mahesh / Anita / Anita | 1.0d | Lighthouse + axe + COPPA delete-audit |
| W10 | TASK-032 | Karan | 1.0d | Reference-device perf — NO agent-readiness, manual |
| W11 | TASK-035 | Mahesh | 0.5d | `security-audit-deep` runs on full system |
| **GATE** | **`approve-impl` HITL (strict profile)** | Priya + Arjun + Security | — | OQ-1 must be CLOSED here; profile flipped to strict |
| W12 | TASK-036, TASK-037, TASK-038 | Anita / Mahesh / Mahesh | 0.5d | Auto-recovery loop, docs, release notes |

**Total wall-clock with 3 engineers:** ~12 dev-days
**Critical path effort (single engineer):** ~28 dev-days
**Parallelism gain:** 2.3×

---

## File-conflict edges added by scheduler

| Pair | Shared file | Resolution |
|------|-------------|-----------|
| TASK-007 ↔ TASK-008 | `apps/api/src/consent/router.py` | Both touch consent router; serialised within W2 (Karan owns sequentially) — both behind feature flag |
| TASK-024 ↔ TASK-030 | `packages/domain/sync.ts` | Mobile + web both consume the shared sync contract — Mahesh writes contract first in W4 (TASK-011), then both surfaces consume |

---

## HITL gate annotations

- **After W3 — `approve-plan-stage`:** Architect (Arjun) reviews the Foundation surface before logging code lands. Workshop talking point: "this is where we catch consent-mechanism leakage into core code".
- **After W11 — `approve-impl` (strict):** Profile flip from `standard` → `strict` per PO Condition B. OQ-1 MUST be resolved by this point (legal date 2026-04-19; we hit this gate ~2026-04-30).

---

## Recompute triggers

The scheduler re-runs when:
1. A task fails CI (`recompute_on_failure: true`)
2. Spec evolves (any `spec-evolve` skill run on this spec)
3. PO promotes a task via `board-sync pull`
4. OQ-1 resolves and `consent.mechanism` is fixed — at that point the dual-build tasks collapse to one branch and ~4 dev-days are returned to the plan.

---

> **Next:** Workshop attendees pick W0/W1 tasks and pair-program them. Ready to run `/task-implementer` against any task with `Agent-ready: YES`.
