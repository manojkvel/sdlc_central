# Spec: NutriKids — School-Nutrition Tracking for Students

> **Status:** DRAFT (AI-generated, pending PO review)
> **Author:** AI-generated via `/spec-gen` — roleplayed by Product Owner (Priya)
> **Created:** 2026-04-17
> **Last updated:** 2026-04-17
> **Spec ID:** 001

---

## 1. Problem Statement

Oakwood Public School's wellness initiative has a goal — improve students' daily nutrition — but no visibility into what kids actually eat. Parents can't see patterns outside the home. The cafeteria publishes a printed menu no student keeps. Students have no feedback on whether their choices match age-appropriate guidance. NutriKids is a lightweight logging + dashboard product for students aged 10–14 that gives students, parents, and the school a shared, privacy-preserving view of daily nutrition and encourages healthy habits through positive reinforcement rather than restriction.

## 2. Goals

- **G-1:** Enable any enrolled student to log every meal (breakfast, lunch, snack, dinner) in under 30 seconds on mobile, including offline.
- **G-2:** Show each student a daily and weekly dashboard comparing their intake to age-bracket targets for calories, protein, fibre, fruit/veg servings, added sugar, and sodium.
- **G-3:** Award weekly "Healthy Habit" badges based on objective thresholds (see BR-3) to reinforce consistent behaviour.
- **G-4:** Give each parent a read-only weekly summary for their own child only, with no cross-student visibility.
- **G-5:** Let cafeteria staff publish the daily lunch menu with pre-calculated nutrition so students log lunch with one tap.
- **G-6:** Satisfy COPPA (13-and-under) and FERPA (educational records) compliance from day one.

## 3. Non-Goals

- **NG-1:** **Not a medical, dietetic, or weight-loss tool.** No calorie limits, no "eat less of X" prescriptions, no BMI tracking. Reduces liability and keeps it positive.
- **NG-2:** **No social features.** No friend lists, no leaderboards, no public sharing. Eliminates bullying/comparison risk for minors.
- **NG-3:** **No fitness-wearable integration in v1.** Keeps scope tight; re-evaluate for v2.
- **NG-4:** **No support for students outside Oakwood Public School's SSO tenant.** Single-tenant v1; multi-tenancy is future work.
- **NG-5:** **No ad revenue, no third-party tracking, no analytics SDKs.** COPPA-safe by construction.

## 4. User Stories

### Primary Flow — Student logs lunch from cafeteria menu
> As a **student**, I want to **log today's cafeteria lunch with one tap**, so that **my dashboard updates without me typing ingredients**.

**Preconditions:**
- Student is logged in via school SSO.
- Cafeteria has published today's menu before 10:00 AM school time.
- Student has granted meal-logging permission (implied by parental consent).

**Steps:**
1. Student opens app at lunch; home screen shows "Today's cafeteria lunch" card with menu items and nutrition preview.
2. Student taps "I ate this" (or deselects items they skipped).
3. System records the logged meal against the student's day, attributed to `cafeteria_menu_<date>`.
4. Dashboard tile for today updates: daily totals and each target's progress bar reflect the logged meal.

**Postconditions:**
- Meal appears in student's meal history for today.
- If student was offline, the meal is queued and syncs when connectivity returns (AC-5).

### Alternative Flow — Student logs a home meal manually
> As a **student**, I want to **log a home meal by picking from common foods**, so that **my dashboard reflects the whole day, not just school**.

**Steps:**
1. Student taps "+ Log meal" and picks meal slot (breakfast/snack/dinner).
2. Student searches or picks from a curated kid-friendly food list (Apple, Banana, Cereal, PB&J sandwich, etc.) with portion sizes (small/medium/large).
3. System adds nutrition estimate to the day's totals.

### Alternative Flow — Parent views weekly summary
> As a **parent**, I want to **see my child's last 7 days of nutrition at a glance**, so that **I can support their goals at home**.

**Steps:**
1. Parent logs in via SSO invite link (linked to their child's student account).
2. Parent sees the "My Children" page with one tile per child they have consented access to.
3. Parent taps a child's tile; sees a read-only weekly dashboard (same metrics as student view) and the badge earned this week.
4. Parent cannot log, edit, or delete meals. Parent cannot see other students or any aggregate data.

### Alternative Flow — Cafeteria staff publishes daily menu
> As a **cafeteria staff member**, I want to **publish today's menu by 10:00 AM**, so that **students can one-tap log at lunch**.

**Steps:**
1. Staff logs in to the cafeteria admin web view with staff SSO.
2. Staff picks today's date; chooses menu items from a dish library pre-loaded with nutrition per serving.
3. Staff publishes; all students see the menu on their home screen within 1 minute.

### Error Flow — Offline log with stale cache
> **Given** a student has been offline for 24+ hours and the daily menu has since been re-published, **when** the student returns online, **then** any cafeteria-menu log created against the old version is re-attached to the published version of that day (nutrition values updated) and the student is shown a one-line toast: "Today's menu was updated — your log has been refreshed."

### Error Flow — Parent consent not granted
> **Given** a student logs in but parental consent has not been recorded, **when** they reach the home screen, **then** the app shows a blocking screen explaining parental consent is required and provides a button to email the consent request to the parent on file. No meal logging is possible until consent is granted.

## 5. Acceptance Criteria

- [ ] **AC-1:** Given a cafeteria menu published before 10:00 AM, when a student taps "I ate this" on the cafeteria lunch card, then the meal is recorded against that student's day within 2 seconds and dashboard totals update immediately.
- [ ] **AC-2:** Given a student is offline at lunch, when they tap "I ate this" on a cached cafeteria menu card, then the log is queued locally and syncs within 60 seconds of connectivity returning; no log is lost.
- [ ] **AC-3:** Given a student has logged meals for the current day, when they open the dashboard, then they see 6 progress bars (calories, protein, fibre, fruit/veg servings, added sugar, sodium) each showing percent-of-target for their age bracket.
- [ ] **AC-4:** Given a student has logged at least 5 fruit/veg servings/day for any 5 days in a calendar week (Mon–Sun), when Sunday 23:59 school-time passes, then the system awards the "Rainbow Plate" weekly badge visible on the student's and that child's parent's dashboards.
- [ ] **AC-5:** Given a parent has been invited via email and completes SSO linking with their child's account, when the parent opens the app, then they see a read-only weekly dashboard for that child only and are denied access to any other student's data (enforced server-side; tested with a direct API call).
- [ ] **AC-6:** Given a cafeteria staff member submits a daily menu, when they tap "Publish", then the menu is visible to all students within 60 seconds and is immutable (edits create a new version referenced by subsequent logs).
- [ ] **AC-7:** Given an account belongs to a student under 13, when the account is created, then no data is collected and no meals can be logged until explicit parental consent is recorded, signed by the parent via a verified SSO-linked account.
- [ ] **AC-8:** Given the user is on a 3-year-old Android device (Android 11, 2GB RAM), when they open the app cold, then time-to-interactive is under 3 seconds and lunch logging succeeds with the same UX as on a current device.
- [ ] **AC-9:** Given any screen in the app, when audited against WCAG 2.1 AA, then it passes with zero blocker issues (colour contrast, focus order, screen-reader labels, touch-target size).
- [ ] **AC-10:** Given a dataset with 500 students and 30 days of logs each, when the dashboard is loaded, then server responses are < 400 ms at the 95th percentile.

## 6. Business Rules

| Rule ID | Rule | Example |
|---------|------|---------|
| BR-1 | Every meal log must be attributable to exactly one student account. No shared logs. | Sibling accounts each log independently. |
| BR-2 | Parental consent is per-student and revocable. Revocation deletes the student's data within 30 days (COPPA). | Parent toggles consent off → student account locked; data wiped by next month's retention job. |
| BR-3 | "Rainbow Plate" weekly badge = 5+ fruit/veg servings on 5+ distinct days in the Mon-Sun week. "Steady Fuel" badge = logged all 3 main meals on 5+ days. Exactly one badge per week per rule; rules stack. | A student logs 5 fruit/veg × 6 days and 3 meals × 6 days → both badges awarded. |
| BR-4 | A published cafeteria menu is immutable. Corrections create a new version; existing logs retain reference to the version they were created against until next sync. | Menu published with wrong calorie count; staff publishes v2; student logs between publishes are auto-updated to v2 on next sync. |
| BR-5 | A parent account can access exactly the students they are explicitly linked to via SSO-verified invite. No teacher / admin / cafeteria-staff role has access to individual parent-visible dashboards without a separate approval flow. | Parent A cannot see Student B; principal cannot see any student's meal logs. |
| BR-6 | Nutrition targets are a function of age bracket only, not sex or body metrics. Three brackets: 10–11, 12–13, 14+. | 10-year-old and 11-year-old see same targets. |
| BR-7 | Age bracket is derived from grade level, not birthdate. The school doesn't share birthdates; grade proxies the bracket. | Grade 5 → 10–11 bracket. Grade 8 → 14+ bracket. |

## 7. Data Requirements

**Inputs:**
- From school SSO (Google Workspace for Education): user email, display name, role (student/parent/staff), grade (for students).
- From student: meal logs (meal slot, date, items chosen, portion size).
- From cafeteria staff: daily menu (date, list of dishes from the dish library).
- From dish library: nutrition per serving (curated, updated quarterly from USDA FoodData Central).

**Outputs:**
- Student dashboard data (today's totals vs targets, weekly trend).
- Parent weekly-summary view (read-only aggregate of child's week).
- Badge assignments per student per week.
- Cafeteria admin view of published menus.

**Stored state:**
- User records (email, SSO subject, role, grade for students, consent state for minors).
- Meal logs (one row per meal per day per student; items, portions, source=manual|cafeteria_menu_v<N>).
- Dish library (dish id, name, nutrition per serving, active/inactive flag).
- Daily menu versions (date, version, list of dish ids, published_at).
- Parent-child links (parent_user_id, student_user_id, consent state, consent_timestamp).
- Weekly badge awards (student_id, week, badge_ids).

**Relationships:**
- User 1—N Meal log.
- User (parent) M—N User (student) via consent-linked parent_child table.
- Daily menu (N versions per date) 1—N Dish.
- Meal log → Dish (via items) or → Daily menu version.

**Retention:**
- Meal logs: retained for the student's active period + 1 school year, then anonymised.
- On consent revocation: all PII and meal logs for that student deleted within 30 days (COPPA).

## 8. Constraints

### Security Constraints
- **Auth:** SSO-only for all roles. No password-based auth. Short-lived access tokens (15 min); refresh via SSO.
- **Authorisation:** Server-side RBAC; every API call checks role + ownership. Parents can only read their linked children; students can only read/write their own logs; cafeteria staff can only write menus.
- **Data minimisation:** We collect school email, display name, grade, age bracket, consent state, and meal logs. Explicitly NOT collected: home address, phone number, birthdate, body measurements, photos.
- **Encryption:** All data at rest encrypted (AES-256). All data in transit over TLS 1.2+.
- **PII handling:** All logs with student identifiers are classified as FERPA-protected educational records.

### Performance Constraints
- Cold start on reference low-end Android device (Android 11, 2GB RAM): < 3s TTI.
- Dashboard load p95: < 400 ms server-side at 500-student scale.
- Offline capability: most-recent 24h of menu + logging UI works offline. Sync within 60s of reconnection.

### Compliance Constraints
- **COPPA:** Verifiable parental consent before any collection for students under 13. 30-day deletion on revocation.
- **FERPA:** All educational records accessible only to the student, the linked parent, and school staff with legitimate educational interest. Audit log of access.
- **Data residency:** US regions only.
- **Accessibility:** WCAG 2.1 AA on every screen.

### Compatibility Constraints
- **Platforms:** iOS 15+, Android 11+, modern web (last-2 versions of Chrome/Safari/Edge/Firefox).
- **Low-end device target:** Android 11, 2GB RAM, 3-year-old hardware.
- **Browsers for parent/staff web:** keyboard-navigable, works at 200% zoom.

## 9. Edge Cases & Boundary Conditions

| # | Scenario | Expected Behaviour |
|---|----------|-------------------|
| 1 | Student logs same cafeteria lunch twice (double-tap) | System dedupes — one log per student per menu version per day. Second tap is a no-op; shown visually as "Already logged". |
| 2 | Parent tries to access another parent's child via direct API URL (authorisation bypass attempt) | Server returns 403. Event recorded in security audit log. |
| 3 | Cafeteria menu published without nutrition for a dish (missing dish data) | Publish is blocked at the menu-builder; inline error "Dish 'mystery soup' is missing nutrition info". |
| 4 | Student under 13 on first login, no parental consent yet | Shown consent-request screen; email-parent CTA; no logging allowed. |
| 5 | Student ages into a new bracket mid-year (grade 6 → grade 7) | Targets recompute from the day grade is updated in SSO. Past weeks keep historical targets. |
| 6 | Device clock is wrong by ±2 hours | Server-authoritative timestamps. Client time shown to user; server date used for daily/weekly bucketing. |
| 7 | 500 students all open the dashboard at once (post-lunch) | Meets p95 < 400ms. Graceful degradation: cached partial data with a "refreshing" indicator acceptable. |
| 8 | A dish is retired from the library between publish and student log | Historical logs keep the dish-nutrition snapshot. New logs can't reference retired dish. |
| 9 | Consent is revoked Friday morning, student had logged Mon–Thu | Account immediately locked. 30-day deletion clock starts. Data is inaccessible to anyone (including staff) during the countdown. |
| 10 | Parent has 3 children enrolled | Parent sees 3 tiles on "My Children"; tapping each shows that child's dashboard only. |

## 10. Dependencies

**Depends on:**
- Oakwood's Google Workspace for Education SSO tenant (already in place).
- USDA FoodData Central as the source for initial dish nutrition (public API).
- A JSON-configured age-bracket → target table, reviewed by school nurse quarterly.

**Depended on by:**
- Future v2 features: fitness-wearable integration, multi-school roll-out, teacher classroom-health view.

**External dependencies:**
- Google Workspace SSO (OIDC).
- USDA FoodData Central (seed only; not a runtime dependency).
- A transactional email provider for parent consent invites (e.g. SendGrid — exact vendor TBD in plan).

## 11. Open Questions

| # | Question | Impact | Owner | Resolution |
|---|----------|--------|-------|------------|
| 1 | For parent consent, do we require wet-signature workflow (mailed) or is SSO-verified email acceptable under COPPA? | Changes onboarding UX + legal review | School legal + PO | **Pending** — legal review scheduled 2026-04-19. Blocking. |
| 2 | Do we support student-initiated food logging via free-text / photo, or strictly from curated list in v1? | Scope — free text doubles effort | PO | **Resolved: strictly from curated list in v1.** Free text is a v2 candidate. |
| 3 | Who owns keeping the dish library + nutrition data current? | Operational | PO + school nurse | **Resolved: School nurse reviews quarterly; USDA FoodData pulled annually.** |
| 4 | Does "badge" wording risk feeling like extrinsic motivation / gamification backlash from parents? | Product design | PO + school counsellor | **Pending** — user-research session scheduled 2026-04-22. Non-blocking for spec; can refine naming during implementation. |

## 12. Out of Scope for V1 (Future Considerations)

- Integration with Fitbit / Apple Health / Google Fit.
- Teacher classroom-health dashboard (aggregated, de-identified).
- Multi-school / multi-tenant support.
- Free-text meal logging / photo-based meal recognition.
- Push notifications for meal-time reminders.
- In-app messaging between parent and school nurse.
- Export to PDF for pediatrician visits.
- Non-English localisation.

---

> **Next step:** Once Open Question #1 is resolved and this spec is APPROVED by the PO, run `/plan-gen docs/workshop/2026-04-17-nutrition-app/specs/001-nutrition-app/spec.md` to generate an implementation plan.
