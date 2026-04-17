# SDLC Central — Workshop Governance & Workflow Guide
## Building applications from scratch with multi-person AI-assisted teams

> Audience: Workshop participants taking real ideas from intake to running code, then maintaining them. This guide is the "rules of the road" — branching, role hand-offs, what skill to run when, how artefacts move between people, how security gates fire, and how the recursive fix-loop works.

---

## 0. The mental model in one paragraph

In SDLC Central, the **artefact is the contract**. A spec is not a Slack message — it's `specs/<NNN>-<slug>/spec.md` committed to a branch. A plan, tasks, decision log, review report, security audit, release notes — all of them are files in the repo. Hand-offs between team members are git operations, not meetings. Quality gates are commits-blocked-or-allowed, not Jira columns. Once you internalise this, the whole framework is just "the right slash command at the right point on the right branch".

---

## 1. Pre-workshop setup (do this once, before anything else)

### 1.1 Install the framework per role

Each participant runs **one** of:

```bash
bash setup/install-role.sh product-owner  --agent claude-code
bash setup/install-role.sh architect      --agent claude-code
bash setup/install-role.sh developer      --agent claude-code
bash setup/install-role.sh qa             --agent claude-code
bash setup/install-role.sh devops-sre     --agent claude-code
bash setup/install-role.sh tech-lead      --agent claude-code   # gets all 60 skills
bash setup/install-role.sh scrum-master   --agent claude-code
bash setup/install-role.sh designer       --agent claude-code
```

Tech Lead installs everything (orchestrator role). Everyone else gets only the skills relevant to their lane — this prevents accidental misuse (e.g. a PO running `task-implementer` directly).

### 1.2 Pick your gate profile up-front

Edit `config/gate-config.json` and commit on `main` before the workshop starts. Choose one:

| Profile | Use when | HITL gates | Test cov. floor | Critical findings allowed |
|---|---|---|---|---|
| `minimal` | Spike, prototype, throwaway | 2 | 40% | 1 |
| `standard` | Default for the workshop | 3 | 70% | 0 |
| `strict`  | Compliance / security-sensitive (auth, payments, PII) | 5 | 85% | 0 (also requires license + API contract checks) |

**Workshop recommendation: `standard` for first feature, switch to `strict` for the second.** This lets people feel both shapes.

### 1.3 Agree on the artefact root

Default is `specs/<NNN>-<slug>/`. Don't change this for the workshop — every skill defaults to this path and changing it just creates confusion.

---

## 2. Git branching strategy (the real question: do we need AI sandboxes?)

**Short answer: yes, but they look like ordinary feature branches.**

The framework does not require any special "AI branch" concept. What it *does* require is that the unit of work — one spec, one plan, one set of tasks, one implementation pass — lives on its own branch from intake through release. Here is the strategy I'd recommend for your workshop and ongoing use:

### 2.1 Branch types

| Branch | Purpose | Lifetime | Who creates |
|---|---|---|---|
| `main` | Always shippable. Protected. | Forever | Initial setup |
| `develop` *(optional)* | Integration of in-flight features. Use only if you ship multiple features per release. | Forever | Initial setup |
| `feature/NNN-<slug>` | One feature, one spec, end-to-end. **This is the AI sandbox.** | Until merged | Product Owner at intake |
| `fix/NNN-<slug>` | Bug fix tied to a bug-report artefact. | Until merged | QA or Developer |
| `hotfix/NNN-<slug>` | Production incident fix. Branched from `main`. | Until merged | DevOps/SRE |
| `experiment/<who>-<topic>` | Throwaway exploration. Never merges. | Until deleted | Anyone |
| `chore/<topic>` | Dependency updates, doc-gen sweeps, tech-debt audits. | Until merged | Developer / DevOps |

### 2.2 Why the feature branch *is* the AI sandbox

You will hear people argue for separate "ai-generated" branches that get squash-reviewed before merging into the human feature branch. **Don't do that.** It creates two-step review, doubles the merge surface, and obscures who-did-what in `git blame`. Instead:

1. The Product Owner creates `feature/NNN-<slug>` at intake. The branch's first commits are the spec and balance sheet — produced by AI but reviewed and approved by the PO at the HITL gate before commit.
2. Architect commits the plan + decision log to the same branch.
3. Developer commits implementation. Each task from `tasks.md` becomes one commit, with the task ID in the commit message: `task-3: implement RBAC middleware`. This makes it easy to bisect.
4. QA / DevOps commit reports and release artefacts to the same branch.
5. PR opens against `main` (or `develop`). Reviewer sees the *whole story* on one branch.

If you want to mark AI-generated commits, use a trailer line: `Generated-By: claude-code-skill: task-implementer`. Don't fragment the branch graph for it.

### 2.3 Branch protection rules (commit these to your repo)

On `main`:
- Require pull request before merging.
- Require status checks: `quality-gate-impl-to-release`, `security-audit`, `release-readiness`.
- Require CODEOWNERS approval (use the `code-ownership-mapper` skill to keep CODEOWNERS current).
- Disallow force-push.
- Disallow direct push (everyone goes through PR — including Tech Lead).

On `feature/*`:
- Allow force-push (people will rebase as the spec evolves).
- No required reviewers — review happens at PR time.

The framework's `approval-workflow-auditor` skill verifies these are actually enforced. Run it monthly.

### 2.4 Worktrees, not branch-switching

For developers running multiple features in parallel, use `git worktree` instead of switching branches. Reason: skill state files in `.sdlc/` and `.claude/pipelines/pipeline-state-*.json` are branch-bound, and switching branches with in-flight pipeline state will confuse `--resume`. Worktrees give each feature its own checkout and its own clean state directory.

```bash
git worktree add ../sdlc-feature-001-rbac feature/001-rbac
cd ../sdlc-feature-001-rbac
# pipeline state stays clean per worktree
```

---

## 3. The end-to-end flow for ONE feature, by role

This is the canonical happy path. We'll call the feature "001-rbac" throughout.

### Stage A — Intake (Product Owner, ~30 min)

```bash
git checkout main && git pull
git checkout -b feature/001-rbac

/feature-balance-sheet quick "Multi-tenant role-based access control"
# → produces a quick GO/NO_GO. If NO_GO, branch is deleted, no further work.

/run-pipeline product-owner/feature-intake "Multi-tenant RBAC"
# → spec-gen writes specs/001-rbac/spec.md
# → quality-gate spec-to-plan runs
#   ├─ if it fails: spec-evolve auto-invokes, asks PO clarifying questions
#   └─ re-runs the gate
# → feature-balance-sheet deep produces portfolio scoring
# → gate-briefing renders an executive brief
# → HITL pause: PO reviews and types "approve" / "reject"

git add specs/001-rbac/
git commit -m "intake: spec for 001-rbac

Generated-By: claude-code-skill: spec-gen, feature-balance-sheet"
git push -u origin feature/001-rbac
```

**What's now on the branch for the next person:**
- `specs/001-rbac/spec.md` (approved)
- `specs/001-rbac/balance-sheet.md`
- `specs/001-rbac/gate-briefing.md`

**Hand-off signal:** PO posts the branch name in the team channel + assigns the architect on the (still draft) PR.

### Stage B — Planning (Architect, ~1–2 h)

```bash
git fetch && git checkout feature/001-rbac

/run-pipeline architect/design-to-plan specs/001-rbac/spec.md
# → design-review reads the spec and current architecture, flags concerns
# → plan-gen writes specs/001-rbac/plan.md
# → quality-gate plan-to-tasks runs
# → decision-log captures architectural choices
# → HITL pause: Architect (and Tech Lead if strict profile) approve

git add specs/001-rbac/plan.md specs/001-rbac/decision-log.md
git commit -m "plan: implementation plan for 001-rbac"
git push
```

**Hand-off signal:** Architect re-assigns the PR to the developer. If multiple features are in flight that touch the same modules, **run `/plan-merge` first** to detect conflicts.

### Stage C — Implementation (Developer, ~4–8 h)

```bash
git fetch && git checkout feature/001-rbac
# Optional: git worktree add ../sdlc-001-rbac feature/001-rbac

/run-pipeline developer/feature-build specs/001-rbac/plan.md
# → task-gen writes specs/001-rbac/tasks.md
# → wave-scheduler computes parallel waves
# → task-implementer iterates: write test → run → write code → run
#   (each task = one commit with task ID)
# → spec-review verifies all acceptance criteria met
#   ├─ if drift detected: spec-fix auto-invokes
#   └─ if scope changed: spec-evolve, then re-plan
# → review-fix patches CRITICAL/HIGH review findings

# Before opening PR:
/run-pipeline developer/pr-workflow
# → pr-orchestrator decides which review skills are needed
# → review (full code review)
# → security-audit (fast SAST + secrets + dep check, ~1-2 min)
# → test-gen for any uncovered paths
```

**Open the PR.** Use:

```bash
gh pr ready
gh pr edit --add-reviewer @qa-lead,@architect
```

The PR description should be auto-generated from the implementation report:

```bash
/changelog-plain --from feature/001-rbac --for stakeholder
```

### Stage D — Test & Validate (QA, ~1–2 h)

```bash
git fetch && git checkout feature/001-rbac

/run-pipeline qa/test-strategy specs/001-rbac/spec.md
# → spec-review (independent, second opinion)
# → test-gen (fills coverage gaps)
# → regression-check (predicts which existing tests are at risk)

/run-pipeline qa/release-validation
# → release-readiness-checker (against the candidate)
# → spec-review (final AC verification)
# → quality-gate impl-to-release
```

If `release-readiness-checker` returns NO_GO, QA assigns the PR back to the developer with the report attached. Developer runs `/review-fix` and `/spec-fix` and pushes new commits. **The PR stays open — same branch, same spec, recursive fix-loop.**

### Stage E — Security gate (everyone — but DevOps owns the deep audit)

There are *two* security skills and they fire at different stages:

| Skill | Speed | When | Who runs it |
|---|---|---|---|
| `security-audit` | 1–2 min | Every PR, automatic in `pr-workflow` | Developer (in pre-PR pipeline) |
| `security-audit-deep` | 15–25 min | Pre-release on `strict` profile, monthly cadence, post-incident | DevOps/SRE or Tech Lead |

For the workshop, run both on the first feature so people see the difference:

```bash
/security-audit                              # fast, scoped to diff
/security-audit-deep --scope feature/001-rbac # IaC, container, SBOM, CVSS, STRIDE
```

**Findings classification & action:**
- **CRITICAL:** Block PR. `review-fix` auto-attempts. If unfixed, escalate to Architect.
- **HIGH:** Block PR on `standard`/`strict`. Auto-fix attempts via `review-fix`.
- **MEDIUM:** Tracked via `risk-tracker`, can be merged with explicit approval + risk acceptance entry.
- **LOW:** Logged. Swept up in `chore/security-cleanup` branches.

For PII / auth / payments features: also run `/license-compliance-audit` and `/api-contract-analyzer main` before merge.

### Stage F — Release (DevOps/SRE, ~30 min)

```bash
git fetch && git checkout feature/001-rbac

/run-pipeline product-owner/release-signoff
# (technically PO triggers this, but DevOps is in the room)
# → release-readiness-checker (final aggregate gate)
# → gate-briefing (release decision brief)
# → release-notes (categorised CHANGELOG)

# PO approves the HITL release gate.

# Merge:
gh pr merge --squash --auto

# Post-merge on main:
/run-pipeline devops-sre/deploy-verify
# → release-readiness-checker (one more time, against the merged main)
# → incident-detector (watch for anomalies post-deploy)
# → slo-sla-tracker (verify SLOs not breached)
```

If `incident-detector` flags something within the first hour:

```bash
/run-pipeline devops-sre/incident-response
# → incident-triager pulls logs + recent commits
# → rollback-assessor checks if HEAD~1 is safe to revert
#   (specifically: any irreversible DB migrations?)
# → if SAFE: revert; if RISKY: forward-fix on hotfix/<slug>
```

---

## 4. The recursive fix-loop (this is the part most teams get wrong)

Most "AI delivery" demos show a clean linear flow. Reality is iterative. Here's how SDLC Central handles iteration **without losing track of state**:

```
                ┌─────────────────────────────────────────────────┐
                │                                                  │
   spec ───►  spec-review  ──fail──►  spec-fix or spec-evolve  ───┘
     │           ▲
     │           │
   plan ───►  quality-gate plan-to-tasks  ──fail──►  re-plan
     │           ▲
     │           │
   tasks ──►  task-implementer  ──►  spec-review  ──fail──►  spec-fix
     │           ▲
     │           │
   review ──►  review-fix  ──►  re-review
     │           ▲
     │           │
   security-audit ──►  fix CRITICAL/HIGH  ──►  re-audit
     │           ▲
     │           │
   release-readiness  ──fail──►  back to whichever stage failed
```

### 4.1 Rules that keep the loop sane

1. **Never delete artefacts. Always evolve them.** `spec-evolve` and `spec-fix` update the spec in place with revision history. This preserves traceability.
2. **Every fix produces its own commit on the same branch.** Do not amend or squash mid-flight — that breaks task-ID traceability and `--resume` state.
3. **Pipelines are resumable.** If a gate fails and someone goes to lunch, `/run-pipeline <role>/<name> --resume` picks up exactly where it stopped. State lives in `.claude/pipelines/pipeline-state-<name>.json` (per worktree).
4. **Auto-recover before escalating.** Each gate has an `auto_recover` skill. The framework tries that first. Humans only see the gate when machines have given up.
5. **Loop limit: max 3 auto-fix attempts per gate.** After that, `auto-triage` escalates to HITL and the Scrum Master gets a `pipeline-monitor` alert.

### 4.2 What "stuck" looks like and who unsticks it

| Symptom | Detection | Action | Owner |
|---|---|---|---|
| Spec rewrites > 3 times | `pipeline-monitor scan` | Convene PO + Architect to resolve scope | Scrum Master |
| Same review finding fixed and reappearing | `review-fix` log | Pattern is wrong, escalate to Tech Lead for a `decision-log` entry | Tech Lead |
| Security finding can't be auto-fixed | `security-audit` re-run | Architect designs fix, decision-log entry, may require spec-evolve | Architect |
| Test coverage stuck below threshold | `release-readiness-checker` | `/test-gen` on uncovered modules; if still stuck, scope-tracker change request | Developer + QA |
| Plan-merge conflict between two features | `/plan-merge` output | Architect adjudicates phase ordering; may require one feature to wait | Architect + Tech Lead |

---

## 5. How artefacts move between team members (handoff playbook)

The hand-off is **always a git operation + an artefact reference**, never a verbal "I'm done".

### 5.1 The hand-off pattern

```
1. Producer commits and pushes the artefact on feature/NNN-<slug>.
2. Producer reassigns the open draft PR to the consumer.
3. Producer adds a one-line PR comment:
   "Ready for <next role>: artefact at specs/NNN-<slug>/<file>.md"
4. Consumer pulls the branch, opens the artefact, runs their pipeline.
5. Quality gate at the start of the consumer's pipeline validates the
   incoming artefact meets the threshold (e.g. plan-to-tasks gate
   verifies the plan has a risk section before letting tasks-gen run).
```

### 5.2 The hand-off matrix

| From → To | Trigger artefact | Consumer's first pipeline | Gate that validates incoming artefact |
|---|---|---|---|
| PO → Architect | `specs/NNN/spec.md` | `architect/design-to-plan` | `spec-to-plan` |
| Architect → Developer | `specs/NNN/plan.md` | `developer/feature-build` | `plan-to-tasks` |
| Developer → QA | implementation + `implementation-report.md` | `qa/test-strategy` then `qa/release-validation` | `tasks-to-impl`, then `impl-to-release` |
| QA → DevOps | `release-readiness.md` (PASS) | `devops-sre/deploy-verify` | `impl-to-release` (re-validated) |
| DevOps → PO | deploy verification + slo report | `product-owner/release-signoff` HITL | release HITL |
| Anyone → Scrum Master | stuck pipeline | `scrum-master/impediment-tracker` | n/a (monitoring) |
| Anyone → Tech Lead | escalation from gate | n/a — Tech Lead inspects directly | n/a |
| Designer → Architect | `specs/NNN/spec.md` (UX-derived) | `architect/design-to-plan` | `spec-to-plan` |

### 5.3 What the consumer should *always* do first

1. `git pull` the branch.
2. Open the incoming artefact and read it. Don't trust the producer's "it's done" — the gate exists for a reason but a 60-second human read catches things gates miss.
3. Run the consumer's pipeline. If the gate at the start fails, **don't** edit the artefact yourself — push it back to the producer with the gate's failure report.

This is the "no-silent-rework" rule. It prevents the situation where every consumer quietly fixes the producer's gaps and the producer never learns.

---

## 6. Cross-team coordination (when more than one feature is in flight)

### 6.1 Two POs intake two features in the same week

- Each gets their own `feature/NNN-<slug>` branch.
- If their balance sheets together exceed the portfolio limit (`max_concurrent_features` in `config/balance-sheet-config.json`, default 5), the framework flags it. The Tech Lead decides which proceeds.

### 6.2 Two architects plan features that touch the same module

- Both write `plan.md` on their own branches.
- Before either developer starts, run `/plan-merge specs/NNN-a/plan.md specs/NNN-b/plan.md`.
- Output is a merged execution order. May require feature B to wait until feature A's Phase 2 is complete.
- Decision goes into the `decision-log.md` of both features.

### 6.3 A developer's PR conflicts with main while in-flight

- Rebase, don't merge. Linear history matters because task-IDs and pipeline-state files are commit-bound.
- After rebase, re-run `/run-pipeline developer/pr-workflow`. The security-audit and review skills must re-validate against the new diff.

### 6.4 QA finds a bug after release

```bash
git checkout main && git pull
git checkout -b fix/047-rbac-tenant-leak

/bug-report "RBAC allows tenant A to read tenant B's resources via /api/v1/orgs/list"
# → produces structured bug report under specs/047-rbac-tenant-leak/

/run-pipeline qa/bug-to-fix
# → impact-analysis maps blast radius

# Hand to developer; flow continues exactly as a feature would,
# but on a fix/ branch with priority routing.
```

### 6.5 Production incident

```bash
git checkout main && git pull
git checkout -b hotfix/049-auth-latency

/run-pipeline devops-sre/incident-response "API latency spike on auth-service post-deploy v2.4.0"
# → incident-detector confirms
# → incident-triager produces triage report with root-cause candidates
# → rollback-assessor: SAFE / RISKY / BLOCKED

# If SAFE → git revert <commit> on hotfix branch, fast-track PR to main.
# If RISKY → forward-fix using a mini feature flow (spec-gen, plan-gen with the
#            triage report as input, expedited HITL gates).

# After resolution:
/incident-postmortem-synthesizer
# → writes .sdlc/incidents/incident-049-postmortem.md
# Tech Lead reviews monthly aggregations via the same skill.
```

---

## 7. Governance ceremonies (the cadence)

| Ceremony | Frequency | Pipeline / Skills | Owner |
|---|---|---|---|
| Daily standup | Daily | `scrum-master/sprint-tracking` (board-sync, scope-tracker, risk-tracker) | Scrum Master |
| Pipeline health check | Daily, async | `pipeline-monitor scan` | Scrum Master |
| Sprint planning | Bi-weekly | `feature-balance-sheet deep` per candidate | PO + Tech Lead |
| Sprint retrospective | Bi-weekly | `scrum-master/retrospective-data` (feedback-loop, report-trends) | Scrum Master |
| Architecture review | Monthly | `architect/system-health` (tech-debt-audit, code-ownership-mapper, api-contract-analyzer) | Architect |
| Team health | Monthly | `tech-lead/team-health` (code-ownership-mapper, skill-gap-analyzer) | Tech Lead |
| Dependency sweep | Monthly | `developer/maintenance` (dependency-update, tech-debt-audit, regression-check) | Developer rotation |
| Deep security | Monthly | `security-audit-deep`, `license-compliance-audit` | DevOps/SRE |
| Governance audit | Quarterly | `tech-lead/governance` (license, standards, approval-workflow-auditor) | Tech Lead |
| Incident pattern review | Quarterly | `incident-postmortem-synthesizer` | DevOps + Tech Lead |
| Drift scan | Quarterly | `drift-detector scan` per major spec | Architect |

Put these on the calendar. The framework can produce the artefacts; only humans can make the meeting happen.

---

## 8. Workshop schedule (proposed)

For your tomorrow session, here's a 6-hour agenda that exercises everything above:

| Time | Block | What happens |
|---|---|---|
| 09:00–09:15 | Welcome | Play the overview video. |
| 09:15–09:45 | Setup | Everyone runs `setup/install-role.sh` for their role. Tech Lead commits `gate-config.json` set to `standard`. |
| 09:45–10:15 | Idea triage | Each PO brings 2 ideas. Run `/feature-balance-sheet quick` on each. Pick top 2 to take forward. |
| 10:15–10:30 | Break | |
| 10:30–11:30 | Feature 1 — Intake & Planning | PO runs feature-intake. Architect runs design-to-plan. Live walk-through of the hand-off. |
| 11:30–12:30 | Feature 1 — Implementation | Developer runs feature-build. Pair-program with the framework. Watch task-implementer work. |
| 12:30–13:30 | Lunch | |
| 13:30–14:15 | Feature 1 — Review, Security, Release | pr-workflow → security-audit → release-validation → deploy-verify. **Inject a security finding deliberately** to demonstrate the recursive fix loop. |
| 14:15–14:30 | Switch profile to `strict`. | Edit `gate-config.json`. Discuss what changes. |
| 14:30–15:30 | Feature 2 — Same flow on strict | Take a second idea through. Notice the extra HITL gates and the deep security audit step. |
| 15:30–15:45 | Break | |
| 15:45–16:30 | Reflection | Run `/feedback-loop analyze`, `/report-trends dashboard`, `/scope-tracker report`. Discuss what the framework taught us about our process. |
| 16:30–17:00 | Q&A and Monday plan | What does each role do on Monday morning to keep this going? |

---

## 9. Common failure modes and how to avoid them

1. **"We skipped the spec because it was a small change."** This is how the framework dies. *Every* change goes through at least `user-story-refiner` or `bug-report`, even a one-line fix. The artefact takes 90 seconds; the audit trail it creates is permanent.

2. **"The AI wrote it; we don't need to review."** No. `review` is mandatory before merge. The framework's review skill catches issues humans miss; humans catch nuance the framework misses. Both must run.

3. **"Tech Lead approved everything to keep things moving."** Bypassing HITL gates defeats the point. If a profile is too strict for the work, change the profile (a deliberate, logged act) — don't rubber-stamp.

4. **"We branched off a feature branch."** Don't. Each feature is its own branch off `main`. Branching off another feature branch creates merge tangles and breaks pipeline state.

5. **"We re-ran the pipeline from scratch instead of `--resume`."** Wastes time and creates duplicate artefacts. Always `--resume` unless you've explicitly reset state.

6. **"We edited the spec directly instead of using `spec-evolve`."** Loses revision history. Always evolve.

7. **"We let MEDIUM security findings accumulate."** They become CRITICAL eventually. Sweep them every sprint via `chore/security-cleanup` branches.

8. **"We installed all 60 skills for everyone."** Confuses people, increases blast radius. Install per role; only Tech Lead gets all.

---

## 10. Cheat sheet — slash commands by role

### Product Owner
```
/feature-balance-sheet quick "<idea>"
/run-pipeline product-owner/feature-intake "<feature>"
/run-pipeline product-owner/release-signoff
/run-pipeline product-owner/sprint-health
/run-pipeline product-owner/stakeholder-update
```

### Architect
```
/run-pipeline architect/design-to-plan specs/NNN/spec.md
/run-pipeline architect/system-health
/run-pipeline architect/migration-planning
/plan-merge specs/A/plan.md specs/B/plan.md
/decision-log capture specs/NNN/plan.md
```

### Developer
```
/run-pipeline developer/feature-build specs/NNN/plan.md
/run-pipeline developer/pr-workflow
/run-pipeline developer/maintenance
/review-fix specs/NNN/code-review.md
/spec-fix specs/NNN/spec-compliance.md
```

### QA
```
/run-pipeline qa/test-strategy specs/NNN/spec.md
/run-pipeline qa/regression-suite
/run-pipeline qa/release-validation
/run-pipeline qa/bug-to-fix
```

### DevOps / SRE
```
/run-pipeline devops-sre/deploy-verify
/run-pipeline devops-sre/incident-response "<description>"
/run-pipeline devops-sre/platform-health
/security-audit-deep --scope <feature-or-module>
/rollback-assessor HEAD~1
```

### Tech Lead
```
/run-pipeline tech-lead/full-pipeline specs/NNN/spec.md --gates standard
/run-pipeline tech-lead/team-health
/run-pipeline tech-lead/governance
/pipeline-orchestrator run specs/NNN/spec.md
```

### Scrum Master
```
/run-pipeline scrum-master/sprint-tracking
/run-pipeline scrum-master/retrospective-data
/run-pipeline scrum-master/impediment-tracker
/pipeline-monitor scan
/auto-triage <path-to-failed-report>
```

### Designer
```
/run-pipeline designer/design-handoff
/run-pipeline designer/design-implementation
/run-pipeline designer/design-system-sync
/visual-review <figma-url> --implementation src/components/X.tsx
/design-token-sync <figma-url> --format tailwind
```

---

## 11. Final principle

> **The framework is not in charge. You are.** The skills are tools. The pipelines are conventions. The gates are guard-rails you chose. Every approve / reject / fix decision is a human one. AI handles the toil; you handle the judgement. Done well, this is the most leverage a software team has ever had — and the most accountability.

See you in the workshop.
