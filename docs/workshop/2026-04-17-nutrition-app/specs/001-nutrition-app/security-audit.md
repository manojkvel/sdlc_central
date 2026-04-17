# Security Audit — NutriKids (001), pre-release pass

> **Skill:** `security-audit-deep` (post-Phase-7)
> **Auditor:** Vikram (Security) | **Date:** 2026-04-17 (workshop sim — would be ~2026-04-30 in calendar)
> **Standards aligned:** OWASP Top 10 (2025), Agentic AI Top 10 (2026), COPPA, FERPA
> **Workshop note:** This audit deliberately injects two findings so the recursive `review-fix` loop can be demonstrated. Real audits would only flag what they observe.

---

## 1. Scope

| Surface | In-scope | Notes |
|---------|----------|-------|
| Authn (TASK-004) | ✓ | OIDC token handling, refresh flow |
| Authz / RLS (TASK-002, 003) | ✓ | Adversarial test review + manual probe |
| API surface (TASK-011, 015, 018, 019) | ✓ | All endpoints under `/v1/*` |
| Offline sync (TASK-024, 030) | ✓ | Replay safety, queue tampering |
| Data retention (TASK-034) | ✓ | COPPA delete-on-request validation |
| Secrets, build supply chain | ✓ | npm + pypi audit |
| LLM-touched surfaces | n/a | No LLM features in v1 |

## 2. Findings

| ID | Severity | Standard | Title | Status |
|----|----------|----------|-------|--------|
| SEC-001 | **CRITICAL** | COPPA / OWASP A04 | `consent_audit_log` retention exceeds COPPA 30-day deletion window | OPEN |
| SEC-002 | **HIGH** | OWASP A01 | `/v1/dashboard/{student_id}` accepts `student_id` from path without secondary parent-link check | OPEN |
| SEC-003 | MED | OWASP A05 | CORS allows `*` on `/v1/cafeteria/menus/*` (intended for service worker) but also exposes `/v1/meals/batch` | OPEN |
| SEC-004 | MED | OWASP A02 | JWT `kid` claim not validated against JWKS allowlist | OPEN |
| SEC-005 | LOW | A09 | OpenTelemetry trace exporter uses HTTP not HTTPS in dev preset | INFO only |
| SEC-006 | LOW | A06 | `expo-sqlite` pinned to ~14.x — minor version drift allowed | OPEN |

### SEC-001 — CRITICAL — `consent_audit_log` retention exceeds COPPA window

**Observation.** The COPPA delete-on-request flow (TASK-034) iterates every table referencing `user_id` and removes rows. However, `consent_audit_log` is intentionally write-only (per AD-6) so its rows are NOT deleted on request — only redacted (`user_id` → null, `details` → `{redacted}`).

The COPPA 30-day window requires that *no PII* remain after deletion. The current scheme leaves a `parent_email` column populated for audit purposes — that is PII for a minor's guardian and falls under the request.

**Why we flagged it.** Audit-log retention is a frequent COPPA gotcha. The intent (audit trail) is legitimate, but the column choice is non-compliant.

**Required fix (proposed).**
1. Hash `parent_email` with rotating salt at write time (not on delete).
2. Store hash + timestamp + action only.
3. Add migration to redact existing rows on deploy.
4. Update TASK-034 deletion-audit to assert no plaintext email survives a delete request.

**Owner.** Mahesh.

---

### SEC-002 — HIGH — Dashboard endpoint trusts path-supplied `student_id`

**Observation.** `GET /v1/dashboard/{student_id}` reads `student_id` from the URL path. RLS catches the bottom layer (the SQL won't return another student's data), but the endpoint logic (aggregation, badge lookup) relies on the path value to compose the response payload. A parent passing their own student's ID gets the right answer; a parent passing a non-linked student's ID gets an empty response — but the *response shape* leaks the existence of that student.

**Required fix (proposed).**
1. Reject requests where `student_id` does not match the JWT's user_id (for student role) OR a linked student (for parent role).
2. Return 404 for non-linked, indistinguishable from a non-existent student.

**Owner.** Mahesh.

---

### SEC-003 — MED — CORS overly permissive

**Observation.** The cafeteria publish path was opened up for the staff PWA service worker, but CORS was widened on the entire `/v1` prefix instead of the specific path.

**Required fix.** Tighten CORS to specific paths and origins (the school's GWfE domain).

**Owner.** Karan (Phase 6w fix).

---

### SEC-004 — MED — JWT `kid` validation missing

**Observation.** Authn middleware (TASK-004) decodes the JWT against the GWfE JWKS but doesn't enforce that the `kid` is in an allowlist. Google rotates keys legitimately, but a stale-key attack window exists.

**Required fix.** Cache JWKS for 1 h; reject any `kid` not present.

**Owner.** Mahesh.

---

### SEC-005 / SEC-006

Informational / low priority — defer to next sprint.

---

## 3. Gate verdict (`impl-to-release` under `strict`)

| Threshold | Required | Actual | Pass? |
|-----------|----------|--------|-------|
| `max_critical_findings` | 0 | 1 (SEC-001) | ✗ |
| `max_high_findings` | 0 | 1 (SEC-002) | ✗ |
| `min_test_coverage_percent` | 85 | 87 | ✓ |
| `require_spec_compliance` | true | spec-compliance.md present | ✓ |
| `require_security_audit` | true | this file | ✓ |
| `require_license_audit` | true | (deferred — see Stage F) | ✗ |
| `require_api_contract_check` | true | (deferred — see Stage F) | ✗ |

**Verdict: FAIL.** Cannot release. Triggers `auto_recover` via `review-fix`.

---

## 4. Recommended next action

Run `review-fix` with this audit as input. Two of the four findings (SEC-001, SEC-002) are auto-fixable from the proposed remediation; the other two are scheduled into Phase 6w and Phase 7 cleanup.

The recursive loop:
- review-fix proposes patch → re-runs the failing test → re-runs `security-audit` → if PASS, gate re-evaluates → if FAIL again, escalates to human.
