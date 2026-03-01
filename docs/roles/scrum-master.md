# Scrum Master Role Guide

## Your Toolkit

**9 skills | 3 pipelines** -- Track sprint progress, gather retrospective data, and unblock impediments.

## Install

```bash
# Claude Code (default)
bash setup/install-role.sh scrum-master --agent claude-code

# Cursor
bash setup/install-role.sh scrum-master --agent cursor
```

## Common Workflows

### 1. Daily Standup Data

Pull board status, check scope changes, and surface risks before standup.

**Claude Code:**
```
/board-sync status --provider jira
/scope-tracker report
/risk-tracker report
```

**Cursor / Windsurf (natural language):**
```
Run board-sync in status mode with Jira provider, then run scope-tracker report
```

Or run the full pipeline:

```
/run-pipeline scrum-master/sprint-tracking
```

### 2. Sprint Retrospective Prep

Gather pipeline metrics, feedback patterns, and trend data for the retro.

**Claude Code:**
```
/feedback-loop analyze
/report-trends all
/pipeline-monitor dashboard
```

**Copilot:**
```
Use the feedback-loop instruction in analyze mode to identify pipeline patterns for retro
```

### 3. Unblock Impediments

Identify failed gates and auto-triage them, or escalate blockers.

**Claude Code:**
```
/auto-triage reports/failed-gate.md
/gate-briefing --audience engineering specs/blocked-feature/spec.md
```

**Gemini:**
```
Run auto-triage on reports/failed-gate.md to attempt automated recovery
```

## Key Skills

| Skill | When to Use |
|-------|------------|
| `board-sync` | Sync artifacts with Jira, Azure Boards, Linear, or GitHub Projects |
| `scope-tracker` | Detect and report scope changes across the sprint |
| `risk-tracker` | Maintain and escalate the living risk register |
| `feedback-loop` | Analyze pipeline execution history for process improvement |
| `auto-triage` | Automated failure recovery for stalled pipeline steps |

## Handoff

When impediments require action from another role, route them with context:

- **Technical blockers** -- escalate to Architect or Developer with the `gate-briefing` output
- **Process blockers** -- escalate to Product Owner with `scope-tracker` and `risk-tracker` reports
- **Infrastructure blockers** -- escalate to DevOps/SRE with `pipeline-monitor` data
