# End-to-End Walkthrough: Building an RBAC Feature

This walkthrough follows a role-based access control (RBAC) feature from initial idea through release readiness. Each step uses a single SDLC Central skill, showing what you type, what the agent produces, and the artifact created.

All example artifacts are stored in `examples/rbac-feature/`.

---

## Step 1: Assess the Feature

Before investing time in a full spec, run a quick cost-benefit filter.

**What you type:**
```
/feature-balance-sheet quick "Add RBAC for multi-tenant users"
```

**What the agent produces:**
A cost-benefit assessment with a recommendation of GO, NO_GO, or CONDITIONAL. The quick mode evaluates complexity, risk, strategic alignment, and estimated effort in under a minute.

**Artifact:** `examples/rbac-feature/feature-balance-sheet.md`

If the result is NO_GO, stop here. If CONDITIONAL, address the flagged concerns before proceeding. For this walkthrough, we received GO.

---

## Step 2: Write the Spec

Generate a structured technical specification from the feature description.

**What you type:**
```
/spec-gen "Add role-based access control with roles, permissions, and resource-level policies"
```

**What the agent produces:**
A complete spec document with sections for overview, requirements, acceptance criteria, API contracts, data models, security considerations, and open questions. The spec follows a standardized format that downstream skills can parse.

**Artifact:** `examples/rbac-feature/spec.md`

---

## Step 3: Validate the Spec

Run the quality gate to check whether the spec meets the bar for planning.

**What you type:**
```
/quality-gate spec-to-plan specs/rbac/spec.md
```

**What the agent produces:**
A PASS or FAIL verdict with a score breakdown. The gate checks completeness (all required sections present), clarity (no ambiguous requirements), testability (acceptance criteria are verifiable), and feasibility (no impossible constraints). If it fails, the gate report identifies exactly which sections need work.

**Artifact:** `examples/rbac-feature/quality-gate-spec.md`

If the gate fails, you have two options. Run `/spec-evolve revise specs/rbac/spec.md` to address the feedback and re-run the gate. Or, if the pipeline is running, `auto-triage` will attempt recovery automatically.

---

## Step 4: Create the Plan

Generate an implementation plan from the approved spec.

**What you type:**
```
/plan-gen specs/rbac/spec.md
```

**What the agent produces:**
An implementation plan that breaks the spec into architectural components, defines module boundaries, specifies interfaces, identifies dependencies between components, and establishes an implementation sequence. The plan maps every spec requirement to a concrete implementation strategy.

**Artifact:** `examples/rbac-feature/plan.md`

---

## Step 5: Break into Tasks

Convert the plan into atomic, implementable tasks organized in dependency waves.

**What you type:**
```
/task-gen specs/rbac/plan.md
```

**What the agent produces:**
A task list with approximately 12 tasks organized into 4 waves. Each task includes a unique ID (TASK-001 through TASK-012), a description, acceptance criteria, estimated complexity, the spec requirement it traces to, and its dependencies on other tasks. Wave 1 contains foundation tasks (models, migrations). Wave 2 covers core logic (permission engine, role assignment). Wave 3 handles integration (middleware, API endpoints). Wave 4 addresses cross-cutting concerns (audit logging, admin UI).

**Artifact:** `examples/rbac-feature/tasks.md`

---

## Step 6: Implement

Execute a task with TDD and full traceability to the plan.

**What you type:**
```
/task-implementer TASK-001
```

**What the agent produces:**
Working code with tests. The skill reads the task definition, writes failing tests first, implements the code to make them pass, and records traceability links back to the plan and spec. Each implemented task generates a mini-report showing files changed, tests added, and spec requirements covered.

**Artifact:** `examples/rbac-feature/implementation-report.md`

Repeat for each task, or let the pipeline run them in wave order. In practice, you often run `/task-implementer specs/rbac/tasks.md` to process all tasks sequentially, wave by wave.

---

## Step 7: Review

Run a comprehensive code review on the implementation.

**What you type:**
```
/review src/
```

**What the agent produces:**
A review report with findings categorized by severity (CRITICAL, HIGH, MEDIUM, LOW, INFO). Each finding includes the file, line range, description, and suggested fix. Common findings include missing error handling, security concerns, performance issues, and style violations. CRITICAL and HIGH findings block release; MEDIUM and below are advisory.

**Artifact:** `examples/rbac-feature/review-report.md`

If there are CRITICAL or HIGH findings, run `/review-fix reports/review-report.md` to auto-fix them.

---

## Step 8: Validate for Release

Run the final quality gate to verify the implementation is release-ready.

**What you type:**
```
/quality-gate impl-to-release
```

**What the agent produces:**
A release readiness verdict with scores across multiple dimensions: spec compliance (does the code match the spec), test coverage (are acceptance criteria verified), security posture (no open vulnerabilities), performance baseline (no regressions), and documentation completeness. A PASS here means the feature is ready to merge and deploy.

**Artifact:** `examples/rbac-feature/quality-gate-release.md`

---

## Multi-Agent Note

The examples above use Claude Code slash commands. If you use a different agent, invoke the same skills with natural language:

| Claude Code | Other Agents (Cursor, Windsurf, Copilot, Cline, Gemini, Aider) |
|------------|----------------------------------------------------------------|
| `/spec-gen "Add RBAC"` | "Generate a spec for RBAC" |
| `/quality-gate spec-to-plan spec.md` | "Run the spec-to-plan quality gate on spec.md" |
| `/plan-gen spec.md` | "Generate an implementation plan from spec.md" |
| `/task-gen plan.md` | "Break plan.md into implementable tasks" |
| `/review src/` | "Run a comprehensive code review on src/" |

The underlying skill logic is identical. Only the invocation syntax differs.

---

## Pipeline Shortcut

Instead of running each step manually, execute the entire flow as a pipeline:

```
/run-pipeline product-owner/feature-intake "Add RBAC"
```

This runs steps 1-3 automatically, pausing at quality gates for your approval. When the spec is approved, hand off to the architect:

```
/run-pipeline architect/design-to-plan specs/rbac/spec.md
```

Then hand off to the developer:

```
/run-pipeline developer/feature-build specs/rbac/plan.md
```

Each pipeline chains skills together with gates and dependency ordering, so you get the same result as the manual steps but with less typing and automatic failure recovery.

---

## When Things Fail

Quality gates can fail. When they do:

1. **Auto-recovery** -- The pipeline attempts automatic recovery using a paired fix skill. For example, if `spec-to-plan` fails, the pipeline runs `spec-evolve` to revise the spec and re-checks the gate.
2. **Auto-triage** -- If auto-recovery fails, `/auto-triage` analyzes the failure, classifies it, and either retries with adjusted parameters or escalates to a human.
3. **Human-in-the-loop (HITL)** -- If automated recovery cannot resolve the issue, the pipeline pauses and presents a `gate-briefing` so you can decide how to proceed.

You can also run triage manually at any time:

```
/auto-triage reports/failed-quality-gate.md
```

---

## Team Handoff

Artifacts flow between roles through a defined chain. Each pipeline produces output artifacts that become the input for the next role's pipeline.

```
Product Owner          Architect           Developer         QA              DevOps/SRE
feature-intake    -->  design-to-plan  --> feature-build --> test-strategy --> deploy-verify
  spec.md                plan.md            tasks.md         test-report.md   release-verified
  balance-sheet.md       decision-log.md    impl-report.md   regression.md
```

Each handoff is a quality gate. The spec must pass `spec-to-plan` before the architect can plan. The plan must pass `plan-to-tasks` before the developer can build. The implementation must pass `impl-to-release` before DevOps can deploy. This chain ensures that quality is verified at every stage boundary, and no role receives artifacts that have not been validated by the previous role.

The **Tech Lead** can monitor the entire chain at any time with:

```
/pipeline-orchestrator status specs/rbac/spec.md
```

And the **Scrum Master** can track progress and unblock impediments with:

```
/board-sync status
/auto-triage reports/blocked-step.md
```
