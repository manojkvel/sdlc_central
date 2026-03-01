# Spec: SDLC Central Operational Layer — Shared State, Notifications, Metrics, Pre-Flight, Emergency Bypass, CI/CD Hooks

> **Status:** DRAFT
> **Author:** AI-generated, pending review
> **Created:** 2026-03-01
> **Last updated:** 2026-03-01 (rev 2 — resolved open questions)
> **Spec ID:** 001

---

## 1. Problem Statement

SDLC Central has a strong skill and pipeline engine but lacks the operational infrastructure needed for real teams. Today, pipelines run in isolation — one agent, one person, one machine. When a pipeline pauses at a human-in-the-loop gate, nobody is notified. When two developers run pipelines on overlapping code, there is no collision detection. When a P1 incident fires at 3 AM, the pipeline cannot be bypassed. There are no execution metrics, no pre-flight validation, and no integration with CI/CD systems.

These gaps mean the framework works for solo developers but breaks down for teams of 3+ people using it across roles, and it fails entirely for hybrid human-plus-AI-agent workflows where coordination is critical.

This spec defines six capabilities that close these gaps and make SDLC Central production-ready for real teams.

## 2. Goals

- **G-1:** Enable any role on any agent to resume a pipeline started by a different role on a different agent, with full context preserved.
- **G-2:** Automatically notify the right person (via MS Teams) when a pipeline needs human action, with one-click approve/reject.
- **G-3:** Record every pipeline execution so teams can measure cycle time, gate failure rates, and bottleneck steps.
- **G-4:** Validate all required tools, integrations, and permissions before a pipeline starts — not mid-run.
- **G-5:** Allow emergency bypass of pipeline gates during incidents, with mandatory post-incident documentation.
- **G-6:** Emit structured events at pipeline transitions so external CI/CD systems can react to SDLC Central activity.

## 3. Non-Goals

- **NG-1:** Building a custom dashboard UI. The metrics log should be consumable by existing tools (Grafana, Excel, or the report-trends skill) — not a bespoke web app.
- **NG-2:** Replacing CI/CD. The CI/CD hooks emit events; they do not replace GitHub Actions, Azure Pipelines, or Jenkins.
- **NG-3:** Enforcing authentication or RBAC. Role-based access remains advisory. Adding auth is a separate concern and out of scope.
- **NG-4:** Supporting notification channels other than MS Teams (v1). Slack, email, and PagerDuty are future considerations.
- **NG-5:** Real-time multi-agent collaboration. Agents still work sequentially within a pipeline; they do not co-edit simultaneously.

## 4. User Stories

### 4.1 Primary Flow — Cross-Role Pipeline Handoff

> As a **Developer**, I want to resume a pipeline that an **Architect** started on a different machine, so that our feature-build pipeline continues without re-running completed steps.

**Preconditions:**
- Architect has completed `design-to-plan` pipeline (steps 1-4 done, output artifacts exist).
- Pipeline state is committed to git in the shared `.sdlc/` directory.
- Developer has pulled latest from the repository.

**Steps:**
1. Developer runs `/run-pipeline developer/feature-build --resume`
2. Pipeline runner reads `.sdlc/pipeline-state/feature-build-001.json`
3. Runner identifies first non-completed step (step 1: `break-tasks`)
4. Runner resolves `$INPUT` from the state file's `input` field
5. Pipeline executes from that step forward

**Postconditions:**
- State file is updated after each step with new status, output paths, and timestamps.
- State file is agent-agnostic (no `.claude/` or `.cursor/` path references — all paths relative to project root).

### 4.2 Primary Flow — MS Teams HITL Notification

> As a **Product Owner**, I want to receive a Teams notification when a pipeline needs my approval, so that I don't need to keep checking the terminal.

**Preconditions:**
- Teams webhook URL is configured in `.sdlc/config/notifications.json`.
- Pipeline is running and reaches a `hitl` gate.

**Steps:**
1. Pipeline runner reaches a step with `gate.type: hitl`
2. Runner reads notification config
3. Runner sends a POST to the configured Power Automate Workflow URL with an adaptive card payload
4. Adaptive card displays: pipeline name, step description, artifacts produced, and Approve/Reject buttons
5. PO clicks Approve in Teams
6. Power Automate writes an approval file to a shared location (or the PO runs `/run-pipeline --resume --approve`)
7. Pipeline continues

**Postconditions:**
- Notification is posted to the correct Teams channel.
- Approval decision is recorded in the pipeline state file with timestamp and approver.

### 4.3 Alternative Flow — Teams Notification with Reject

> As a **Product Owner**, I click Reject in the Teams adaptive card.

**Steps:**
1. Power Automate writes a rejection marker
2. On next `--resume`, pipeline runner reads the rejection
3. Pipeline status is set to `rejected` with the PO's reason
4. Pipeline halts, state is preserved for potential re-run after changes

### 4.4 Primary Flow — Pre-Flight Check

> As a **DevOps/SRE**, I want the pipeline to check that kubectl is available and my cluster is reachable before the incident-response pipeline starts, so I don't fail at step 3 of 3.

**Steps:**
1. SRE runs `/run-pipeline devops-sre/incident-response 'API 500 errors'`
2. Before step 1, runner executes pre-flight checks defined in pipeline YAML
3. Checks pass (kubectl available, git clean, required skills installed)
4. Pipeline proceeds

### 4.5 Error Flow — Pre-Flight Failure

**Steps:**
1. Pre-flight check fails: `kubectl` not found
2. Runner displays: "Pre-flight failed: kubectl is required but not found. Install it and retry."
3. Pipeline does not start. No state file is created.

### 4.6 Primary Flow — Emergency Bypass

> As a **DevOps/SRE** at 3 AM during a P1, I want to skip pipeline gates and go straight to rollback, with the system recording that I bypassed the process.

**Steps:**
1. SRE runs `/run-pipeline devops-sre/incident-response --emergency`
2. Runner logs a warning: "EMERGENCY MODE: All gates bypassed. Post-incident documentation required."
3. All steps execute without gate evaluation
4. On completion, runner automatically queues `/incident-postmortem-synthesizer` as a mandatory follow-up
5. State file records `"mode": "emergency"` and `"bypass_reason": "P1 incident"`

**Postconditions:**
- All gates are skipped but the skip is recorded.
- A postmortem task is created that cannot be dismissed without generating output.

### 4.7 Primary Flow — CI/CD Event Emission

> As a **Tech Lead**, I want GitHub Actions to trigger automatically when a spec is approved, so our CI pipeline runs validation without manual intervention.

**Steps:**
1. Pipeline completes the `validate-spec` step with a `pass` gate result
2. Runner writes a structured event to `.sdlc/events/pipeline-events.jsonl`
3. A GitHub Actions workflow watches for changes to this file
4. On push, the GHA workflow reads the latest event and triggers the appropriate job

**Postconditions:**
- Event file contains: pipeline name, step ID, gate result, timestamp, artifacts.
- External CI/CD can parse the event and make decisions.

## 5. Acceptance Criteria

- [ ] **AC-1:** Given a pipeline started by Claude Code on machine A, when a Cursor user runs `--resume` on machine B (after git pull), then the pipeline continues from the first non-completed step with all context preserved.
- [ ] **AC-2:** Given a `hitl` gate is reached and a Teams webhook is configured, when the pipeline runner executes, then an adaptive card is posted to the configured Teams channel within 5 seconds.
- [ ] **AC-3:** Given a Teams adaptive card with Approve/Reject, when the user clicks Approve, then the pipeline state file is updated with `"gate_result": "hitl_approved"` and the approver's identity.
- [ ] **AC-4:** Given a pipeline has completed 10 runs, when a user runs `/report-trends pipeline-metrics`, then the skill can read `.sdlc/metrics/pipeline-executions.jsonl` and report average duration per step, gate failure rate, and most common failure reasons.
- [ ] **AC-5:** Given a pipeline YAML with `preflight` checks defined, when a required tool is missing, then the pipeline refuses to start and displays a clear error listing all failed checks.
- [ ] **AC-6:** Given an `--emergency` flag, when the pipeline runs, then all gates are bypassed, the state file records `"mode": "emergency"`, and the runner queues a mandatory postmortem follow-up.
- [ ] **AC-7:** Given a pipeline step completes, when the CI/CD hooks feature is enabled, then a JSONL event is appended to `.sdlc/events/pipeline-events.jsonl` with pipeline, step, result, and timestamp fields.
- [ ] **AC-8:** Given a pipeline state file exists in `.sdlc/pipeline-state/`, when any supported agent reads it, then the file contains no agent-specific paths (no `.claude/`, `.cursor/`, `.github/` references — all paths are project-root-relative).
- [ ] **AC-9:** Given an `--emergency` pipeline run has completed, when the user tries to close the postmortem follow-up without generating output, then the system refuses and displays: "Emergency bypass requires postmortem documentation."
- [ ] **AC-10:** Given notification config is missing or the Teams webhook URL is invalid, when a `hitl` gate fires, then the pipeline still pauses (does not crash) and displays a warning: "Notification failed — manual approval required via --resume --approve."

## 6. Business Rules

| Rule ID | Rule | Example |
|---------|------|---------|
| BR-1 | Pipeline state files must be agent-agnostic. All paths are relative to the project root, never to an agent-specific directory. | `"output": "specs/001-dark-mode/plan.md"` not `"output": ".claude/specs/..."` |
| BR-2 | Emergency bypass requires a reason string. The flag alone is not sufficient; the user must provide `--emergency "P1: API outage"`. | `/run-pipeline ... --emergency "P1: API 500 cascade"` |
| BR-3 | Metrics are append-only. The execution log is never overwritten or truncated. | New runs append to `pipeline-executions.jsonl` |
| BR-4 | Pre-flight checks are non-blocking by default but can be set to `required: true` per check. | A check for `kubectl` can be `required: true` (blocks) or `required: false` (warns) |
| BR-5 | Notification failures are non-fatal. The pipeline pauses at the gate regardless of whether the notification was delivered. | If the Teams webhook is unreachable, the gate still fires — it just doesn't notify. |
| BR-6 | CI/CD events are opt-in. The feature is disabled unless `cicd_hooks: true` is set in `.sdlc/config/pipeline-config.json`. | Teams that don't use CI/CD integration are not affected. |
| BR-7 | One active pipeline per spec ID. If pipeline state for `feature-build-001` is `in_progress`, a second `feature-build-001` run is rejected with: "Pipeline already in progress. Use --resume or --force." | Prevents conflicting parallel runs on the same feature. |

## 7. Data Requirements

**Inputs:**
- Pipeline YAML definitions (existing, no change)
- Skill definitions (existing, no change)
- New: `.sdlc/config/notifications.json` — Teams webhook URL, channel mappings per role
- New: `.sdlc/config/pipeline-config.json` — global pipeline settings (cicd_hooks, metrics, emergency policy)

**Outputs:**
- New: `.sdlc/pipeline-state/<pipeline>-<spec-id>.json` — agent-agnostic state (replaces current `.claude/pipelines/pipeline-state-*.json`)
- New: `.sdlc/metrics/pipeline-executions.jsonl` — append-only execution log
- New: `.sdlc/events/pipeline-events.jsonl` — structured CI/CD events
- New: `pipeline-progress.md` (existing concept, moved to `.sdlc/pipeline-state/`)

**Stored state:**
- Pipeline state files are persisted in git (committed by the user or CI).
- Metrics and events are persisted in git (append-only, one line per event).
- Notification config is persisted in git (committed once during setup).

**Relationships:**
- Pipeline state references skill outputs by project-root-relative paths.
- Metrics reference pipeline names and step IDs from pipeline YAML definitions.
- Events reference the same identifiers, consumable by external CI/CD.

## 8. Constraints

### Security Constraints
- Teams webhook URLs must not be committed to public repositories. The `notifications.json` file should be in `.gitignore` for public repos, or encrypted via `git-crypt` / environment variables for private repos.
- Emergency bypass must record the operator's identity (from git config `user.name` or environment variable).
- CI/CD events must not contain secrets, credentials, or full file contents — only metadata.

### Performance Constraints
- Notification delivery must complete within 5 seconds or time out gracefully (non-blocking).
- Pre-flight checks must complete within 10 seconds total (all checks combined).
- Metrics file append must be atomic (write to temp file, then rename) to prevent corruption from concurrent writes.

### Compatibility Constraints
- Pipeline state schema must be forward-compatible: unknown fields are preserved, not stripped.
- All new files use the `.sdlc/` directory (never agent-specific directories).
- MS Teams integration uses Power Automate Workflows (not deprecated Office 365 Connectors which were retired December 2025).
- Minimum bash version: 4.0 (for associative arrays in pre-flight checks).

### Compliance Constraints
- Emergency bypass creates an audit trail that cannot be deleted without git history rewriting.
- All HITL approvals record: who approved, when, and the gate description.

## 9. Edge Cases & Boundary Conditions

| # | Scenario | Expected Behavior |
|---|----------|-------------------|
| 1 | Pipeline state file exists but is corrupt (invalid JSON) | Runner displays error: "State file corrupt. Use `--force` to restart or manually fix the JSON." Pipeline does not start. |
| 2 | Two users run `--resume` on the same pipeline simultaneously | First write wins (file lock). Second user gets: "Pipeline state locked by another process. Retry in a moment." |
| 3 | Teams webhook returns HTTP 429 (rate limited) | Retry once after 2 seconds. If still 429, log warning and continue (non-blocking). |
| 4 | Emergency bypass on a pipeline with no postmortem skill installed | Runner warns: "incident-postmortem-synthesizer not installed. Postmortem must be created manually." Records the bypass anyway. |
| 5 | Metrics JSONL file exceeds 10 MB | Runner rotates: renames current file to `pipeline-executions-<date>.jsonl` and starts a new file. |
| 6 | Pre-flight check requires a tool that exists but returns non-zero (e.g., `kubectl` present but cluster unreachable) | Distinguish between "tool missing" and "tool failed." Display both. Only `required: true` checks block. |
| 7 | Pipeline YAML has no `preflight` section | Pre-flight phase is skipped entirely. No error. |
| 8 | CI/CD events file is deleted by user | Runner recreates it on next event. No crash. |
| 9 | User runs `--emergency` on a non-incident pipeline (e.g., feature-intake) | Allowed but logged with warning: "Emergency mode used on non-incident pipeline. This will be flagged in metrics." |
| 10 | Notification config specifies a per-role channel but the current step's role has no mapping | Fall back to the `default` channel. If no default, skip notification with warning. |

## 10. Dependencies

**Depends on:**
- Existing pipeline runner engine (PIPELINE-RUNNER.md) — this spec extends it, does not replace it.
- Existing gate-config.json — emergency bypass interacts with gate profiles.
- Existing pipeline YAML schema — extended with `preflight` section.
- MS Teams Power Automate Workflows — for notification delivery.
- Git — for state persistence and event distribution.

**Depended on by:**
- report-trends skill — will consume metrics JSONL for trend analysis.
- feedback-loop skill — will consume execution history for pattern detection.
- Any external CI/CD system (GitHub Actions, Azure Pipelines, Jenkins) — consumes events JSONL.

**External dependencies:**
- MS Teams Power Automate Workflow endpoint (user-provisioned, per-team).
- No new external services required beyond MS Teams and the team's existing git hosting.

## 11. Open Questions

| # | Question | Impact | Owner | Resolution |
|---|----------|--------|-------|------------|
| 1 | Should the Teams approval flow be fully async (via file-based markers) or require the user to run `--resume --approve` manually? | Determines complexity of the Power Automate workflow. Fully async needs a webhook endpoint. | Tech Lead | **Resolved:** V1 uses `--resume --approve` (manual). The Teams notification is informational only — it tells the user to go approve, but does not accept approval clicks directly. This avoids needing a webhook endpoint. V2 may add async approval via Power Automate response actions. |
| 2 | Should metrics include token/cost estimates per step? | Valuable for budgeting but requires per-agent token tracking which doesn't exist today. | Product Owner | **Resolved:** V1 records step duration only (seconds). Token cost estimation deferred to V2. The JSONL schema reserves an optional `tokens` field for forward compatibility. |
| 3 | Should pipeline state files be auto-committed to git, or is that the user's responsibility? | Auto-commit risks noisy git history. Manual commit risks stale state on other machines. | Architect | **Resolved:** Pipeline runner auto-stages state files (`git add .sdlc/pipeline-state/`) after each step but does NOT auto-commit. The user (or CI) commits when ready. The runner prints a reminder: "State updated. Commit and push to share with your team." |
| 4 | Should pre-flight checks be defined in the pipeline YAML or in a separate preflight.yaml? | In-pipeline is simpler. Separate file allows shared pre-flight definitions across pipelines. | Architect | **Resolved:** V1 defines pre-flight checks inline in the pipeline YAML (under a `preflight:` key). This keeps each pipeline self-contained. If reuse patterns emerge across pipelines, V2 may extract shared check definitions into `.sdlc/config/preflight-checks.yaml` with `$ref` references. |
| 5 | What is the maximum number of concurrent pipelines per project? | Affects file locking strategy and state directory structure. | Tech Lead | **Resolved:** Default limit is 5 concurrent pipelines, configurable via `pipeline-config.json` field `concurrency.max_concurrent_pipelines`. File locking uses atomic rename (write to `.lock` temp file, rename on success). |

## 12. Out of Scope for V1 (Future Considerations)

- Slack, email, and PagerDuty notification channels (v2).
- Real-time collaborative editing between multiple agents on the same pipeline step.
- A web-based dashboard for pipeline visualization (use report-trends + existing tools instead).
- Token cost estimation and budget enforcement.
- Automatic git commit of state files (user commits manually in v1).
- Pipeline templates (parameterized pipelines that generate YAML from inputs).
- Cross-repository pipeline orchestration (running pipelines across multiple repos).

---

## Appendix A: New File Schemas

### A.1 Agent-Agnostic Pipeline State — `.sdlc/pipeline-state/<pipeline>-<spec-id>.json`

```json
{
  "schema_version": "2.0.0",
  "pipeline": "developer/feature-build",
  "spec_id": "001",
  "input": "specs/001-dark-mode/plan.md",
  "started_at": "2026-03-01T10:00:00Z",
  "updated_at": "2026-03-01T11:30:00Z",
  "started_by": { "role": "developer", "agent": "claude-code", "user": "alice" },
  "gate_profile": "standard",
  "mode": "normal",
  "status": "in_progress",
  "total_steps": 5,
  "completed_steps": 3,
  "steps": {
    "break-tasks": {
      "status": "completed",
      "skill": "task-gen",
      "started_at": "2026-03-01T10:00:00Z",
      "completed_at": "2026-03-01T10:05:00Z",
      "output": "specs/001-dark-mode/tasks.md",
      "executed_by": { "agent": "claude-code", "user": "alice" }
    },
    "verify-spec": {
      "status": "pending_approval",
      "skill": "spec-review",
      "gate_type": "hitl",
      "gate_description": "Review spec compliance before proceeding",
      "notification_sent": true,
      "notification_channel": "dev-approvals",
      "awaiting_role": "architect"
    }
  }
}
```

### A.2 Notification Config — `.sdlc/config/notifications.json`

```json
{
  "provider": "ms-teams",
  "power_automate_workflow_url": "https://prod-XX.westus.logic.azure.com:443/workflows/...",
  "channel_mappings": {
    "product-owner": "po-approvals",
    "architect": "arch-reviews",
    "developer": "dev-approvals",
    "devops-sre": "ops-alerts",
    "default": "sdlc-notifications"
  },
  "mention_mappings": {
    "product-owner": "po-team@company.com",
    "architect": "arch-team@company.com"
  },
  "timeout_seconds": 5
}
```

### A.3 Metrics Log — `.sdlc/metrics/pipeline-executions.jsonl`

```jsonl
{"ts":"2026-03-01T10:05:00Z","pipeline":"developer/feature-build","spec_id":"001","step":"break-tasks","skill":"task-gen","status":"completed","duration_s":300,"gate_result":null,"agent":"claude-code","user":"alice"}
{"ts":"2026-03-01T10:15:00Z","pipeline":"developer/feature-build","spec_id":"001","step":"schedule","skill":"wave-scheduler","status":"completed","duration_s":120,"gate_result":null,"agent":"claude-code","user":"alice"}
{"ts":"2026-03-01T11:30:00Z","pipeline":"developer/feature-build","spec_id":"001","step":"verify-spec","skill":"spec-review","status":"gate_failed","duration_s":180,"gate_result":"fail","gate_type":"quality","agent":"cursor","user":"bob"}
```

### A.4 CI/CD Event Log — `.sdlc/events/pipeline-events.jsonl`

```jsonl
{"ts":"2026-03-01T10:05:00Z","event":"step_completed","pipeline":"developer/feature-build","step":"break-tasks","result":"completed","artifacts":["specs/001/tasks.md"]}
{"ts":"2026-03-01T11:30:00Z","event":"gate_failed","pipeline":"developer/feature-build","step":"verify-spec","gate_type":"quality","reason":"test_coverage_below_threshold"}
{"ts":"2026-03-01T12:00:00Z","event":"pipeline_completed","pipeline":"developer/feature-build","status":"completed","total_duration_s":7200}
```

### A.5 Pipeline YAML Extension — `preflight` Section

```yaml
pipeline:
  name: "Incident Response"
  role: devops-sre
  trigger: "When an incident is detected"

preflight:
  - check: tool_available
    tool: kubectl
    required: true
  - check: tool_available
    tool: jq
    required: true
  - check: git_clean
    required: false
    message: "Working directory has uncommitted changes"
  - check: skill_installed
    skill: incident-detector
    required: true
  - check: config_exists
    path: .sdlc/config/notifications.json
    required: false
    message: "Notification config missing — HITL gates will require manual --resume"

steps:
  - id: detect
    skill: incident-detector
    # ... (existing schema, unchanged)
```

### A.6 Pipeline Config — `.sdlc/config/pipeline-config.json`

```json
{
  "schema_version": "1.0.0",
  "metrics": {
    "enabled": true,
    "max_file_size_mb": 10,
    "rotation": true
  },
  "cicd_hooks": {
    "enabled": false,
    "event_file": ".sdlc/events/pipeline-events.jsonl"
  },
  "concurrency": {
    "max_concurrent_pipelines": 5,
    "lock_timeout_seconds": 30
  },
  "emergency": {
    "allowed_pipelines": ["devops-sre/incident-response", "devops-sre/deploy-verify"],
    "require_reason": true,
    "require_postmortem": true,
    "postmortem_skill": "incident-postmortem-synthesizer"
  },
  "notifications": {
    "enabled": true,
    "config_path": ".sdlc/config/notifications.json"
  }
}
```

---

> **Next step:** When this spec is APPROVED, run `/plan-gen specs/001-operational-layer/spec.md` to generate an implementation plan.
