# Customization

SDLC Central is designed to be configured without forking. Gate thresholds, scoring weights, pipeline definitions, and role assignments are all editable.

## Gate Thresholds

Edit `config/gate-config.json` to change the quality requirements enforced between pipeline stages. Three built-in profiles are provided: `minimal`, `standard`, and `strict`.

Example -- raise the minimum test coverage for the standard profile:

```json
{
  "profiles": {
    "standard": {
      "thresholds": {
        "impl-to-release": {
          "min_test_coverage_percent": 80,
          "max_critical_findings": 0,
          "max_high_findings": 1
        }
      }
    }
  }
}
```

Each gate transition (`spec-to-plan`, `plan-to-tasks`, `tasks-to-impl`, `impl-to-release`) has its own threshold set. The `strict` profile adds requirements like `require_license_audit` and `require_api_contract_check` for compliance-sensitive projects.

## Feature Scoring

Edit `config/balance-sheet-config.json` to adjust how `feature-balance-sheet` weighs cost-benefit dimensions. Each dimension has a `weight` (0.0 to 1.0, summing to 1.0 within its group) and a `description`.

Example -- increase the weight of risk reduction in benefit scoring:

```json
{
  "scoring": {
    "benefit_dimensions": {
      "risk_reduction": {
        "weight": 0.20,
        "description": "Reduces technical risk, security exposure, or operational burden"
      }
    }
  }
}
```

The `thresholds` section controls go/no-go cutoff scores for both quick and deep assessments. The `portfolio_limits` section caps concurrent features and total effort.

## Creating Custom Pipelines

Add a YAML file under `pipelines/<role>/` following this schema:

```yaml
pipeline:
  name: "My Pipeline"
  description: "What this pipeline does"
  role: developer
  trigger: "When to run this pipeline"

steps:
  - id: step-one
    skill: spec-gen
    args: "$INPUT"
    description: "Generate spec from input"

  - id: step-two
    skill: plan-gen
    args: "$step-one.output"
    depends_on: [step-one]
    description: "Generate plan from spec"
    gate:
      type: quality           # quality | decision | hitl
      on_fail: hitl           # hitl | stop | auto_recover: <skill>

output:
  summary: "What was produced"
  artifacts: [spec.md, plan.md]
  next_pipeline: "developer/feature-build"
```

Key fields: `depends_on` declares execution order, `gate` adds a checkpoint (quality thresholds, decision conditions, or human-in-the-loop review), and `args` supports variable references (`$INPUT`, `$<step-id>.output`).

## Adding Skills to a Role

Edit `setup/install-role.sh` to include additional skills for a role. Find the role's skill list array and append the skill name. Then re-run the installer:

```bash
bash setup/install-role.sh developer --agent cursor
```

Also update `registry/catalog.yaml` so the role mapping stays consistent with the installer.

## Per-Project Overrides

Each agent has a project-level configuration file where you can add custom instructions that apply to all skills:

| Agent | File |
|-------|------|
| Claude Code | `CLAUDE.md` in project root |
| Cursor | `.cursor/rules/*.mdc` |
| Copilot | `.github/instructions/*.instructions.md` |
| Windsurf | `.windsurf/rules/*.md` |
| Gemini | `GEMINI.md` in project root |
| AGENTS.md | `AGENTS.md` in project root |

Add project-specific conventions (naming patterns, test frameworks, deployment targets) to these files. Skills will incorporate them automatically.

## Updating

Pull the latest version and run the update script:

```bash
git pull
bash setup/update.sh
```

The update overwrites skill prompt files with the latest versions but preserves your configuration files (`config/gate-config.json`, `config/balance-sheet-config.json`) and any custom pipelines you have added. Back up custom modifications to installed skill files before updating, as those will be replaced.
