# Product Owner Role Guide

## Your Toolkit

**12 skills | 3 pipelines** -- Everything you need to evaluate features, track sprint health, and approve releases.

## Install

```bash
# Claude Code (default)
bash setup/install-role.sh product-owner --agent claude-code

# Cursor
bash setup/install-role.sh product-owner --agent cursor
```

## Common Workflows

### 1. Evaluate a Feature Idea

Run a quick cost-benefit filter, then generate a full spec if the idea passes.

**Claude Code:**
```
/feature-balance-sheet quick "Add RBAC for multi-tenant users"
/spec-gen "Add role-based access control"
```

**Cursor / Windsurf / Cline (natural language):**
```
Run the feature-balance-sheet skill in quick mode for "Add RBAC for multi-tenant users"
```

Or run the entire intake pipeline in one step:

```
/run-pipeline product-owner/feature-intake "Add RBAC"
```

### 2. Track Sprint Health

**Claude Code:**
```
/scope-tracker report
/board-sync status --provider jira
```

**Copilot:**
```
Use the scope-tracker instruction to generate a report of scope changes
```

### 3. Approve a Release

**Claude Code:**
```
/release-readiness-checker v2.4.0
/run-pipeline product-owner/release-signoff
```

**Gemini:**
```
Run release-readiness-checker for version v2.4.0
```

## Key Skills

| Skill | When to Use |
|-------|------------|
| `feature-balance-sheet` | Before committing to any new feature -- quick GO/NO_GO/CONDITIONAL |
| `spec-gen` | Turn an approved idea into a structured technical spec |
| `quality-gate` | Validate a spec before passing it to architecture |
| `scope-tracker` | Monitor scope creep across the sprint |
| `board-sync` | Sync artifacts to Jira, Azure Boards, Linear, or GitHub Projects |
| `release-readiness-checker` | Pre-release go/no-go gate with checklist |

## Handoff

Once you approve a spec, hand it to the **Architect** to begin the design-to-plan pipeline:

```
/run-pipeline architect/design-to-plan specs/rbac/spec.md
```

The architect receives your `spec.md` and `feature-balance-sheet.md` as inputs for planning.
