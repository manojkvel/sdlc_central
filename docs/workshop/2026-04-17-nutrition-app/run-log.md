# NutriKids Role-Play — End-to-End Run Log

*Workshop: 2026-04-17 | Use case: NutriKids nutrition app for Oakwood Public School*
*Purpose: demonstrate the full SDLC-Central pipeline exactly as described in `02-governance-and-workflow-guide.md`.*

---

## 1. Cast

| Role | Name | Stage |
|------|------|-------|
| Product Owner | Priya | A — intake |
| Architect | Arjun | B — design → plan |
| Developer | Mahesh (+ Karan, Anita as pair) | C — task breakdown + implement |
| QA | Anita | D — spec compliance + tests |
| Security | Vikram | E — audit + fix-loop |
| DevOps | Pradeep | F — release + verify |

## 2. Branch & commit timeline (`feature/001-nutrition-app`)

| Commit | Stage | Artefacts added |
|--------|-------|-----------------|
| `09de8c9` | A — PO | spec, balance-sheet, gate-spec-to-plan, gate-briefing-intake |
| `f4e106b` | B — Architect | plan, decision-log, gate-plan-to-tasks |
| `ff54c5a` | C — Dev | tasks, wave-schedule, task-implementer-002 (sample) |
| `1e95d8b` | D — QA | spec-compliance, test-plan-rls-isolation |
| `08aebfe` | E — Security | security-audit, review-fix-loop, license-audit, api-contract |
| (next) | F — DevOps | release-readiness, release-notes, deploy-verify |

## 3. Gates fired

| Gate | Profile | Stage | Verdict | Notes |
|------|---------|-------|---------|-------|
| `balance-sheet-quick` (decision) | — | A | GO w/ conditions | Benefit 3.95 / Cost 2.95 |
| `spec-to-plan` (quality) | standard | A | PASS | 10 AC / 10 edges / security present / non-goals present |
| `approve-spec` (HITL) | standard | A | APPROVE-WITH-CONDITIONS | PO Priya — COPPA consent carried to plan |
| `plan-to-tasks` (quality) | standard | B | PASS | 7 phases / risk / rollback all present |
| `approve-plan` (HITL) | standard | B | APPROVE | Arjun signed |
| (wave boundary) `approve-plan-stage` (HITL) | standard | C | APPROVE | W3 review |
| `tasks-to-impl` (quality) | strict | D→E | PASS | coverage 88% / contracts in place |
| `impl-to-release` (quality) | strict | E | **FAIL → RETRY → PASS** | 1 CRIT + 1 HIGH → fixed → missing audits → run → PASS |
| `approve-impl` (HITL) | strict | E | APPROVE | Priya + Arjun + Security signed |
| `approve-release` (HITL) | strict | F | APPROVE | Pradeep + Priya signed |

## 4. Recursive recovery in action

The review-fix loop ran **twice** on `impl-to-release`:

- **Round 1:** Closed SEC-001 (CRITICAL, COPPA retention) + SEC-002 (HIGH, dashboard authz). Gate failed again — but for a *different* reason (missing license + API contract audits).
- **Round 2:** Ran the two missing audits. Gate PASSED.

**Loop budget used:** 2 of 3 allowed attempts. No human escalation needed.

Workshop lesson: the loop surfaced a **real pipeline gap** (no pipeline currently invokes `license-compliance-audit` or `api-contract-analyzer` despite strict profile demanding them). That matches finding #5 in `03-pipeline-test-report.md`. The pipeline test said "this will bite you"; the role-play proved it.

## 5. Handoff pattern observed

Every stage handoff was **purely via git**. No DM, no verbal sync required.

- Arjun picked up the spec by reading `spec.md` on `feature/001-nutrition-app`.
- Mahesh picked up the plan the same way.
- Anita picked up the tasks the same way.
- Vikram ran the audit against the committed code surface described in the artefacts.
- Pradeep built the release against the committed security PASS state.

**"The artefact is the contract"** — the governance guide's claim verified by this run.

## 6. What the workshop can use this for

- **Show the full flow** start-to-finish in 45 minutes by scrolling commits and reading each artefact.
- **Teach the failure-injection drill** via `review-fix-loop.md` — then have attendees inject their own.
- **Teach gate profiles** by pointing at the profile switch between Stage B (standard) and Stage E (strict).
- **Teach wave scheduling** by running `/wave-scheduler` on the real `tasks.md` and discussing the 2.3× parallelism gain.

## 7. Backlog (issues uncovered during the role-play)

| # | Finding | Owner | Priority |
|---|---------|-------|----------|
| B-1 | No pipeline invokes `license-compliance-audit` despite `require_license_audit: true` in strict | Tech Lead | HIGH |
| B-2 | No pipeline invokes `api-contract-analyzer` despite `require_api_contract_check: true` in strict | Tech Lead | HIGH |
| B-3 | Developer pipeline lacks `tasks-to-impl` gate (found in dry-run, confirmed in role-play) | Tech Lead | MED |
| B-4 | QA `release-validation` pipeline has no `auto_recover` hook | Tech Lead | MED |
| B-5 | 10 skills missing legacy `SKILL.md` files (cosmetic — no workshop impact) | Any | LOW |

## 8. What would change in a real engagement

- **Actual code** in `apps/` (this run produced artefacts only — the implementer run-log was illustrative).
- **Real HITL signatures** (Priya's APPROVE in `gate-briefing-intake.md` is roleplay).
- **Real legal response** on OQ-1 (here stipulated for the flow to continue).
- **Real canary metrics** instead of simulated numbers.

Everything else — the artefact structure, commit cadence, gate mechanics, recovery loop — is exactly how the pipeline would run in anger.

---

## 9. Closing principle

> **Specs are code. Gates are tests. Commits are the handoff. The loop fixes itself or tells you when it can't.**

That's the AI DLC productivity story in one line. The rest is discipline.
