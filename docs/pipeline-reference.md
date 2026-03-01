# Pipeline Reference

SDLC Central includes 30 composable pipelines organized by role. Each pipeline chains skills together in a dependency-ordered sequence with quality gates and human-in-the-loop checkpoints.

## Running a Pipeline

**Claude Code:**
```
/run-pipeline developer/feature-build specs/auth/plan.md
```

**Cursor / Copilot / Windsurf / Cline / Gemini:**
```
Run the developer/feature-build pipeline on specs/auth/plan.md
```

### Flags

- `--dry-run` -- show the step chain and gates without executing
- `--resume` -- resume a previously paused pipeline from the last completed step
- `--gates minimal|standard|strict` -- override quality gate profile

---

## Product Owner (6 pipelines)

### feature-intake (5 steps)
**Chain:** feature-balance-sheet (quick) -> spec-gen -> quality-gate -> feature-balance-sheet (deep) -> gate-briefing

Evaluate a feature request end-to-end: quick cost-benefit filter, spec generation, quality validation, deep portfolio analysis, and executive briefing with HITL approval.

### sprint-health (4 steps)
**Chain:** scope-tracker -> board-sync -> report-trends -> risk-tracker

Sprint progress dashboard with scope change tracking, PM tool sync, trend analysis, and risk escalation.

### release-signoff (3 steps)
**Chain:** release-readiness-checker -> gate-briefing -> release-notes

Release go/no-go decision: aggregate readiness signals, generate executive briefing with HITL approval, then produce release notes.

### stakeholder-update (2 steps)
**Chain:** progress-summary -> changelog-plain

Generate a non-technical status update: gather progress from git activity, then translate changes into plain business language for stakeholder meetings.

### idea-to-spec (3 steps)
**Chain:** user-story-refiner -> spec-gen -> spec-review

Transform a rough feature idea into a reviewed specification: refine into a structured user story, generate a full spec, and validate for completeness. Includes quality gate with auto-recovery.

### sprint-demo (3 steps)
**Chain:** progress-summary -> demo-prep -> changelog-plain

Prepare a complete sprint demo package: gather sprint progress, build a walkthrough script with click paths, and produce a plain-English changelog for the audience.

---

## Architect (3 pipelines)

### design-to-plan (4 steps)
**Chain:** design-review -> plan-gen -> quality-gate -> decision-log

Transform an approved spec into a validated implementation plan with architectural decision tracking.

### system-health (4 steps)
**Chain:** tech-debt-audit -> code-ownership-mapper -> api-contract-analyzer -> report-trends

Comprehensive architectural health assessment covering tech debt, ownership risks, API breaking changes, and metric trends.

### migration-planning (4 steps)
**Chain:** migration-tracker -> impact-analysis -> plan-gen -> plan-merge

Plan a technical migration: track current state, analyze blast radius, generate phased plan, merge with existing plans. Includes HITL review before merge.

---

## Developer (3 pipelines)

### feature-build (5 steps)
**Chain:** task-gen -> wave-scheduler -> task-implementer -> spec-review -> review-fix

Build a feature from an approved plan: break into tasks, schedule execution waves, implement with TDD, verify spec compliance, and auto-fix findings.

### pr-workflow (4 steps)
**Chain:** pr-orchestrator -> review -> security-audit -> test-gen

Pre-PR quality checks: analyze changes, run code review, scan for security issues, generate tests for uncovered paths.

### maintenance (3 steps)
**Chain:** dependency-update -> tech-debt-audit -> regression-check

Periodic codebase upkeep: update dependencies, audit tech debt, predict regressions.

---

## QA (4 pipelines)

### test-strategy (3 steps)
**Chain:** spec-review -> test-gen -> regression-check

Create a test plan from a spec: review for testability, generate tests, predict regressions.

### regression-suite (3 steps)
**Chain:** regression-check -> perf-review -> report-trends

Regression and performance analysis with trend dashboard generation.

### release-validation (3 steps)
**Chain:** release-readiness-checker -> spec-review -> quality-gate

Pre-release quality gate: aggregate readiness signals, validate spec compliance, enforce final quality thresholds.

### bug-to-fix (2 steps)
**Chain:** bug-report -> impact-analysis

From a plain-English bug description to a structured report: generate an actionable bug report, then analyze the blast radius across the codebase. Ready for a developer to pick up.

---

## DevOps/SRE (3 pipelines)

### deploy-verify (3 steps)
**Chain:** release-readiness-checker -> incident-detector -> slo-sla-tracker

Post-deployment health check: verify release criteria, detect incidents from deployment signals, check SLO and error budgets.

### incident-response (3 steps)
**Chain:** incident-detector -> incident-triager -> rollback-assessor

Incident detection through remediation: confirm and classify the incident, triage with root cause analysis, evaluate rollback safety. Includes HITL gate before action.

### platform-health (3 steps)
**Chain:** slo-sla-tracker -> approval-workflow-auditor -> cross-repo-standards-enforcer

Platform governance audit: SLO and DORA metrics, approval workflow compliance, repository standards enforcement.

---

## Tech Lead (3 pipelines)

### full-pipeline (1 orchestrated step, 12+ sub-steps)
**Chain:** pipeline-orchestrator (delegates full DAG: spec -> plan -> tasks -> impl -> review -> release)

End-to-end delivery automation. The pipeline-orchestrator manages the entire SDLC DAG with multiple HITL gates (spec approval, plan approval, release approval).

### team-health (4 steps)
**Chain:** code-ownership-mapper -> skill-gap-analyzer -> report-trends -> feedback-loop

Team and process health: ownership and bus factor risks, capability gaps, cross-metric trends, pipeline effectiveness analysis.

### governance (3 steps)
**Chain:** license-compliance-audit -> cross-repo-standards-enforcer -> approval-workflow-auditor

Compliance audit: OSS license scanning, repository standards enforcement, branch policy and environment controls audit.

---

## Scrum Master (3 pipelines)

### sprint-tracking (3 steps)
**Chain:** board-sync -> scope-tracker -> risk-tracker

Sprint progress: sync PM tool status, track scope changes, scan and escalate risks.

### retrospective-data (3 steps)
**Chain:** feedback-loop -> report-trends -> scope-tracker

Gather retrospective data: pipeline effectiveness analysis, trend dashboard, scope change trends across sprints.

### impediment-tracker (3 steps)
**Chain:** pipeline-monitor -> auto-triage -> risk-tracker

Resolve blockers: detect stuck tasks and anomalies, classify failures with automated recovery, update risk register with escalation.

---

## Designer (5 pipelines)

### design-implementation (5 steps)
**Chain:** design-to-code -> component-audit -> design-to-code -> visual-review -> design-token-sync

Translate a Figma design into code: extract design context, resolve component mappings, implement, verify visual fidelity, and sync tokens. Includes quality gate on visual review with auto-recovery.

### design-system-sync (4 steps)
**Chain:** design-token-sync -> component-audit -> design-token-sync -> design-review

Synchronize the design system: extract tokens from Figma, audit component coverage, apply token updates, and review for consistency.

### design-handoff (4 steps)
**Chain:** design-to-code -> spec-gen -> spec-review -> doc-gen

Prepare a design for engineering handoff: extract design context, generate spec, review for completeness, and produce handoff documentation. Includes HITL gate for designer approval.

### spec-collaboration (2 steps)
**Chain:** spec-gen -> spec-review

Validate design aligns with specification: generate spec from design requirements, review for completeness and design intent.

### design-validation (2 steps)
**Chain:** design-review -> api-contract-analyzer

Validate implementation matches design: review architecture and patterns, verify API contracts match design specifications.

---

## Pipeline YAML Schema

All pipeline definitions live in `pipelines/<role>/<name>.pipeline.yaml`. Each file defines metadata, an ordered list of steps with skill references and dependency declarations, and optional quality gates. See [Customization](customization.md) for creating your own pipelines.
