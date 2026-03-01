# Code Review: RBAC Implementation

> **Date:** 2026-03-01
> **Scope:** src/services/RoleService.ts, src/middleware/authorize.ts, src/routes/roles.ts
> **Verdict:** APPROVE WITH COMMENTS
> **Issues:** 0 critical, 0 high, 1 medium, 2 low

---

## Summary

This changeset implements the core RBAC system: role and permission models, the RoleService with business rule enforcement, authorization middleware, and the role management API endpoints. The overall architecture is clean and follows existing codebase conventions. Three minor issues should be addressed before merge but do not block approval.

## Issues Found

### Finding 1

**[MEDIUM]** `src/services/RoleService.ts:47` — Missing input validation on role name

**Category:** Data Handling
**Description:** The `createRole()` method passes the role name directly to the database query without sanitizing or validating the input beyond length checks. While the ORM parameterizes the query (preventing SQL injection), the name field accepts characters that could cause display issues in the admin UI, such as leading/trailing whitespace, HTML entities, or control characters.

**Recommendation:** Add a name sanitization step before persistence. Trim whitespace, reject control characters, and enforce an alphanumeric-plus-hyphens pattern (e.g., `/^[a-zA-Z0-9][a-zA-Z0-9 _-]{1,62}[a-zA-Z0-9]$/`).

---

### Finding 2

**[LOW]** `src/middleware/authorize.ts:23` — Inconsistent error response format

**Category:** API Contract
**Description:** The 403 response uses `{ error: "Forbidden", missing_permission: "role:manage" }`, but the existing 401 response from the auth middleware uses `{ error: { code: "UNAUTHORIZED", message: "..." } }`. The two error shapes are inconsistent, which complicates client-side error handling.

**Recommendation:** Align with the existing error envelope format: `{ error: { code: "FORBIDDEN", message: "Missing required permission", details: { permission: "role:manage" } } }`.

---

### Finding 3

**[LOW]** `src/services/RoleService.ts:112` — Magic string for default role

**Category:** Code Quality
**Description:** The fallback role assignment in `deleteRole()` uses the hardcoded string `"viewer"` to look up the default role. If the seed data changes the default role name, this code silently breaks.

**Recommendation:** Extract the default role name to a constant (e.g., `DEFAULT_ROLE_NAME` in a shared config module) and reference it in both the seed script and the service.

---

## Positive Observations

1. **Thorough business rule enforcement.** All four business rules (BR-1 through BR-4) are implemented with clear, descriptive error messages. The `deleteRole()` method correctly handles cascade removal and the system-role protection check.

2. **Audit logging is comprehensive.** Both allow and deny decisions are logged with all required fields. The append-only constraint is enforced at the repository level, not just the service level, which is the right approach.

3. **Test coverage is strong.** The test suite covers all six acceptance criteria, all four business rules, and three of the four edge cases. Test names are descriptive and follow the Given/When/Then pattern from the spec.

## AC Coverage Check

| AC | Covered by Tests | Status |
|----|-----------------|--------|
| AC-1 | `role.create.test.ts` | PASS |
| AC-2 | `role.assign.test.ts` | PASS |
| AC-3 | `authorize.middleware.test.ts` | PASS |
| AC-4 | `permission.union.test.ts` | PASS |
| AC-5 | `audit.logging.test.ts` | PASS |
| AC-6 | `role.delete.cascade.test.ts` | PASS |
