# SDLC Central — Windsurf Guide

## Install

Run the installer with the `--agent` flag set to `windsurf`:

```bash
bash setup/install-role.sh developer --agent windsurf
```

To install all 50 skills:

```bash
bash setup/install-all.sh --agent windsurf
```

## What Gets Installed

The Windsurf adapter installs skills to two locations — a condensed version under `.windsurf/rules/` and the full version under `.sdlc/skills/`:

```
.windsurf/
  rules/
    sdlc-review.md          # Condensed (max 6000 chars)
    sdlc-spec-gen.md
    sdlc-test-gen.md
    ...
.sdlc/
  skills/
    review.md                # Full, unabridged skill prompt
    spec-gen.md
    test-gen.md
    ...
```

Windsurf enforces a 6000-character limit per rule file. The adapter automatically condenses each skill to fit within this limit. If a skill exceeds the threshold, the condensed version includes a reference pointing to the full version in `.sdlc/skills/`.

## How Skills Work

Windsurf loads rules from `.windsurf/rules/` and makes them available in its Cascade panel. Rules are matched to your conversation context automatically. When a skill has been condensed to fit the 6000-character limit, Windsurf uses the abbreviated version for context matching, but the full instructions remain accessible in `.sdlc/skills/` for detailed reference.

## Invoking a Skill

Skills are invoked via natural language in Windsurf's Cascade panel or through @mentions:

- **Code review:** "Review src/api/routes.ts for security and performance issues" — Windsurf matches the review rule and applies its guidelines.
- **Spec generation:** "@sdlc-spec-gen Generate a spec for real-time notifications via WebSocket" — directly references the skill by name.
- **Test generation:** "Write unit tests for the payment processing module" — Windsurf picks up the test-gen rule from context.

## Running a Pipeline

Trigger a pipeline by asking Windsurf to execute the pipeline steps:

```
Run the developer/pr-workflow pipeline for the changes in this branch
```

Windsurf follows the pipeline definition, executing each stage and pausing at gates for your input.

## HITL Gates

At each human-in-the-loop gate, Windsurf pauses execution in the Cascade panel and presents the current output along with a prompt for your decision. You can approve to continue, provide feedback to revise, or abort the pipeline. The interaction happens inline within the Cascade conversation.

## Tips

- **Check `.sdlc/skills/` for full instructions.** If a condensed rule in `.windsurf/rules/` seems to be missing detail, open the corresponding file in `.sdlc/skills/` for the complete, unabridged prompt. This is especially relevant for complex skills like threat-model or architecture-review that often exceed the 6000-character limit.
- **Commit both directories.** Both `.windsurf/rules/` and `.sdlc/skills/` should be committed to version control so your team shares the same skill definitions.
- **Prefer role-based installs.** Since Windsurf loads rules into context, keeping the number manageable (10-20 per role) avoids unnecessary context consumption and keeps responses fast and focused.
