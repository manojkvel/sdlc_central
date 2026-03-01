# SDLC Central — Antigravity Guide

## Install

Run the installer with the `--agent` flag set to `antigravity`:

```bash
bash setup/install-role.sh developer --agent antigravity
```

To install all 50 skills:

```bash
bash setup/install-all.sh --agent antigravity
```

## What Gets Installed

The Antigravity adapter places skills under `.antigravity/rules/`, workflows under `.antigravity/workflows/`, and creates an index file:

```
.antigravity/
  rules/
    sdlc-review.md
    sdlc-spec-gen.md
    sdlc-test-gen.md
    sdlc-threat-model.md
    sdlc-index.md              # Index listing all installed skills
    ...
  workflows/
    feature-build.yaml
    pr-workflow.yaml
    deploy-verify.yaml
    ...
```

Each rule file in `.antigravity/rules/` contains the full skill prompt. The `sdlc-index.md` file provides a catalog of all installed skills with names, descriptions, and file paths. Workflow files in `.antigravity/workflows/` define pipeline step chains that reference the installed skills.

## How Skills Work

Antigravity loads rules from `.antigravity/rules/` and makes them available based on context matching. The agent reads the index file to understand the full set of available skills and selects the relevant rule when your request matches a skill's domain. Workflows in `.antigravity/workflows/` define multi-step processes that chain skills together with gates and dependencies.

## Invoking a Skill

Skills are invoked via natural language in the Antigravity interface:

- **Code review:** "Review the database migration scripts for correctness and rollback safety" — Antigravity matches the review rule and applies its structured checklist.
- **Spec generation:** "Generate a product spec for a multi-tenant billing system" — Antigravity follows the spec-gen rule template.
- **Threat modeling:** "Analyze the API gateway for security threats" — Antigravity applies the threat-model rule to identify attack surfaces and recommend mitigations.

## Running a Pipeline

Trigger a pipeline by referencing the workflow:

```
Run the developer/feature-build workflow for "Add search functionality to the dashboard"
```

Antigravity reads the workflow definition from `.antigravity/workflows/`, executes each skill in sequence, and pauses at defined gates for your approval before advancing to the next stage.

## HITL Gates

When a pipeline reaches a human-in-the-loop gate, Antigravity presents the current stage output and a set of options in the interface. It waits for your reply before proceeding. You can approve the output to continue, provide feedback to trigger a revision, or abort the pipeline. The gate interaction is conversational — respond directly and Antigravity acts on your decision.

## Tips

- **Check `sdlc-index.md` for available skills.** The index file at `.antigravity/rules/sdlc-index.md` lists every installed skill with its description and file path. Consult it to discover which skills are available and how to reference them.
- **Commit the `.antigravity/` directory.** Both `rules/` and `workflows/` should be committed to version control so your team shares the same skills and pipeline definitions without re-running the installer.
- **Use workflows for repeatable processes.** Rather than invoking skills one at a time, define your team's common processes as workflows in `.antigravity/workflows/`. This ensures consistency across team members and enforces gates at the right points in each process.
