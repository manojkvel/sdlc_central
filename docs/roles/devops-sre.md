# DevOps/SRE Role Guide

## Your Toolkit

**14 skills | 3 pipelines** -- Verify deployments, respond to incidents, and monitor platform health.

## Install

```bash
# Claude Code (default)
bash setup/install-role.sh devops-sre --agent claude-code

# Cursor
bash setup/install-role.sh devops-sre --agent cursor
```

## Common Workflows

### 1. Verify a Deployment

Check release readiness, audit approval workflows, and monitor the pipeline.

**Claude Code:**
```
/release-readiness-checker v2.4.0
/approval-workflow-auditor full
/pipeline-monitor scan
```

**Cursor / Windsurf (natural language):**
```
Run release-readiness-checker for v2.4.0, then audit the full approval workflow
```

Or run the full pipeline:

```
/run-pipeline devops-sre/deploy-verify
```

### 2. Respond to an Incident

Detect the incident, triage it, assess rollback safety, then generate a postmortem.

**Claude Code:**
```
/incident-detector scan
/incident-triager "API latency spike on auth-service after deploy v2.4.0"
/rollback-assessor HEAD~1
```

**Copilot:**
```
Use the incident-triager instruction for "API latency spike on auth-service after deploy v2.4.0"
```

Or run the full pipeline:

```
/run-pipeline devops-sre/incident-response
```

### 3. Platform Health Check

**Claude Code:**
```
/slo-sla-tracker summary
/cross-repo-standards-enforcer full
/pipeline-monitor dashboard
```

**Cline:**
```
Run slo-sla-tracker in summary mode, then run cross-repo-standards-enforcer in full mode
```

## Key Skills

| Skill | When to Use |
|-------|------------|
| `incident-detector` | Correlate deployments with observability signals |
| `incident-triager` | Produce triage reports with root cause candidates |
| `rollback-assessor` | Evaluate whether a rollback is safe |
| `slo-sla-tracker` | Track SLOs, DORA metrics, and error budgets |
| `pipeline-monitor` | Continuous health monitoring for SDLC pipelines |

## Handoff

After incidents are resolved, hand postmortem data to the **Tech Lead** for governance and trend analysis:

```
/run-pipeline tech-lead/governance
```

Incident postmortems, SLO reports, and platform health data feed into the tech lead's governance review cycle.
