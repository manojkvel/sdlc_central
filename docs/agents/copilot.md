# SDLC Central — GitHub Copilot Guide

## Install

Run the installer with the `--agent` flag set to `copilot`:

```bash
bash setup/install-role.sh developer --agent copilot
```

To install all 50 skills:

```bash
bash setup/install-all.sh --agent copilot
```

## What Gets Installed

The Copilot adapter places instruction files under `.github/instructions/`:

```
.github/
  instructions/
    sdlc-review.instructions.md
    sdlc-spec-gen.instructions.md
    sdlc-test-gen.instructions.md
    sdlc-deploy-check.instructions.md
    ...
```

Each `.instructions.md` file contains YAML frontmatter with an `applyTo` glob (e.g., `applyTo: "**/*.ts"`) that tells Copilot when to auto-attach the instruction, followed by the full skill prompt.

## How Skills Work

Copilot Chat reads instruction files from `.github/instructions/` and auto-attaches them based on the `applyTo` glob patterns in their frontmatter. For example, a review skill with `applyTo: "**/*.ts"` is automatically included in context when you are working with TypeScript files. Instructions without a matching glob can still be referenced explicitly by name. Copilot selects which instructions to surface based on the files in your current editor context.

## Invoking a Skill

Skills are invoked through Copilot Chat. Reference the instruction file by name for the best results:

- **Code review:** "Following the sdlc-review instructions, review the changes in src/auth/login.ts" — Copilot applies the review checklist.
- **Spec generation:** "Using the sdlc-spec-gen instructions, generate a spec for user registration with email verification" — Copilot follows the spec template.
- **Test generation:** "Per the sdlc-test-gen instructions, write tests for src/utils/parser.ts" — Copilot generates tests according to the defined conventions.

## Running a Pipeline

Run a pipeline by asking Copilot Chat to follow the pipeline steps sequentially:

```
Following the developer/feature-build pipeline, start the workflow for "Add OAuth2 support"
```

Copilot will work through each pipeline stage, generating the required artifacts and pausing at gates.

## HITL Gates

When a pipeline reaches a gate requiring human approval, Copilot presents the output in the Copilot Chat panel and asks for your decision. You reply directly in the chat to approve, reject, or provide feedback. Copilot then continues or revises based on your response.

## Tips

- **Reference instruction files explicitly.** Copilot's auto-attach via `applyTo` globs works well for file-type-specific skills, but for general skills (like spec-gen or threat-model), you get better results by naming the instruction file in your prompt. This ensures Copilot includes the full skill in context rather than relying on automatic matching.
- **Be mindful of context limits.** Copilot has a relatively limited context window compared to some other agents. If you install many skills, not all of them can be active simultaneously. Stick to role-based installs to keep the set focused.
- **Commit `.github/instructions/` to your repository.** These files are project configuration. Committing them lets every contributor benefit from the same SDLC skills, and they integrate naturally with your existing `.github/` directory structure.
