# Getting Started with SDLC Central

## What Is SDLC Central?

SDLC Central is a repository of 50 AI-agent skills and 22 composable pipelines that bring structured software development practices to your AI coding assistant. Skills cover the full lifecycle -- specification, planning, implementation, review, testing, deployment, and governance. The core is agent-agnostic: a universal format is adapted at install time for whichever AI coding agent you use.

## Prerequisites

- **Git** (any recent version)
- **One supported AI coding agent** installed and configured in your project

### Supported Agents

| Agent | Flag Value | Install Location |
|-------|-----------|-----------------|
| Claude Code | `claude-code` (default) | `.claude/skills/` |
| Cursor | `cursor` | `.cursor/rules/` |
| Copilot | `copilot` | `.github/instructions/` |
| Windsurf | `windsurf` | `.windsurf/rules/` |
| Cline | `cline` | `.cline/rules/` |
| Aider | `aider` | `.aider/conventions/` |
| Gemini | `gemini` | `GEMINI.md` sections |
| Antigravity | `antigravity` | `.antigravity/skills/` |
| AGENTS.md | `agents-md` | `AGENTS.md` sections |

## Installation

Clone the repository, then choose one of three install modes. Always pass `--agent <agent>` to target your agent (defaults to `claude-code` if omitted).

### Option 1: Interactive Installer

```bash
bash setup/install.sh
# Prompts you to select an agent and a role
```

### Option 2: Install by Role

```bash
bash setup/install-role.sh developer --agent cursor
bash setup/install-role.sh qa --agent copilot
bash setup/install-role.sh architect --agent gemini
```

### Option 3: Install All 50 Skills

```bash
bash setup/install-all.sh --agent claude-code
bash setup/install-all.sh --agent windsurf
```

## Verify Your Installation

After installing, confirm the skill files were written to the correct location for your agent:

| Agent | Check |
|-------|-------|
| Claude Code | `ls .claude/skills/` -- one `.md` file per skill |
| Cursor | `ls .cursor/rules/` -- one `.mdc` file per skill |
| Copilot | `ls .github/instructions/` -- one `.instructions.md` file per skill |
| Windsurf | `ls .windsurf/rules/` -- one `.md` file per skill |
| Gemini | Search `GEMINI.md` for skill headings |

## Try a Skill

The same skill works across all agents. Here is `spec-gen` invoked in four different agents:

**Claude Code:**
```
/spec-gen 'Add user authentication with OAuth2'
```

**Cursor / Windsurf / Cline:**
```
Run the spec-gen skill on 'Add user authentication with OAuth2'
```

**Copilot:**
```
Use the spec-gen instruction to generate a spec for 'Add user authentication with OAuth2'
```

**Gemini:**
```
Run spec-gen for 'Add user authentication with OAuth2'
```

## Try a Pipeline

Pipelines chain skills together with quality gates. Run one with the `run-pipeline` command (Claude Code) or by describing the pipeline to your agent:

```
/run-pipeline developer/feature-build specs/auth/plan.md
```

The pipeline will execute task-gen, wave-scheduler, task-implementer, spec-review, and review-fix in sequence, pausing at quality gates for your approval.

## Further Reading

- [Agent-Specific Guides](agents/) -- setup and usage details per agent
- [Role Guides](roles/) -- what each role gets and why
- [Skill Reference](skill-reference.md) -- all 50 skills with descriptions
- [Pipeline Reference](pipeline-reference.md) -- all 22 pipelines with step chains
- [Customization](customization.md) -- gate thresholds, scoring weights, custom pipelines
