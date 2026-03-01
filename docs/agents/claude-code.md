# SDLC Central — Claude Code Guide

## Install

Run the installer with the `--agent` flag set to `claude-code` (this is also the default):

```bash
bash setup/install-role.sh developer --agent claude-code
```

To install all 50 skills:

```bash
bash setup/install-all.sh --agent claude-code
```

## What Gets Installed

The Claude Code adapter places skill files under the `.claude/` directory in your project root:

```
.claude/
  skills/
    review/
      SKILL.md          # Full skill prompt with frontmatter
    spec-gen/
      SKILL.md
    test-gen/
      SKILL.md
    ...
```

Each `SKILL.md` file contains YAML frontmatter (controlling `allowed-tools`, description, and other metadata) followed by the full skill prompt in Markdown.

## How Skills Work

Claude Code discovers skills from `.claude/skills/` automatically. Each skill is a standalone Markdown file with frontmatter that tells Claude Code what tools the skill is permitted to use. Skills are loaded on-demand when invoked — they are not all injected into context simultaneously, which keeps token usage efficient even with large installs.

## Invoking a Skill

Skills are invoked via slash commands in the Claude Code terminal:

- **Code review:** `/review` — runs the review skill against the current context or staged changes.
- **Spec generation:** `/spec-gen "SSO login for enterprise tenants"` — generates a product specification for the described feature.
- **Test generation:** `/test-gen src/auth/login.ts` — generates tests for the specified file.

## Running a Pipeline

Pipelines chain multiple skills together with gates between stages. Run a pipeline with:

```
/run-pipeline developer/feature-build --feature "Add SSO login"
```

This executes the feature-build pipeline, which typically runs spec-gen, then implementation scaffolding, then test-gen, then review — pausing at each gate for your approval before proceeding.

## HITL Gates

Claude Code handles human-in-the-loop gates by stopping execution and prompting you directly in the terminal. When a pipeline reaches a gate (for example, "approve spec before implementation"), Claude Code prints the output, asks for your confirmation, and waits. You can approve, reject with feedback, or abort the pipeline entirely. No special configuration is needed — HITL is built into the pipeline runner.

## Tips

- **Resume long pipelines.** If a pipeline is interrupted (network drop, terminal close), use `--resume` to pick up where you left off rather than restarting from scratch.
- **Commit `.claude/` to version control.** The skills directory is project-specific configuration. Committing it ensures every team member gets the same skills without re-running the installer.
- **On-demand loading keeps context lean.** Unlike agents that load all rules at startup, Claude Code only pulls in the skill you invoke. This means installing all 50 skills has no performance penalty — you only pay for what you use.
