# Pipelines

Pipelines are composable YAML workflows that chain skills into role-specific sequences. Instead of learning and invoking individual skills, run a single pipeline command that handles the entire workflow.

## How Pipelines Work

1. **You invoke**: `/run-pipeline <role>/<pipeline-name> [args]`
2. **The Pipeline Runner** reads the YAML definition
3. **Steps execute** in dependency order, passing outputs between skills
4. **Quality gates** enforce standards between steps
5. **HITL checkpoints** pause for human approval at decision points
6. **State persists** so interrupted pipelines can resume

## Pipeline YAML Format

```yaml
pipeline:
  name: "Pipeline Name"
  description: "What this pipeline does"
  role: role-name
  trigger: "When to use this pipeline"

steps:
  - id: step-name
    skill: skill-name          # Which skill to invoke
    args: "$INPUT"             # Arguments ($INPUT = user input, $step-id.output = step output)
    description: "What this step does"
    depends_on: [other-step]   # Steps that must complete first
    gate:                      # Optional quality/decision gate
      type: decision|quality|hitl
      pass_condition: "expression"
      on_fail: stop|hitl|{auto_recover: skill, fallback: hitl}

output:
  summary: "What was produced"
  artifacts: [file1.md, file2.md]
  next_pipeline: "role/next-pipeline"  # Suggested next step
```

## Available Pipelines

### Product Owner (3)
| Pipeline | Command | Purpose |
|----------|---------|---------|
| feature-intake | `/run-pipeline product-owner/feature-intake '<idea>'` | Evaluate and spec a feature |
| sprint-health | `/run-pipeline product-owner/sprint-health` | Sprint dashboard |
| release-signoff | `/run-pipeline product-owner/release-signoff vX.Y.Z` | Release go/no-go |

### Architect (3)
| Pipeline | Command | Purpose |
|----------|---------|---------|
| design-to-plan | `/run-pipeline architect/design-to-plan specs/NNN/spec.md` | Spec to plan |
| system-health | `/run-pipeline architect/system-health` | Architecture health |
| migration-planning | `/run-pipeline architect/migration-planning '<migration>'` | Plan a migration |

### Developer (3)
| Pipeline | Command | Purpose |
|----------|---------|---------|
| feature-build | `/run-pipeline developer/feature-build specs/NNN/plan.md` | Build from plan |
| pr-workflow | `/run-pipeline developer/pr-workflow` | PR preparation |
| maintenance | `/run-pipeline developer/maintenance` | Codebase upkeep |

### QA (3)
| Pipeline | Command | Purpose |
|----------|---------|---------|
| test-strategy | `/run-pipeline qa/test-strategy specs/NNN/spec.md` | Test from spec |
| regression-suite | `/run-pipeline qa/regression-suite` | Regression + perf |
| release-validation | `/run-pipeline qa/release-validation vX.Y.Z` | Pre-release gate |

### DevOps/SRE (3)
| Pipeline | Command | Purpose |
|----------|---------|---------|
| deploy-verify | `/run-pipeline devops-sre/deploy-verify vX.Y.Z` | Post-deploy check |
| incident-response | `/run-pipeline devops-sre/incident-response '<description>'` | Incident workflow |
| platform-health | `/run-pipeline devops-sre/platform-health` | Platform governance |

### Tech Lead (3)
| Pipeline | Command | Purpose |
|----------|---------|---------|
| full-pipeline | `/run-pipeline tech-lead/full-pipeline '<feature>'` | End-to-end delivery |
| team-health | `/run-pipeline tech-lead/team-health` | Team + process health |
| governance | `/run-pipeline tech-lead/governance` | Compliance audit |

### Scrum Master (3)
| Pipeline | Command | Purpose |
|----------|---------|---------|
| sprint-tracking | `/run-pipeline scrum-master/sprint-tracking` | Sprint progress |
| retrospective-data | `/run-pipeline scrum-master/retrospective-data` | Retro data |
| impediment-tracker | `/run-pipeline scrum-master/impediment-tracker` | Resolve blockers |

### Designer (2)
| Pipeline | Command | Purpose |
|----------|---------|---------|
| spec-collaboration | `/run-pipeline designer/spec-collaboration '<design>'` | Design-spec alignment |
| design-validation | `/run-pipeline designer/design-validation` | Validate design impl |

## Creating Custom Pipelines

Add a new `.pipeline.yaml` file to `.claude/pipelines/<role>/` and it will be available via `/run-pipeline`. See [docs/customization.md](../docs/customization.md) for details.

## Resuming Pipelines

If a pipeline is interrupted (context limit, crash, user closes terminal):
```
/run-pipeline --resume <role>/<pipeline-name>
```
The Pipeline Runner reads `pipeline-state.json` and continues from the last completed step.
