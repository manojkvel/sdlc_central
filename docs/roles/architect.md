# Architect Role Guide

## Your Toolkit

**17 skills | 3 pipelines** -- Turn approved specs into implementation plans, audit system health, and plan migrations.

## Install

```bash
# Claude Code (default)
bash setup/install-role.sh architect --agent claude-code

# Windsurf
bash setup/install-role.sh architect --agent windsurf
```

## Common Workflows

### 1. Turn a Spec into a Plan

Review architecture patterns, generate the plan, then capture decisions.

**Claude Code:**
```
/design-review specs/rbac/spec.md
/plan-gen specs/rbac/spec.md
/decision-log capture specs/rbac/plan.md
```

**Cursor / Windsurf (natural language):**
```
Run the design-review skill on specs/rbac/spec.md, then generate a plan from the spec
```

Or run the full pipeline:

```
/run-pipeline architect/design-to-plan specs/rbac/spec.md
```

### 2. Audit System Health

**Claude Code:**
```
/tech-debt-audit full
/api-contract-analyzer full
```

**Cline:**
```
Run tech-debt-audit in full mode on the entire codebase
```

### 3. Plan a Migration

**Claude Code:**
```
/reverse-engineer src/legacy-auth/
/migration-tracker init auth-v2-migration
/run-pipeline architect/migration-planning
```

**Copilot:**
```
Use the reverse-engineer instruction on src/legacy-auth/ to document the current architecture
```

## Key Skills

| Skill | When to Use |
|-------|------------|
| `plan-gen` | Generate an implementation plan from an approved spec |
| `design-review` | Review architecture and design patterns before planning |
| `tech-debt-audit` | Assess codebase health and prioritize debt reduction |
| `api-contract-analyzer` | Detect breaking API changes between branches |
| `decision-log` | Capture architectural decisions alongside plans |
| `reverse-engineer` | Document an unfamiliar or legacy codebase |

## Handoff

Once the plan passes the `plan-to-tasks` quality gate, hand it to the **Developer** to begin the feature-build pipeline:

```
/run-pipeline developer/feature-build specs/rbac/plan.md
```

The developer receives your `plan.md` and `decision-log.md` as inputs for task breakdown and implementation.
