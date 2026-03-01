# SDLC Central — Team Productivity Hub

A central repository of **50 skills** and **22 composable pipelines** covering the full software development lifecycle. Works with **any coding agent** — Claude Code, Cursor, GitHub Copilot, Windsurf, Cline, Aider, Gemini, Antigravity, or any AGENTS.md-compatible tool.

## Quickstart

```bash
# From your project directory:
bash /path/to/sdlc_central/setup/install.sh
# → Interactive: select your agent + role(s)

# Or non-interactive:
bash /path/to/sdlc_central/setup/install-role.sh developer --agent claude-code
bash /path/to/sdlc_central/setup/install-role.sh developer --agent cursor
bash /path/to/sdlc_central/setup/install-role.sh qa --agent copilot
bash /path/to/sdlc_central/setup/install-role.sh developer --agent gemini
bash /path/to/sdlc_central/setup/install-role.sh architect --agent antigravity

# Or via npm:
npx sdlc-central install --role developer --agent cursor
```

## Supported Agents

| Agent | Output Format | Skills Location |
|-------|---------------|-----------------|
| **Claude Code** | `.claude/skills/*/SKILL.md` | `/slash-commands` |
| **Cursor** | `.cursor/rules/*.mdc` | Auto-attach & agent-requested |
| **GitHub Copilot** | `.github/instructions/*.instructions.md` | Auto-attach by glob |
| **Windsurf** | `.windsurf/rules/*.md` | Always On / Model Decision |
| **Cline** | `.clinerules/*.md` | Auto or conditional |
| **Aider** | `CONVENTIONS.md` + `.sdlc/skills/` | Via `.aider.conf.yml` |
| **Gemini** | `GEMINI.md` at project root | Project-level instructions |
| **Antigravity** | `.antigravity/rules/*.md` | Rules & Workflows |
| **AGENTS.md** | `AGENTS.md` at project root | Universal fallback |

## What Gets Installed

The installer generates agent-native files from a universal skill format:

```
# Claude Code                    # Cursor                        # Copilot
my-project/.claude/               my-project/.cursor/             my-project/.github/
├── skills/spec-gen/SKILL.md      ├── rules/sdlc-spec-gen.mdc     ├── instructions/sdlc-spec-gen.instructions.md
├── pipelines/...                 ├── rules/sdlc-review.mdc       ├── copilot-instructions.md
└── config/                       └── pipelines/...               └── pipelines/...
```

## Choose Your Role

| Role | Skills | Pipelines | Best For |
|------|--------|-----------|----------|
| **Product Owner** | 12 | feature-intake, sprint-health, release-signoff | Feature evaluation, sprint tracking, release decisions |
| **Architect** | 17 | design-to-plan, system-health, migration-planning | System design, tech health, migration planning |
| **Developer** | 20 | feature-build, pr-workflow, maintenance | Building features, PR prep, codebase upkeep |
| **QA** | 10 | test-strategy, regression-suite, release-validation | Test planning, regression, release gates |
| **DevOps/SRE** | 14 | deploy-verify, incident-response, platform-health | Deployments, incidents, platform governance |
| **Tech Lead** | 50 | full-pipeline, team-health, governance | End-to-end oversight, team health, compliance |
| **Scrum Master** | 9 | sprint-tracking, retrospective-data, impediment-tracker | Sprint progress, retros, blocker resolution |
| **Designer** | 5 | spec-collaboration, design-validation | Design-spec alignment, implementation validation |

## Using Pipelines

Pipelines chain skills into automated workflows:

```bash
# Product Owner: evaluate a feature end-to-end
/run-pipeline product-owner/feature-intake 'Add SSO login'

# Developer: build from plan
/run-pipeline developer/feature-build specs/047-sso-login/plan.md

# DevOps: incident response
/run-pipeline devops-sre/incident-response 'API 500 errors since 14:30'
```

Each pipeline:
- Chains skills in the right order
- Enforces quality gates between stages
- Pauses at HITL (human-in-the-loop) checkpoints for approval
- Saves state for resume if interrupted
- Routes failures to auto-recovery or human escalation

## Using Individual Skills

All 50 skills are available in your agent's native format:

```bash
# Claude Code:  /spec-gen 'Add OAuth2 login'
# Cursor:       Ask "run the spec-gen skill for OAuth2 login"
# Copilot:      Instructions auto-attach when editing relevant files
# Aider:        Conventions loaded from CONVENTIONS.md
```

See [docs/skill-reference.md](docs/skill-reference.md) for the full list.

## Updating

```bash
# Update skills + pipelines, preserving your local config
bash /path/to/sdlc_central/setup/update.sh

# Or via npm:
npx sdlc-central update
```

The updater reads the tracking file to know which agent and roles are installed.

## Examples

The [`examples/rbac-feature/`](examples/rbac-feature/) directory contains a complete worked example — real output from each skill for a "Role-Based Authorization" feature:

| File | Produced by | What it shows |
|------|-------------|---------------|
| `spec.md` | `/spec-gen` | 6 ACs, 4 business rules, 4 edge cases |
| `plan.md` | `/plan-gen` | 5 phases, 3 architecture decisions, AC traceability |
| `tasks.md` | `/task-gen` | 12 tasks across 4 waves, dependency graph |
| `gate-spec-to-plan.md` | `/quality-gate` | PASS — all criteria green |
| `gate-spec-to-plan-fail.md` | `/quality-gate` | FAIL — shows failure routing |
| `review.md` | `/review` | 1 MEDIUM + 2 LOW findings, verdict: approve |

## Testing

```bash
# Run all integration tests
bash tests/run.sh

# Or directly with Node.js
node --test tests/*.test.js
```

Tests validate:
- **Skill manifest** — all 50 skills have valid `skill.yaml`, `prompt.md`, and `SKILL.md`
- **Pipeline schema** — all pipeline YAML files parse correctly, skill references exist, no dependency cycles
- **Gate config** — all profiles have correct types and thresholds
- **Installer consistency** — every skill and pipeline referenced by installers exists on disk
- **Adapter output** — all 9 adapters produce correct files (Windsurf: verifies 6000 char limit)

## Documentation

- [Getting Started](docs/getting-started.md) — First-time setup walkthrough
- [Core Concepts](docs/concepts.md) — Skills, pipelines, gates, HITL checkpoints
- [Role Guides](docs/guides/) — "Here's how YOU use this" per role
- [Skill Reference](docs/skill-reference.md) — All 50 skills documented
- [Pipeline Reference](docs/pipeline-reference.md) — All 22 pipelines explained
- [Customization](docs/customization.md) — Custom pipelines, config overrides
- [Step-by-Step Walkthrough](docs/walkthrough.md) — How to use this framework, start to finish (RBAC example)
- **Agent Guides:**
  - [Claude Code](docs/agents/claude-code.md) — Complete guide with all roles
  - [Cursor](docs/agents/cursor.md) — Complete guide with all roles
  - [Antigravity](docs/agents/antigravity.md) — Complete guide with all roles
  - [GitHub Copilot](docs/agents/copilot.md)
  - [Windsurf](docs/agents/windsurf.md)
  - [Cline](docs/agents/cline.md)
  - [Aider](docs/agents/aider.md)
  - [Gemini](docs/agents/gemini.md)

## Repository Structure

```
sdlc_central/
├── skills/           # 50 skill definitions (source of truth)
│   └── <skill>/
│       ├── SKILL.md      # Claude Code native format (backward compat)
│       ├── skill.yaml    # Universal metadata
│       └── prompt.md     # Agent-agnostic prompt
├── adapters/         # Per-agent output generators
│   ├── claude-code/      # → .claude/skills/*/SKILL.md
│   ├── cursor/           # → .cursor/rules/*.mdc
│   ├── copilot/          # → .github/instructions/*.instructions.md
│   ├── windsurf/         # → .windsurf/rules/*.md
│   ├── cline/            # → .clinerules/*.md
│   ├── aider/            # → CONVENTIONS.md + .sdlc/skills/
│   ├── gemini/           # → GEMINI.md
│   ├── antigravity/      # → .antigravity/rules/
│   └── agents-md/        # → AGENTS.md
├── pipelines/        # 22 pipeline YAML workflows (agent-agnostic)
├── registry/         # Skill catalog + role matrix
├── templates/        # Per-role CLAUDE.md templates
├── setup/            # Install, update, uninstall scripts
├── config/           # Default gate + scoring configs
├── docs/             # Guides, references, customization
└── package/          # npm distribution
```

## Contributing

1. Skills live in `skills/<skill-name>/` — edit `skill.yaml` (metadata) + `prompt.md` (agent-agnostic prompt)
2. Legacy `SKILL.md` is auto-generated by the Claude Code adapter — do not edit directly
3. Pipelines live in `pipelines/<role>/<name>.pipeline.yaml`
4. Update `registry/catalog.yaml` when adding/modifying skills
5. Test with `bash setup/install-role.sh <role> --agent <agent>` in a temp directory
