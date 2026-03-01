# Implementation Plan: Role-Based Access Control (RBAC)

> **Spec:** [012 - Role-Based Access Control](spec.md)
> **Status:** APPROVED
> **Created:** 2026-02-19
> **Estimated effort:** L

---

## 1. Summary

Implement RBAC by adding a permission registry, role and role-permission data models, a core authorization service with in-memory caching, Express middleware for route-level enforcement, REST API endpoints for role management and assignment, and an admin UI for role CRUD. Audit logging is woven through every layer so that every permission check is recorded. The implementation follows a bottom-up approach: data model first, then service logic, then middleware, then API surface, then admin UI.

## 2. Architecture Decisions

| # | Decision | Rationale | Alternatives Considered |
|---|----------|-----------|------------------------|
| AD-1 | Store roles and permissions in the primary PostgreSQL database using a join table for role-permission mappings. | Keeps authorization data co-located with user data, simplifying transactions and consistency. | Redis-only storage (fast but no durability guarantees), dedicated authorization service (premature for V1 scope). |
| AD-2 | Cache resolved permission sets in-memory (per-process LRU cache with 60-second TTL) rather than querying the database on every request. | Meets the 5 ms P95 constraint from the spec. TTL ensures permission changes propagate within one minute without requiring cache invalidation infrastructure. | Distributed cache via Redis (adds operational dependency), no cache (fails performance constraint). |
| AD-3 | Use Express middleware for route-level permission enforcement, with a `requirePermission('action:resource')` decorator pattern. | Matches existing codebase conventions for authentication middleware. Keeps enforcement declarative and co-located with route definitions. | Centralized policy engine like OPA (over-engineered for V1), manual checks inside each handler (error-prone, inconsistent). |

## 3. Acceptance Criteria Traceability

| AC | Description | Implemented In | Tested In |
|----|-------------|----------------|-----------|
| AC-1 | Admin creates role with permissions | Phase 4 (API endpoints) | Phase 4 (integration tests) |
| AC-2 | Role assignment grants effective permissions | Phase 2 (core service), Phase 4 (API) | Phase 2 (unit), Phase 4 (integration) |
| AC-3 | Unauthorized action returns 403 with missing permission | Phase 3 (middleware) | Phase 3 (unit + integration) |
| AC-4 | Multiple roles produce union of permissions | Phase 2 (core service) | Phase 2 (unit tests) |
| AC-5 | Audit log entry for every permission check | Phase 2 (core service), Phase 3 (middleware) | Phase 3 (integration) |
| AC-6 | Deleting a role removes it from assigned users | Phase 2 (core service), Phase 4 (API) | Phase 4 (integration) |

## 4. Implementation Phases

### Phase 1: Data Model & Migrations

**Goal:** Create the database schema for roles, permissions, and their relationships.

**Work items:**
1. Create `permissions` table with columns: `id`, `action`, `resource`, `description`.
2. Create `roles` table with columns: `id`, `name`, `description`, `is_system`, `created_at`, `updated_at`.
3. Create `role_permissions` join table with composite key (`role_id`, `permission_id`).
4. Create `user_roles` join table with composite key (`user_id`, `role_id`, `assigned_at`, `assigned_by`).
5. Write seed migration to populate the permission registry and create the built-in "admin" and "viewer" roles.

**Files likely affected:**
- `src/db/migrations/20260219_create_rbac_tables.sql` (CREATE)
- `src/db/seeds/rbac_permissions.sql` (CREATE)
- `src/models/Role.ts` (CREATE)
- `src/models/Permission.ts` (CREATE)
- `src/models/index.ts` (MODIFY — add exports)

### Phase 2: Core Authorization Service

**Goal:** Build the service layer that resolves user permissions, manages roles, and enforces business rules.

**Work items:**
1. Implement `RoleService` with methods: `createRole`, `deleteRole`, `updateRolePermissions`, `assignRole`, `revokeRole`.
2. Implement `PermissionService` with method: `getEffectivePermissions(userId)` that unions all role permissions.
3. Add LRU cache (60-second TTL) for resolved permission sets.
4. Integrate audit logging: every `checkPermission` call writes to the audit log.
5. Enforce business rules BR-1 through BR-4 in service validation logic.

**Files likely affected:**
- `src/services/RoleService.ts` (CREATE)
- `src/services/PermissionService.ts` (CREATE)
- `src/services/AuditService.ts` (MODIFY — add permission-check event type)
- `src/utils/cache.ts` (CREATE)

### Phase 3: Authorization Middleware

**Goal:** Create Express middleware that intercepts requests and enforces permissions at the route level.

**Work items:**
1. Implement `requirePermission(permission: string)` middleware that checks the user's effective permissions and returns 403 if missing.
2. Format the 403 response body consistently: `{ error: "Forbidden", missing_permission: "..." }`.
3. Wire audit logging into the middleware so both allow and deny decisions are recorded.

**Files likely affected:**
- `src/middleware/authorize.ts` (CREATE)
- `src/middleware/index.ts` (MODIFY — add export)
- `src/types/errors.ts` (MODIFY — add ForbiddenError type)

### Phase 4: API Endpoints

**Goal:** Expose REST endpoints for role management, role assignment, and permission listing.

**Work items:**
1. `POST /api/roles` — Create a role (requires `role:manage`).
2. `GET /api/roles` — List all roles with their permissions.
3. `DELETE /api/roles/:id` — Delete a role, cascade-remove assignments (requires `role:manage`).
4. `POST /api/users/:id/roles` — Assign roles to a user (requires `role:manage`).
5. `DELETE /api/users/:id/roles/:roleId` — Revoke a role from a user (requires `role:manage`).

**Files likely affected:**
- `src/routes/roles.ts` (CREATE)
- `src/routes/users.ts` (MODIFY — add role assignment sub-routes)
- `src/routes/index.ts` (MODIFY — register role routes)

### Phase 5: Admin UI

**Goal:** Provide a management interface for administrators to create, edit, and assign roles.

**Work items:**
1. Role list page with create/delete actions.
2. Role detail page with permission toggle checkboxes.
3. User detail page with role assignment dropdown.

**Files likely affected:**
- `src/ui/pages/RoleList.tsx` (CREATE)
- `src/ui/pages/RoleDetail.tsx` (CREATE)
- `src/ui/components/PermissionMatrix.tsx` (CREATE)
- `src/ui/pages/UserDetail.tsx` (MODIFY — add role assignment section)
- `src/ui/routes.tsx` (MODIFY — add role management routes)

## 5. Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|------|----------|-----------|------------|
| Permission cache serves stale data beyond acceptable window | MEDIUM | MEDIUM | 60-second TTL keeps staleness bounded. Add cache-invalidation event on role mutation for future improvement. |
| Bulk role deletion (1,000+ users) causes request timeout | MEDIUM | LOW | Process deletions in batched transactions of 100. Return 202 Accepted with a job ID for large batches. |
| Seed migration conflicts with existing data in staging/production | LOW | MEDIUM | Seed uses `INSERT ... ON CONFLICT DO NOTHING` to be idempotent. |
| Middleware ordering bug causes permission checks to run before authentication | HIGH | LOW | Integration tests assert that unauthenticated requests receive 401 (not 403). Middleware is registered after auth middleware in the router chain. |

## 6. Rollback Plan

If this feature needs to be reverted:
1. Remove the authorization middleware from the route chain (single file change restores open access).
2. Run the down migration to drop `role_permissions`, `user_roles`, `roles`, and `permissions` tables.
3. Remove the role management routes and UI pages.
4. Audit log entries are retained (append-only) and do not need rollback.

---

> **Next step:** When this plan is APPROVED, run `/task-gen specs/012-rbac/plan.md` to break it into implementable tasks.
