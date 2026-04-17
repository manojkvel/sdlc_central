# Architecture Decision Log — NutriKids (001)

*Skill: `decision-log` | Role: Architect (Arjun) | Date: 2026-04-17*
*Source: `plan.md` §2 — promoted into ADR records for posterity & PR review*

> **Format:** ADR-style. Each entry is durable; if a decision is later reversed, append a new ADR that supersedes it rather than editing history.

---

## ADR-001 — Monorepo with pnpm workspace + Poetry backend
- **Status:** Accepted
- **Date:** 2026-04-17
- **Context:** Three surfaces (mobile, web, API) need to share domain types (meal slots, nutrient keys, badge IDs). Team is 3 engineers; coordination overhead matters more than independent release cadence.
- **Decision:** Single repo: `apps/web` (Next.js), `apps/mobile` (Expo/React Native), `apps/api` (FastAPI), `packages/domain` (shared TS types generated from Pydantic schemas).
- **Consequences:**
  - (+) One PR shows full vertical slice; CI runs typecheck end-to-end
  - (+) Shared `packages/domain` makes spec-driven types enforceable at compile time
  - (−) CI minutes higher per PR; mitigated by pnpm `--filter` and Poetry workspace caching
- **Alternatives:** Polyrepo per surface (rejected — sync overhead); Turborepo (deferred — pnpm workspaces are simpler for team of 3)

## ADR-002 — FastAPI + PostgreSQL on RDS (US region) with row-level security
- **Status:** Accepted
- **Date:** 2026-04-17
- **Context:** COPPA + FERPA require US-region storage and verifiable per-student isolation. Cross-student reads must be impossible to construct, even via app bug.
- **Decision:** PostgreSQL 16 on RDS us-east-1 with RLS policies on `students`, `meal_logs`, `parent_child_links`, `weekly_badges`. RLS uses `current_setting('app.user_id')` set per request from validated JWT.
- **Consequences:**
  - (+) Defense-in-depth: RLS catches app-layer bugs
  - (+) FERPA auditor can read RLS policies directly
  - (−) Every connection must set the GUC; mitigated via SQLAlchemy event listener (Phase 1)
- **Alternatives:** Node.js + Prisma (rejected — team prefers Python); Firestore (rejected — security rules less transparent for FERPA audit)

## ADR-003 — OIDC SSO with Google Workspace for Education
- **Status:** Accepted
- **Date:** 2026-04-17
- **Context:** Oakwood already runs GWfE for students and staff. Spec NFR forbids password storage.
- **Decision:** OIDC `authorization_code + PKCE`. Access tokens 15 min; refresh via silent SSO. Parents sign in with their own Google account, link to a student via tokenised email invitation; parent-student link verified server-side.
- **Consequences:**
  - (+) Zero password reset support load
  - (+) Account lifecycle (offboarding) is handled by school IT
  - (−) Households without Google accounts cannot use the parent view in v1 — flagged as known gap
- **Alternatives:** Auth0 (rejected — extra vendor); custom auth (rejected — reinvents OIDC)

## ADR-004 — Offline-first logging via local queue with client UUIDs
- **Status:** Accepted
- **Date:** 2026-04-17
- **Context:** AC-2 mandates offline meal logging with sync within 60 s of reconnect. Cafeteria Wi-Fi is flaky.
- **Decision:** Mobile uses `expo-sqlite`; web uses IndexedDB (via Dexie). All meal logs are written first to local queue with a client-generated UUID. Sync worker POSTs queue to `/v1/meals/batch`. Server dedupes by `(student_id, meal_slot, served_on, client_uuid)` UNIQUE constraint.
- **Consequences:**
  - (+) Idempotent — replay-safe even with flaky network
  - (+) Server can return per-item accept/reject without partial-failure ambiguity
  - (−) Queue bloat if sync stays broken for days; mitigated via 14-day local TTL + visible status indicator
- **Alternatives:** Online-only (rejected — fails AC-2); CRDT merge (rejected — overkill for append-only logs)

## ADR-005 — Cafeteria menus are immutable; logs reference `menu_version_id`
- **Status:** Accepted
- **Date:** 2026-04-17
- **Context:** BR-4 requires that a logged meal always shows the nutrition the student saw when they logged it, even if cafeteria staff later corrects the menu. Edge case #1 — recipe corrected after publish — must not silently change historical logs.
- **Decision:** Each `cafeteria_menu_publish` action writes a new `menu_version` row. Logs reference `menu_version_id` at write time. A republish within the same calendar day triggers a background reattach job for *open* (unsynced) logs only.
- **Consequences:**
  - (+) Auditable: original nutrition values are immutable
  - (+) Correction flow has clear semantics
  - (−) Storage grows per publish; mitigated by 90-day archival
- **Alternatives:** Mutable menu with audit log (rejected — harder to prove for FERPA audit)

## ADR-006 — Consent mechanism behind feature flag (resolves OQ-1 without blocking planning)
- **Status:** Accepted (provisional — both branches built; legal selects active branch ≤ 2026-04-19)
- **Date:** 2026-04-17
- **Context:** OQ-1 (wet-signature vs SSO-verified parental consent) is the one BLOCKING open question from the spec; legal review lands 2026-04-19. PO Priya approved the spec on condition that planning proceeds but implementation does not start until OQ-1 closes.
- **Decision:** Introduce config flag `consent.mechanism ∈ {sso_verified, wet_signature}`.
  - `sso_verified` path: parent SSO + acknowledgement screen → `parent_child_links.consent_status = active`
  - `wet_signature` path: PDF generated server-side, school office uploads countersigned scan; admin marks `consent_status = active`
  - Both paths write to the same `consent_audit_log` table, so downstream code (badge cron, dashboard, parent view) is consent-mechanism-agnostic.
- **Consequences:**
  - (+) Phase 1 can build both paths in parallel; legal picks the live one before launch
  - (+) Forces clean separation: no consent-mechanism-specific assumptions leak into Phase 2+
  - (−) Wet-signature UX work may be discarded; estimated 4 dev-days at risk
  - (−) Implementation HITL gate (`approve-impl`) MUST verify the chosen path is wired before merging Phase 1
- **Alternatives:** Wait for legal then plan (rejected — costs 2 working days of architect time); pick one and rebuild later (rejected — doubles the rework cost in the worse case)
- **Supersedes:** None
- **Risk owner:** Arjun until 2026-04-19, then Priya

## ADR-007 — Age-bracket nutrition targets stored as JSON config in repo
- **Status:** Accepted
- **Date:** 2026-04-17
- **Context:** BR-6 makes targets a function of age bracket only. OQ-3 (resolution: school nurse approves quarterly) means changes are infrequent and need a review trail.
- **Decision:** `config/nutrition-targets.json` is the source of truth. Loaded at API boot. Updates ship as PRs reviewed by the nurse.
- **Consequences:**
  - (+) Quarterly review trail = git history
  - (+) No admin UI to build or secure in v1
  - (−) Live nutrition tweaks require a deploy; acceptable given quarterly cadence
- **Alternatives:** DB-stored, admin-editable (deferred — no admin UI in v1)

## ADR-008 — Weekly badges computed by Sunday-23:59 cron
- **Status:** Accepted
- **Date:** 2026-04-17
- **Context:** AC-4 is week-scoped and retrospective. Real-time recompute on every meal log would be wasteful and complicate edge cases (late offline sync, midnight crossings).
- **Decision:** Cron at Sunday 23:59 in the school's timezone (America/New_York) writes `weekly_badges` rows for every active student. Idempotent — re-runs are safe.
- **Consequences:**
  - (+) Simple mental model; eventual consistency is fine for retrospective view
  - (+) Easier to test — single trigger, deterministic input
  - (−) Late-syncing logs that arrive Monday 00:30 are excluded from that week; mitigated by a one-shot Monday 06:00 catch-up sweep
- **Alternatives:** Real-time recompute on every log (rejected — wasted compute and race-prone)

## ADR-009 — Server-authoritative dates and times
- **Status:** Accepted
- **Date:** 2026-04-17
- **Context:** Edge case #6 — adversarial student fast-forwards device clock to manufacture a 5-day badge streak.
- **Decision:** `served_on` is set server-side from validated request time. Client clock used only for display ordering within a session. Offline logs carry a client-claimed timestamp but server clamps to `[now − 14d, now]` on sync and stamps the actual `received_at`.
- **Consequences:**
  - (+) Defeats clock manipulation
  - (+) Replay-safe even from devices with wildly wrong clocks
  - (−) Edge case: kid logs lunch on a device with no network and no recent server sync — handled by clamp window
- **Alternatives:** Trust client clock (rejected — adversarial-kid problem)

## ADR-010 — No third-party analytics, crash, or ad SDKs
- **Status:** Accepted
- **Date:** 2026-04-17
- **Context:** Spec NG-5 plus COPPA. Most off-the-shelf analytics SDKs phone home with device identifiers that constitute PII for minors.
- **Decision:** First-party OpenTelemetry only, exported to a self-hosted Tempo + Prometheus stack in the same US region. Student IDs hashed (HMAC with rotating salt) before traces are emitted.
- **Consequences:**
  - (+) Zero third-party data exposure
  - (+) FERPA + COPPA audit story is short
  - (−) Crash reporting requires manual ingestion of native crash logs; acceptable for v1 scale
- **Alternatives:** Sentry / Firebase Crashlytics (rejected — both sample identifiers we cannot ship for minors)

---

## Cross-cutting notes
- All ADRs are subject to revision at the implementation HITL gate (`approve-impl`) if security review surfaces a blocker. Update this log; do not silently change behaviour.
- ADR-006 is the most fragile entry — re-read it before merging Phase 1.
