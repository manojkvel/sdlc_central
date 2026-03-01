# Tasks: Role-Based Access Control (RBAC)

> **Spec:** [012 - Role-Based Access Control](spec.md)
> **Plan:** [Implementation Plan](plan.md)
> **Generated:** 2026-02-20
> **Total tasks:** 12
> **Estimated total effort:** 4 waves, ~30 hours

---

## Summary

This breakdown produces **12 tasks** organized into **4 waves**. Waves define parallelization boundaries: all tasks within a wave can run concurrently, but a wave cannot start until the previous wave is complete.

**Critical path:** TASK-001 -> TASK-002 -> TASK-004 -> TASK-006 -> TASK-009 -> TASK-011 -> TASK-012
**Critical path effort:** ~20 hours

---

## Task Dependency Graph

```
Wave 1 (foundation):
  TASK-001 ─┐
  TASK-002 ─┤ (all independent)
  TASK-003 ─┘
       │
       v
Wave 2 (core logic):
  TASK-004 ──> depends on TASK-001, TASK-002
  TASK-005 ──> depends on TASK-004
  TASK-006 ──> depends on TASK-004
  TASK-007 ──> depends on TASK-004
       │
       v
Wave 3 (integration):
  TASK-008 ──> depends on TASK-005, TASK-006, TASK-007
  TASK-009 ──> depends on TASK-005, TASK-006
  TASK-010 ──> depends on TASK-004
       │
       v
Wave 4 (release prep):
  TASK-011 ──> depends on TASK-008, TASK-009, TASK-010
  TASK-012 ──> depends on TASK-011
```

---

## Wave 1: Foundation

### TASK-001: Create RBAC database schema and migrations

**Type:** MIGRATE
**Estimated effort:** M
**Dependencies:** None
**Phase:** Phase 1 — Data Model
**Traces to:** AC-1, AC-2, BR-1

**Description:**
Create the database migration that adds the `permissions`, `roles`, `role_permissions`, and `user_roles` tables. The schema must enforce unique role names (case-insensitive), support many-to-many relationships between users and roles, and include timestamp columns for audit purposes.

**Definition of Done:**
- [ ] Migration file creates all four tables with correct columns, indexes, and foreign keys
- [ ] `roles.name` has a unique case-insensitive index
- [ ] Down migration cleanly drops all four tables
- [ ] Migration runs successfully against a fresh database
- [ ] Existing tests still pass after migration

**Agent-ready:** YES

---

### TASK-002: Implement Role and Permission models

**Type:** IMPLEMENT
**Estimated effort:** M
**Dependencies:** None
**Phase:** Phase 1 — Data Model
**Traces to:** AC-1, AC-2, BR-1

**Description:**
Create the ORM model definitions for `Role`, `Permission`, `RolePermission`, and `UserRole`. Define the associations (Role has many Permissions through RolePermission, User has many Roles through UserRole). Include validation for role name length (3-64 characters) and uniqueness.

**Definition of Done:**
- [ ] Model files created with correct associations
- [ ] Role name validation enforces 3-64 character length and uniqueness
- [ ] Models can be imported from the shared models index
- [ ] No linting errors introduced

**Agent-ready:** YES

---

### TASK-003: Create permission seed data

**Type:** CONFIGURE
**Estimated effort:** S
**Dependencies:** None
**Phase:** Phase 1 — Data Model
**Traces to:** AC-1, BR-2

**Description:**
Write the seed script that populates the permission registry with all application permissions (e.g., `user:read`, `user:manage`, `role:manage`, `content:read`, `content:write`, `content:delete`, `audit:read`). Create the built-in "admin" role with all permissions and "viewer" role with read-only permissions. The seed must be idempotent.

**Definition of Done:**
- [ ] Seed script populates all permissions using `INSERT ... ON CONFLICT DO NOTHING`
- [ ] Built-in "admin" role is created with all permissions and `is_system = true`
- [ ] Built-in "viewer" role is created with read-only permissions and `is_system = true`
- [ ] Running the seed twice produces no errors or duplicates

**Agent-ready:** YES

---

## Wave 2: Core Logic

### TASK-004: Implement RoleService and PermissionService

**Type:** IMPLEMENT
**Estimated effort:** L
**Dependencies:** TASK-001, TASK-002
**Phase:** Phase 2 — Core Service
**Traces to:** AC-1, AC-2, AC-4, AC-6, BR-1, BR-2, BR-3

**Description:**
Build the core service layer. `RoleService` handles role CRUD and assignment. `PermissionService` resolves a user's effective permissions by unioning all permissions from their assigned roles. Both services enforce business rules: unique role names, protected system roles, minimum one role per user.

**Definition of Done:**
- [ ] `RoleService.createRole()` validates name uniqueness and length
- [ ] `RoleService.deleteRole()` cascade-removes assignments and blocks deletion of system roles
- [ ] `PermissionService.getEffectivePermissions()` returns the union of all role permissions
- [ ] BR-1 through BR-4 are enforced with descriptive error messages
- [ ] Unit tests cover happy path and all four business rules

**Agent-ready:** YES

---

### TASK-005: Add in-memory permission cache

**Type:** IMPLEMENT
**Estimated effort:** S
**Dependencies:** TASK-004
**Phase:** Phase 2 — Core Service
**Traces to:** AC-4

**Description:**
Implement an LRU cache with 60-second TTL for resolved permission sets. The cache key is the user ID. Cache entries are invalidated on TTL expiry, not on mutation (per AD-2). This ensures permission lookups meet the 5 ms P95 performance constraint.

**Definition of Done:**
- [ ] LRU cache module created with configurable TTL and max size
- [ ] `PermissionService.getEffectivePermissions()` reads from cache before querying the database
- [ ] Cache miss triggers a database query and populates the cache
- [ ] Unit tests verify cache hit, cache miss, and TTL expiry behavior

**Agent-ready:** YES

---

### TASK-006: Implement authorization middleware

**Type:** IMPLEMENT
**Estimated effort:** M
**Dependencies:** TASK-004
**Phase:** Phase 3 — Middleware
**Traces to:** AC-3, AC-5

**Description:**
Create the `requirePermission(permission)` Express middleware. It extracts the user from the request context (set by the existing auth middleware), resolves their effective permissions, and returns 403 with `{ error: "Forbidden", missing_permission: "..." }` if the required permission is not present. Every check (allow or deny) writes an audit log entry.

**Definition of Done:**
- [ ] Middleware returns 403 with correct error format when permission is missing
- [ ] Middleware calls `next()` when permission is present
- [ ] Audit log entry is created for both allow and deny decisions
- [ ] Integration test confirms 401 for unauthenticated, 403 for unauthorized, 200 for authorized

**Agent-ready:** YES

---

### TASK-007: Build role management API endpoints

**Type:** IMPLEMENT
**Estimated effort:** L
**Dependencies:** TASK-004
**Phase:** Phase 4 — API Endpoints
**Traces to:** AC-1, AC-2, AC-6

**Description:**
Implement the REST endpoints: `POST /api/roles` (create), `GET /api/roles` (list), `DELETE /api/roles/:id` (delete with cascade), `POST /api/users/:id/roles` (assign), `DELETE /api/users/:id/roles/:roleId` (revoke). All endpoints require the `role:manage` permission via the authorization middleware.

**Definition of Done:**
- [ ] All five endpoints respond with correct status codes and response bodies
- [ ] All endpoints are guarded by `requirePermission('role:manage')`
- [ ] `DELETE /api/roles/:id` removes role assignments and creates audit log entries
- [ ] Input validation returns 400 for malformed requests
- [ ] Integration tests cover happy path, validation errors, and permission denial

**Agent-ready:** YES

---

## Wave 3: Integration

### TASK-008: Build admin UI for role management

**Type:** IMPLEMENT
**Estimated effort:** L
**Dependencies:** TASK-005, TASK-006, TASK-007
**Phase:** Phase 5 — Admin UI
**Traces to:** AC-1, AC-2

**Description:**
Create the admin interface pages: a role list page with create and delete actions, a role detail page with a permission toggle matrix, and a role assignment section on the existing user detail page. The UI should hide management controls from users without the `role:manage` permission.

**Definition of Done:**
- [ ] Role list page displays all roles with create and delete buttons
- [ ] Role detail page shows permission checkboxes and saves changes
- [ ] User detail page includes a role assignment dropdown
- [ ] UI elements are hidden (not just disabled) for users without `role:manage`
- [ ] No console errors or accessibility violations

**Agent-ready:** PARTIAL — UI layout decisions may need human review.

---

### TASK-009: Integrate audit logging for RBAC events

**Type:** IMPLEMENT
**Estimated effort:** M
**Dependencies:** TASK-005, TASK-006
**Phase:** Phase 2 — Core Service
**Traces to:** AC-5, BR-4

**Description:**
Extend the existing `AuditService` to handle RBAC event types: `permission.check.allow`, `permission.check.deny`, `role.created`, `role.deleted`, `role.assigned`, `role.revoked`. Each entry records user ID, action, resource, decision, and timestamp. Audit entries are append-only.

**Definition of Done:**
- [ ] Six new event types are supported by AuditService
- [ ] Audit log table has no UPDATE or DELETE operations exposed
- [ ] Integration tests verify log entries are created for permission checks and role mutations
- [ ] Log entries include all required fields (user ID, action, resource, decision, timestamp)

**Agent-ready:** YES

---

### TASK-010: Write comprehensive test suite

**Type:** TEST
**Estimated effort:** L
**Dependencies:** TASK-004
**Phase:** Phase 2, 3, 4
**Traces to:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, BR-1, BR-2, BR-3, BR-4

**Description:**
Write the end-to-end and edge case test suite. Cover all acceptance criteria, all four business rules, and all four edge cases from the spec (bulk deletion, concurrent modification, permission registry updates, last-role deletion). This task ensures full traceability from AC to test.

**Definition of Done:**
- [ ] At least one test per acceptance criterion (AC-1 through AC-6)
- [ ] At least one test per business rule (BR-1 through BR-4)
- [ ] Edge case tests: bulk role deletion, concurrent role update (409 response), last-role protection
- [ ] All tests pass in CI
- [ ] Test coverage for RBAC modules is above 80%

**Agent-ready:** YES

---

## Wave 4: Release Preparation

### TASK-011: Create data migration script for existing users

**Type:** MIGRATE
**Estimated effort:** M
**Dependencies:** TASK-008, TASK-009, TASK-010
**Phase:** Phase 1 — Data Model
**Traces to:** AC-2, BR-3

**Description:**
Write a one-time migration script that assigns the default "viewer" role to all existing users who have no role assignment. This ensures BR-3 (every user has at least one role) is satisfied for the existing user base. The script must be idempotent and log the number of users affected.

**Definition of Done:**
- [ ] Script assigns "viewer" role to all users without any role
- [ ] Script is idempotent (running twice changes nothing the second time)
- [ ] Script logs count of affected users
- [ ] Manual verification confirms all users have at least one role after execution

**Agent-ready:** YES

---

### TASK-012: Write RBAC documentation

**Type:** DOCUMENT
**Estimated effort:** M
**Dependencies:** TASK-011
**Phase:** Phase 5 — Cleanup
**Traces to:** AC-1, AC-3

**Description:**
Document the RBAC system for developers and administrators. Developer documentation covers: how to add `requirePermission()` to new routes, how to register new permissions, and how the cache works. Administrator documentation covers: how to create roles, assign permissions, and assign roles to users through the admin UI.

**Definition of Done:**
- [ ] Developer guide explains middleware usage with code examples
- [ ] Developer guide explains how to add new permissions to the registry
- [ ] Administrator guide covers role creation, permission assignment, and user role assignment
- [ ] Documentation is reviewed for accuracy against the implemented code

**Agent-ready:** PARTIAL — Technical writing quality may need human review.

---

## Traceability Matrix

| AC | Implementation Task(s) | Test Task(s) | Status |
|----|----------------------|-------------|--------|
| AC-1 | TASK-002, TASK-004, TASK-007 | TASK-010 | PENDING |
| AC-2 | TASK-004, TASK-007, TASK-011 | TASK-010 | PENDING |
| AC-3 | TASK-006 | TASK-010 | PENDING |
| AC-4 | TASK-004, TASK-005 | TASK-010 | PENDING |
| AC-5 | TASK-006, TASK-009 | TASK-010 | PENDING |
| AC-6 | TASK-004, TASK-007 | TASK-010 | PENDING |

**Coverage:** 6/6 ACs covered (100%)
