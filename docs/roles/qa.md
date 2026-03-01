# QA Role Guide

## Your Toolkit

**10 skills | 3 pipelines** -- Build test strategies, run regression checks, and validate releases.

## Install

```bash
# Claude Code (default)
bash setup/install-role.sh qa --agent claude-code

# Copilot
bash setup/install-role.sh qa --agent copilot
```

## Common Workflows

### 1. Build a Test Strategy

Review the spec for testability, generate tests, and check for regressions.

**Claude Code:**
```
/spec-review specs/rbac/spec.md
/test-gen src/auth/
/regression-check
```

**Copilot:**
```
Use the spec-review instruction on specs/rbac/spec.md to validate testability and completeness
```

Or run the full pipeline:

```
/run-pipeline qa/test-strategy specs/rbac/spec.md
```

### 2. Run Regression Checks

**Claude Code:**
```
/regression-check
/perf-review src/auth/
```

**Cursor / Windsurf (natural language):**
```
Run regression-check to predict what might break from recent changes
```

### 3. Validate for Release

**Claude Code:**
```
/release-readiness-checker v2.4.0
/quality-gate impl-to-release
/security-audit
```

**Gemini:**
```
Run release-readiness-checker for v2.4.0 and then run the impl-to-release quality gate
```

## Key Skills

| Skill | When to Use |
|-------|------------|
| `test-gen` | Generate comprehensive tests from spec acceptance criteria |
| `regression-check` | Predict what existing functionality might break |
| `perf-review` | Review code for performance issues and bottlenecks |
| `spec-review` | Validate that implementation matches the spec |
| `security-audit` | Scan for security vulnerabilities before release |

## Handoff

Once tests pass and release validation is complete, hand off to **DevOps/SRE** to begin the deploy-verify pipeline:

```
/run-pipeline devops-sre/deploy-verify
```

DevOps receives your test reports, regression analysis, and release-readiness assessment as deployment prerequisites.
