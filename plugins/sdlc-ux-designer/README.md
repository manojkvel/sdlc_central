# SDLC UX Designer Plugin

Figma-integrated UX designer skills for Claude Code. Provides 4 MCP-backed skills for design-to-code translation, token synchronization, component auditing, and visual fidelity review.

## Install

```bash
claude plugin install sdlc-ux-designer
```

Or install as part of the full SDLC Central designer role:

```bash
bash setup/install-role.sh designer --agent claude-code
```

## Prerequisites

This plugin requires the Figma MCP server. The plugin includes a `.mcp.json` that configures it automatically. You must be authenticated with Figma for the MCP tools to work.

## Skills

### `/design-to-code <figma-url>`

Translate a Figma design into production code. Extracts design context, checks Code Connect mappings for existing components, and generates code adapted to your project's stack and conventions.

### `/design-token-sync <figma-url> [--format css|tailwind|json|scss]`

Extract design tokens (colors, spacing, typography, shadows) from Figma variables and sync them with your codebase token files. Shows a diff before applying changes.

### `/component-audit <figma-url> [--scope full|unmapped|stale]`

Audit your codebase components against the Figma design system. Identifies unmapped components, orphaned implementations, stale Code Connect mappings, and coverage gaps.

### `/visual-review <figma-url> [--implementation path/to/component]`

Compare your implemented UI against the original Figma design. Reports discrepancies in layout, spacing, colors, typography, and visual details with a fidelity score.

## What's Included

```
skills/
├── design-to-code/SKILL.md
├── design-token-sync/SKILL.md
├── component-audit/SKILL.md
└── visual-review/SKILL.md
.mcp.json                    # Figma MCP server configuration
```

## Part of SDLC Central

This plugin is a standalone distribution of the UX designer skills from [SDLC Central](https://github.com/sdlc-central/sdlc-central). For the full 54-skill, 25-pipeline SDLC toolkit, see the main repository.
