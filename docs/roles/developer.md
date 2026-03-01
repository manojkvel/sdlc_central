# Developer Role Guide

## Your Toolkit

**20 skills | 3 pipelines** -- Build features from plans, prepare PRs with automated review, and run maintenance sweeps.

## Install

```bash
# Claude Code (default)
bash setup/install-role.sh developer --agent claude-code

# Cursor
bash setup/install-role.sh developer --agent cursor
```

## Common Workflows

### 1. Build a Feature from a Plan

Break the plan into tasks, schedule waves, implement with TDD, then verify against the spec.

**Claude Code:**
```
/task-gen specs/rbac/plan.md
/wave-scheduler specs/rbac/tasks.md
/task-implementer specs/rbac/tasks.md
```

**Cursor / Windsurf (natural language):**
```
Run task-gen on specs/rbac/plan.md to break the plan into implementable tasks
```

Or run the full pipeline:

```
/run-pipeline developer/feature-build specs/rbac/plan.md
```

### 2. Prepare a PR

**Claude Code:**
```
/review
/pr-orchestrator auto
```

**Copilot:**
```
Use the review instruction to do a comprehensive code review, then run pr-orchestrator in auto mode
```

### 3. Maintenance Sweep

**Claude Code:**
```
/dependency-update --dry-run
/tech-debt-audit src/
/security-audit
```

**Aider:**
```
Run dependency-update in dry-run mode, then run tech-debt-audit on src/
```

## Key Skills

| Skill | When to Use |
|-------|------------|
| `task-implementer` | Implement tasks with TDD and traceability to the plan |
| `review` | Comprehensive code review before opening a PR |
| `test-gen` | Generate unit, integration, or e2e tests for a module |
| `review-fix` | Auto-fix CRITICAL and HIGH findings from review |
| `spec-fix` | Close gaps between implementation and spec |
| `pr-orchestrator` | Analyze PR changes and auto-run relevant review skills |

## Handoff

After implementation, hand off to two roles:

- **QA** receives the implementation for test-strategy: `/run-pipeline qa/test-strategy specs/rbac/spec.md`
- **Tech Lead** receives the PR for governance review: `/run-pipeline tech-lead/governance`
