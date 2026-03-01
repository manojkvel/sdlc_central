# Skill Reference

All 60 SDLC Central skills listed by category. Each skill can be invoked as a slash command in Claude Code or described to any supported agent.

## Role Matrix

Which roles receive which skills during installation.

| Role | Count | Included Skills |
|------|------:|----------------|
| Product Owner | 18 | feature-balance-sheet, spec-gen, quality-gate, gate-briefing, scope-tracker, board-sync, report-trends, risk-tracker, release-readiness-checker, release-notes, decision-log, drift-detector, changelog-plain, progress-summary, demo-prep, user-story-refiner, bug-report, codebase-qa |
| Architect | 18 | design-review, plan-gen, quality-gate, decision-log, tech-debt-audit, code-ownership-mapper, api-contract-analyzer, report-trends, migration-tracker, impact-analysis, plan-merge, spec-gen, spec-review, spec-evolve, feature-balance-sheet, gate-briefing, reverse-engineer, component-audit |
| Developer | 22 | task-gen, wave-scheduler, task-implementer, spec-review, review-fix, pr-orchestrator, review, security-audit, test-gen, dependency-update, tech-debt-audit, regression-check, spec-fix, doc-gen, perf-review, plan-gen, spec-gen, impact-analysis, onboarding-guide, design-review, design-to-code, visual-review |
| QA | 13 | spec-review, test-gen, regression-check, perf-review, report-trends, release-readiness-checker, quality-gate, security-audit, api-contract-analyzer, drift-detector, visual-review, bug-report, codebase-qa |
| DevOps/SRE | 14 | release-readiness-checker, incident-detector, slo-sla-tracker, incident-triager, rollback-assessor, approval-workflow-auditor, cross-repo-standards-enforcer, pipeline-monitor, dependency-update, security-audit, incident-postmortem-synthesizer, migration-tracker, report-trends, risk-tracker |
| Tech Lead | 60 | All skills |
| Scrum Master | 14 | board-sync, scope-tracker, risk-tracker, feedback-loop, report-trends, pipeline-monitor, auto-triage, wave-scheduler, gate-briefing, changelog-plain, progress-summary, demo-prep, bug-report, codebase-qa |
| Designer | 13 | spec-gen, spec-review, design-review, api-contract-analyzer, doc-gen, design-to-code, design-token-sync, component-audit, visual-review, bug-report, codebase-qa, user-story-refiner, changelog-plain |

---

## Planning & Specification

| Skill | Invocation | Description |
|-------|-----------|-------------|
| spec-gen | `/spec-gen 'feature description'` | Generate a structured technical specification from a feature description or requirements file |
| plan-gen | `/plan-gen path/to/spec.md` | Generate a phased implementation plan from an approved specification |
| task-gen | `/task-gen path/to/plan.md` | Break an implementation plan into atomic, dependency-ordered tasks |
| plan-merge | `/plan-merge specs/*/plan.md` | Merge multiple plan outputs into a unified execution plan, resolving conflicts |
| spec-evolve | `/spec-evolve revise path/to/spec.md` | Manage the spec lifecycle with versioned revisions and child specs |
| spec-fix | `/spec-fix path/to/spec-review.md` | Close spec compliance gaps identified by spec-review |
| spec-review | `/spec-review path/to/spec.md` | Validate that implementation matches the original specification |
| user-story-refiner | `/user-story-refiner 'rough feature idea'` | Transform a rough feature idea into a structured user story with acceptance criteria and scope boundaries |

## Development

| Skill | Invocation | Description |
|-------|-----------|-------------|
| task-implementer | `/task-implementer path/to/tasks.md` | Implement tasks with TDD, traceability back to spec, and incremental commits |
| wave-scheduler | `/wave-scheduler path/to/tasks.md` | Compute a parallel execution schedule from task dependencies |
| review | `/review` | Comprehensive code review covering quality, patterns, correctness, and maintainability |
| review-fix | `/review-fix path/to/review.md` | Auto-fix CRITICAL and HIGH findings from a code review report |
| pr-orchestrator | `/pr-orchestrator auto` | Analyze PR changes and determine which quality checks to run automatically |
| doc-gen | `/doc-gen api` | Generate or update documentation (API docs, README, changelog) |
| test-gen | `/test-gen path/to/module` | Generate comprehensive tests for a file, module, or uncovered code paths |
| design-to-code | `/design-to-code <figma-url>` | Translate a Figma design into production code using MCP-backed design context and component mappings |
| design-token-sync | `/design-token-sync <figma-url> --format tailwind` | Extract design tokens from Figma variables and sync with codebase token files |

## Quality & Security

| Skill | Invocation | Description |
|-------|-----------|-------------|
| quality-gate | `/quality-gate impl-to-release path/to/artifact` | Enforce automated stage gates between pipeline stages with configurable thresholds |
| regression-check | `/regression-check` | Predict what existing tests and behavior might break from recent changes |
| perf-review | `/perf-review diff` | Review code for performance regressions, N+1 queries, memory leaks, and hot paths |
| security-audit | `/security-audit` | Scan code for security vulnerabilities, secrets, injection risks, and auth issues |
| visual-review | `/visual-review <figma-url> --implementation path/to/component` | Compare implemented UI against Figma design for layout, spacing, color, and typography fidelity |
| api-contract-analyzer | `/api-contract-analyzer main` | Detect breaking API changes by comparing the API surface against a baseline branch |
| bug-report | `/bug-report 'description of the problem'` | Generate a structured, actionable bug report from a plain-English description |
| license-compliance-audit | `/license-compliance-audit full` | Scan all dependencies for OSS license conflicts and policy violations |

## Pipeline & Automation

| Skill | Invocation | Description |
|-------|-----------|-------------|
| pipeline-orchestrator | `/pipeline-orchestrator run path/to/spec` | End-to-end SDLC pipeline automation from spec through release |
| auto-triage | `/auto-triage path/to/failed-report` | Classify pipeline failures and attempt automated recovery |
| pipeline-monitor | `/pipeline-monitor scan` | Detect stuck tasks, fix loops, stale artifacts, and anomalies in running pipelines |
| gate-briefing | `/gate-briefing --audience executive path/to/spec` | Generate decision-ready briefings at human-in-the-loop gates |
| feedback-loop | `/feedback-loop analyze` | Analyze pipeline execution history to identify patterns and calibrate estimates |

## Decision & Tracking

| Skill | Invocation | Description |
|-------|-----------|-------------|
| decision-log | `/decision-log capture path/to/spec.md` | Capture and track architectural decisions alongside specs and plans |
| feature-balance-sheet | `/feature-balance-sheet quick 'feature idea'` | Pre-spec cost-benefit assessment and portfolio-level prioritization |
| risk-tracker | `/risk-tracker scan --all` | Maintain a living risk register with severity tracking and escalation |
| scope-tracker | `/scope-tracker report path/to/spec` | Track scope changes across the project lifecycle with effort deltas |
| impact-analysis | `/impact-analysis path/to/file` | Analyze the blast radius of proposed changes across the codebase |

## Integration

| Skill | Invocation | Description |
|-------|-----------|-------------|
| board-sync | `/board-sync status` | Sync SDLC artifacts with project management tools (Jira, Azure Boards, Linear, GitHub Projects) |
| dependency-update | `/dependency-update --fix` | Check for outdated and vulnerable dependencies, optionally auto-fix |
| release-notes | `/release-notes --version v2.1.0` | Auto-generate categorized release notes from commit and spec history |
| release-readiness-checker | `/release-readiness-checker v2.1.0` | Aggregate signals from pipelines, tests, and audits into a go/no-go verdict |
| rollback-assessor | `/rollback-assessor HEAD~1` | Evaluate whether rolling back to a given commit is safe |
| approval-workflow-auditor | `/approval-workflow-auditor full` | Audit branch policies, pipeline gates, and environment approval controls |

## Governance

| Skill | Invocation | Description |
|-------|-----------|-------------|
| code-ownership-mapper | `/code-ownership-mapper risks` | Map code ownership from git history -- identify experts, knowledge silos, bus factor risks |
| cross-repo-standards-enforcer | `/cross-repo-standards-enforcer full` | Audit a repository against organizational coding and process standards |
| drift-detector | `/drift-detector scan` | Monitor divergence between spec intent and implementation reality |
| component-audit | `/component-audit <figma-url> --scope full` | Audit codebase components against Figma design system for drift and unmapped components |
| tech-debt-audit | `/tech-debt-audit full` | Full codebase health check -- complexity, duplication, outdated patterns |
| migration-tracker | `/migration-tracker status` | Track long-running technical migration progress across phases |

## Reporting & Knowledge

| Skill | Invocation | Description |
|-------|-----------|-------------|
| report-trends | `/report-trends dashboard` | Analyze report history and surface trends across all tracked metrics |
| changelog-plain | `/changelog-plain latest` | Translate technical changelogs into plain business language for stakeholders |
| progress-summary | `/progress-summary weekly` | Generate a plain-English progress report from git activity for stakeholders |
| demo-prep | `/demo-prep sprint` | Generate a sprint demo walkthrough script with click paths and known limitations |
| codebase-qa | `/codebase-qa 'does our app support dark mode?'` | Answer plain-English questions about what the codebase does without requiring the asker to read code |
| onboarding-guide | `/onboarding-guide full` | Generate a how-this-codebase-works guide for new team members |
| skill-gap-analyzer | `/skill-gap-analyzer full` | Analyze the codebase and team to recommend missing skills and capability gaps |
| incident-detector | `/incident-detector scan` | Correlate deployments with observability signals to detect incidents |
| incident-triager | `/incident-triager 'description'` | Produce a triage report with root cause candidates and remediation steps |
| incident-postmortem-synthesizer | `/incident-postmortem-synthesizer full` | Analyze incident history and surface recurring failure patterns |
| slo-sla-tracker | `/slo-sla-tracker full` | Track SLOs, DORA metrics, and error budgets across services |
| design-review | `/design-review full` | Review architecture and design patterns for correctness and maintainability |
| reverse-engineer | `/reverse-engineer full` | Reverse-engineer a codebase into structured technical documentation |
