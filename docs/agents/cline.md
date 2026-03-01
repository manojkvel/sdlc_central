# SDLC Central — Cline Guide

## Install

Run the installer with the `--agent` flag set to `cline`:

```bash
bash setup/install-role.sh developer --agent cline
```

To install all 50 skills:

```bash
bash setup/install-all.sh --agent cline
```

## What Gets Installed

The Cline adapter places skill files under `.clinerules/` with YAML frontmatter:

```
.clinerules/
  sdlc-review.md
  sdlc-spec-gen.md
  sdlc-test-gen.md
  sdlc-threat-model.md
  sdlc-deploy-check.md
  ...
```

Each file contains YAML frontmatter that defines triggers (auto, conditional, or manual) and a description, followed by the full skill prompt in Markdown. Cline reads these rule files and activates them based on the trigger configuration.

## How Skills Work

Cline loads rules from `.clinerules/` at session start and categorizes them by trigger type. Rules marked as `auto` are always active in context. Rules marked as `conditional` activate when Cline detects a matching situation (e.g., a code review context or a test generation request). Manual rules are available but must be explicitly referenced. This trigger system lets you control which skills are active without manually managing context.

## Invoking a Skill

Skills are invoked through natural language in Cline's chat interface:

- **Code review:** "Review the authentication module for bugs and security issues" — Cline matches the review rule and applies its structured checklist.
- **Spec generation:** "Generate a product spec for a notification preferences feature" — Cline activates the spec-gen rule and follows its template.
- **Deployment check:** "Run a pre-deployment check for the staging environment" — Cline applies the deploy-check rule to verify readiness.

## Running a Pipeline

Trigger a pipeline by referencing it in the Cline chat:

```
Run the devops/deploy-verify pipeline for the v2.3.0 release
```

Cline follows the pipeline definition, executing each skill in sequence and pausing at defined gates for your approval before proceeding to the next stage.

## HITL Gates

Cline has a built-in permission model that requires user approval before it makes changes to files, runs commands, or performs other actions. This aligns naturally with SDLC Central's HITL gates. When a pipeline reaches a gate, Cline presents the output and waits for your approval — just as it does for any action that requires permission. You approve, reject, or provide additional guidance directly in the chat. There is no extra configuration needed because Cline's native approval flow already enforces human oversight.

## Tips

- **Leverage Cline's approval model.** Cline's built-in permission system is a natural fit for HITL gates. Every pipeline gate maps cleanly to Cline's existing "approve before proceeding" pattern, giving you consistent control over each step.
- **Use conditional triggers wisely.** Setting skills to `conditional` rather than `auto` prevents unnecessary context consumption. Reserve `auto` for skills you want active in every conversation (e.g., coding conventions) and use `conditional` for situational skills (e.g., threat-model, deploy-check).
- **Commit `.clinerules/` to version control.** Sharing rule files across your team ensures everyone operates with the same SDLC practices. Cline picks them up automatically with no additional setup per developer.
