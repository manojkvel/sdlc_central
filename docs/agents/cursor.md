# SDLC Central — Cursor Guide

## Install

Run the installer with the `--agent` flag set to `cursor`:

```bash
bash setup/install-role.sh developer --agent cursor
```

To install all 50 skills:

```bash
bash setup/install-all.sh --agent cursor
```

## What Gets Installed

The Cursor adapter places skill files as rule files under `.cursor/rules/`:

```
.cursor/
  rules/
    sdlc-review.mdc
    sdlc-spec-gen.mdc
    sdlc-test-gen.mdc
    sdlc-threat-model.mdc
    ...
```

Each `.mdc` file contains YAML frontmatter (with `alwaysApply: true` and a description) followed by the skill prompt in Markdown. Cursor treats these as project-level rules that are automatically available in every chat session.

## How Skills Work

Cursor loads rules from `.cursor/rules/` and matches them to your conversation based on context. Because each SDLC skill is installed with `alwaysApply: true` in its frontmatter, Cursor considers all installed rules as candidates for every interaction. The agent picks the most relevant rules based on the content of your message and the files you have open, then applies them to shape its response.

## Invoking a Skill

Skills are invoked through natural language in Cursor Chat. There are no slash commands — just describe what you need:

- **Code review:** "Review this code for security issues and maintainability" — Cursor matches the review rule and applies its checklist.
- **Spec generation:** "Generate a spec for SSO login with SAML support" — Cursor picks up the spec-gen rule and follows its template.
- **Threat modeling:** "Threat model the authentication module" — Cursor applies the threat-model rule to analyze attack surfaces.

## Running a Pipeline

Pipelines are run by asking Cursor to follow the pipeline steps in sequence:

```
Run the developer/pr-workflow pipeline for my staged changes
```

Cursor will reference the pipeline definition and execute each step, pausing at gates to ask for your input before moving to the next stage.

## HITL Gates

When a pipeline reaches a human-in-the-loop gate, Cursor presents the output and options directly in the chat panel. It waits for your reply before continuing. You can approve, request changes, or cancel. Since Cursor Chat is conversational, the gate interaction feels natural — just respond in the chat thread.

## Tips

- **Watch your rule count.** Cursor loads all matching rules into context for every interaction. Installing more than 20 skills can consume a significant portion of the context window and slow responses. Prefer role-based installs (e.g., `install-role.sh developer`) over `install-all.sh` unless you genuinely need all 50 skills.
- **Commit `.cursor/rules/` to version control.** This ensures your entire team shares the same SDLC rules without each person running the installer individually.
- **Be specific in your prompts.** While Cursor auto-matches rules, naming the skill explicitly (e.g., "following the review guidelines, check this PR") improves the chance that the correct rule is selected and applied in full.
