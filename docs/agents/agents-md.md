# SDLC Central — AGENTS.md Guide

## Install

Run the installer with the `--agent` flag set to `agents-md`:

```bash
bash setup/install-role.sh developer --agent agents-md
```

To install all 50 skills:

```bash
bash setup/install-all.sh --agent agents-md
```

## What Gets Installed

The AGENTS.md adapter compiles everything into a single `AGENTS.md` file at the project root:

```
AGENTS.md                    # All installed skills compiled into one file
```

The file begins with a structured index listing every installed skill by name and description. Below the index, each skill's full prompt appears under its own Markdown heading. Pipeline definitions are included at the end of the file. The entire file is self-contained — no external references or additional directories are needed.

## How Skills Work

`AGENTS.md` is a universal format designed to work with any AI coding tool that reads project-level instruction files. When a tool opens your project and reads `AGENTS.md`, it gains access to all installed skills. The tool uses the index and section headings to locate the relevant skill based on your request. There is no agent-specific discovery mechanism — the format relies on the consuming tool's ability to read and follow Markdown instructions.

## Invoking a Skill

Skills are invoked via natural language, referencing the skill name for best results:

- **Code review:** "Following the review skill in AGENTS.md, review src/services/payment.ts" — the tool locates the review section and applies its checklist.
- **Spec generation:** "Using the spec-gen skill, generate a spec for an email notification system" — the tool follows the spec-gen template from AGENTS.md.
- **Test generation:** "Per the test-gen skill in AGENTS.md, write tests for the user registration flow" — the tool generates tests according to the defined conventions.

## Running a Pipeline

Run a pipeline by asking the tool to follow the pipeline definition in AGENTS.md:

```
Follow the qa/test-strategy pipeline in AGENTS.md for the checkout module
```

The tool reads the pipeline steps and executes each skill in order, pausing at gates for your input. How smoothly this works depends on the consuming tool's ability to follow multi-step instructions.

## HITL Gates

HITL gate behavior depends entirely on the consuming tool. Most AI coding assistants will present output and wait for your response before continuing, which provides a natural gate. If your tool does not pause automatically, you can enforce gates manually by instructing the tool to "stop and wait for my approval" at each gate point. The pipeline definitions in AGENTS.md include gate markers that a capable tool can interpret as pause points.

## Tips

- **This is the most portable format.** If your AI coding tool is not directly supported by SDLC Central (not one of the 8 other adapters), AGENTS.md is your best option. Any tool that reads Markdown files from the project root can use it.
- **Be aware of file size.** Because all skills are compiled into a single file, a full 50-skill install produces a large AGENTS.md. This can consume significant context in tools with limited context windows. Use role-based installs to keep the file manageable, especially for tools with tight token limits.
- **Reference skill names explicitly.** Since the consuming tool may not have a sophisticated rule-matching system, naming the exact skill (e.g., "use the threat-model skill") in your prompt ensures the tool finds and follows the correct section rather than guessing from context.
