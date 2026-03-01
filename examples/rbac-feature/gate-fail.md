# Quality Gate Report: spec-to-plan

> **Date:** 2026-02-17T09:45:00Z
> **Spec:** specs/012-rbac/spec.md (draft)
> **Decision:** FAIL

---

## Results

| Criterion | Status | Value | Threshold | Notes |
|-----------|--------|-------|-----------|-------|
| Acceptance criteria count | PASS | 6 | >= 3 | AC-1 through AC-6 defined |
| AC measurability | FAIL | 5/6 (83%) | 100% | AC-4 is not testable (see below) |
| Business rules defined | PASS | 4 | >= 1 | BR-1 through BR-4 with concrete examples |
| Constraints specified | PASS | Present | Present | Security, performance, and compliance sections populated |
| Open questions | FAIL | 1 | 0 | OQ-1 unresolved (see below) |
| User flows | PASS | 4 | >= 1 | Four user stories covering admin and user perspectives |
| Edge cases | PASS | 4 | >= 1 | Bulk deletion, concurrency, registry updates, last-role deletion |

---

## Failures

### 1. AC-4 not measurable

**Criterion:** AC measurability
**Detail:** AC-4 reads: *"Given a user with multiple roles, when they access the system, then the system should be fast."* The phrase "should be fast" is not testable. There is no defined metric, threshold, or measurement method. An automated test cannot determine whether this criterion passes or fails.

**Route:** `/spec-evolve resolve`
**Auto-recoverable:** YES
**Action:** Rewrite AC-4 with a specific, measurable condition.

**Before (failing):**
```
AC-4: Given a user with multiple roles, when they access the system,
then the system should be fast.
```

**After (corrected):**
```
AC-4: Given a user with multiple roles, when permissions overlap,
then the effective permission set is the union (most permissive) of
all assigned roles, resolved within 5 ms P95.
```

The corrected version defines a concrete behavior (union of permissions) and a measurable performance target (5 ms P95), making it testable by both unit tests (union logic) and performance benchmarks (latency).

---

### 2. Open question unresolved

**Criterion:** Open questions
**Detail:** OQ-1 is unresolved: *"Should permission changes take effect immediately (invalidate active sessions) or on the next request?"* This question directly impacts the implementation of the permission cache and session handling. The plan cannot proceed until this is answered because it determines whether cache invalidation is needed on every role mutation.

**Route:** HITL gate
**Auto-recoverable:** NO
**Action:** A human decision-maker (product owner or architect) must answer OQ-1. Once resolved, update the spec and re-run this gate.

---

## Recovery Routing

1. Run `/spec-evolve resolve` to fix AC-4 with the measurable rewrite shown above. This is auto-recoverable and does not require human input.
2. Escalate OQ-1 to the HITL gate. A human must decide between immediate invalidation and next-request propagation. Once the decision is recorded, update the spec's Business Rules section and re-run `/quality-gate spec-to-plan`.

**Recommendation:** Fix AC-4 first (automated, takes seconds), then route OQ-1 to the product owner for a decision. Re-evaluate this gate after both issues are resolved.
