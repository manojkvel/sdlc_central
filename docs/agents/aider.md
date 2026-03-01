# SDLC Central — Aider Guide

## Install

Run the installer with the `--agent` flag set to `aider`:

```bash
bash setup/install-role.sh developer --agent aider
```

To install all 50 skills:

```bash
bash setup/install-all.sh --agent aider
```

## What Gets Installed

The Aider adapter installs skill files under `.sdlc/skills/`, creates a `CONVENTIONS.md` index at the project root, and configures `.aider.conf.yml` to auto-load the conventions:

```
.sdlc/
  skills/
    review.md
    spec-gen.md
    test-gen.md
    threat-model.md
    ...
CONVENTIONS.md               # Index of all installed skills with summaries
.aider.conf.yml              # Aider config — references CONVENTIONS.md via read:
```

The `.aider.conf.yml` file includes a `read:` directive pointing to `CONVENTIONS.md`, which ensures Aider loads the skill index automatically on every startup. Individual skill files in `.sdlc/skills/` contain the full, detailed prompts.

## How Skills Work

When Aider starts, it reads `.aider.conf.yml`, which tells it to load `CONVENTIONS.md`. This file serves as an index listing all installed skills with brief descriptions and file paths. Aider holds this index in context so it knows what skills are available. When you reference a skill by name or describe a task that matches a skill, Aider can follow the conventions. For the full detailed prompt of any skill, you can load the individual file from `.sdlc/skills/` into the session.

## Invoking a Skill

Skills are invoked by referencing them in your Aider chat session:

- **Code review:** "Follow the review conventions and review src/auth.py" — Aider applies the review guidelines from the conventions.
- **Spec generation:** "Using the spec-gen conventions, generate a spec for batch processing" — Aider follows the spec template.
- **Loading a full skill mid-session:** Type `/read .sdlc/skills/threat-model.md` to load the complete threat-model skill into context, then ask "Threat model the payment gateway."

## Running a Pipeline

Run a pipeline by asking Aider to follow the pipeline steps:

```
Follow the developer/feature-build pipeline for "Add CSV export to reports"
```

Aider will work through each stage of the pipeline sequentially, generating artifacts and pausing at gates for your input before continuing.

## HITL Gates

Aider has a natural human-in-the-loop workflow: it always presents proposed changes and asks for your confirmation before applying them. This built-in approval step aligns directly with SDLC Central's HITL gates. At each pipeline gate, Aider shows you the output and waits for you to accept, reject, or revise. No additional gate mechanism is needed — Aider's default behavior already enforces human approval at every change.

## Tips

- **Use `/read` to load specific skills.** While `CONVENTIONS.md` provides an index, loading the full skill file with `/read .sdlc/skills/<name>.md` gives Aider the complete prompt with all details, checklists, and templates. This is especially useful for complex skills.
- **Keep `.aider.conf.yml` in version control.** This file ensures every developer on your team gets the same skill conventions loaded automatically. Combined with the committed `.sdlc/` directory, the entire setup is reproducible.
- **Manage context carefully.** Aider operates within model context limits. Loading too many full skill files at once can exhaust the context window. Load skills on-demand with `/read` rather than adding all of them to the session simultaneously.
