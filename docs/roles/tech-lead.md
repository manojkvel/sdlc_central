# Tech Lead Role Guide

## Your Toolkit

**All 50 skills | 3 pipelines** -- Orchestrate the full feature lifecycle, assess team health, and enforce governance.

## Install

```bash
# Claude Code (default) -- installs all 50 skills
bash setup/install-all.sh --agent claude-code

# Windsurf
bash setup/install-all.sh --agent windsurf
```

## Common Workflows

### 1. Run Full Feature Lifecycle

Orchestrate the entire pipeline from spec through release in one command.

**Claude Code:**
```
/pipeline-orchestrator run --gates standard specs/rbac/spec.md
```

**Cursor / Windsurf (natural language):**
```
Run the pipeline-orchestrator skill with standard gates on specs/rbac/spec.md
```

Or use the named pipeline:

```
/run-pipeline tech-lead/full-pipeline specs/rbac/spec.md
```

### 2. Assess Team Health

**Claude Code:**
```
/code-ownership-mapper risks
/report-trends dashboard
/feedback-loop analyze
```

**Copilot:**
```
Use the code-ownership-mapper instruction in risks mode to identify knowledge silos and bus factor
```

### 3. Governance Review

**Claude Code:**
```
/quality-gate impl-to-release
/tech-debt-audit full
/license-compliance-audit full
/skill-gap-analyzer full
```

**Gemini:**
```
Run quality-gate for impl-to-release, then run tech-debt-audit in full mode
```

## Key Skills (Day-to-Day Focus)

| Skill | When to Use |
|-------|------------|
| `pipeline-orchestrator` | End-to-end SDLC automation across all stages |
| `quality-gate` | Enforce stage gates between pipeline phases |
| `code-ownership-mapper` | Identify knowledge silos and bus factor risks |
| `tech-debt-audit` | Codebase health check and debt prioritization |
| `feedback-loop` | Analyze pipeline history to improve process |

## Delegation

The tech lead has access to every skill but delegates execution by role:

| Stage | Delegate To | Pipeline |
|-------|------------|----------|
| Feature evaluation | Product Owner | `feature-intake` |
| Architecture and planning | Architect | `design-to-plan` |
| Implementation | Developer | `feature-build`, `pr-workflow` |
| Testing and validation | QA | `test-strategy`, `release-validation` |
| Deployment and monitoring | DevOps/SRE | `deploy-verify`, `incident-response` |
| Sprint process | Scrum Master | `sprint-tracking` |
| Design and UX | Designer | `spec-collaboration` |
