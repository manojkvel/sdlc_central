# SDLC Central — Gemini CLI Guide

## Install

Run the installer with the `--agent` flag set to `gemini`:

```bash
bash setup/install-role.sh developer --agent gemini
```

To install all 50 skills:

```bash
bash setup/install-all.sh --agent gemini
```

## What Gets Installed

The Gemini adapter compiles all skills into a single `GEMINI.md` file at the project root:

```
GEMINI.md                    # All installed skills compiled into one file
```

The file begins with an index listing every installed skill by name and description, followed by the full prompt for each skill separated by clear Markdown headings. Gemini CLI reads this file as project-level instructions, similar to how Claude Code reads `CLAUDE.md`.

## How Skills Work

Gemini CLI automatically reads `GEMINI.md` from the project root when you start a session. All skills contained in the file are loaded into context at once. Gemini uses the skill index and headings to locate the relevant skill when you make a request. Because everything is in a single file, there is no file-matching or auto-attach mechanism — Gemini simply has all skills available and selects the appropriate one based on your prompt.

## Invoking a Skill

Skills are invoked via natural language in the Gemini CLI terminal. Reference the skill name or describe the task:

- **Spec generation:** "Generate a spec for user authentication with OAuth2" — Gemini locates the spec-gen skill in GEMINI.md and follows its template.
- **Code review:** "Review the changes in src/api/handlers.go for performance issues" — Gemini applies the review skill checklist.
- **Threat modeling:** "Threat model the file upload service" — Gemini follows the threat-model skill prompt to analyze attack vectors and mitigations.

## Running a Pipeline

Run a pipeline by referencing it in your Gemini session:

```
Run the architect/design-to-plan pipeline for "Migrate from monolith to microservices"
```

Gemini reads the pipeline definition from GEMINI.md (or the associated pipeline YAML) and works through each stage, pausing at gates for your input before moving forward.

## HITL Gates

Gemini CLI handles HITL gates by pausing in the terminal and asking for your approval. When a pipeline reaches a gate, Gemini prints the current output and a prompt asking you to approve, reject, or provide feedback. You respond directly in the terminal, and Gemini continues or revises accordingly. The interaction is straightforward — a terminal prompt and your typed response.

## Tips

- **Consider role-based installs for large teams.** Installing all 50 skills produces a very large `GEMINI.md` file, which consumes a significant portion of the context window on every session. If you primarily work in one role (e.g., developer), install only that role's skills to keep the file focused and context usage efficient.
- **Regenerate after updates.** When you update SDLC Central with `bash setup/update.sh`, re-run the installer to regenerate `GEMINI.md` with the latest skill prompts. The single-file format means the entire file is replaced on each install.
- **Commit `GEMINI.md` to version control.** This ensures your team shares the same skill set. Since it is a single file, merge conflicts are possible if multiple people install different roles — coordinate on a single role set or have one person manage the install.
