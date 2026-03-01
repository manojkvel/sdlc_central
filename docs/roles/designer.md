# Designer Role Guide

## Your Toolkit

**13 skills | 5 pipelines** -- Design-to-code translation, token synchronization, component auditing, visual fidelity review, spec collaboration, plus non-coder essentials (bug reporting, codebase Q&A, user stories, changelogs). Powered by Figma MCP integration.

## Install

```bash
# Claude Code (default)
bash setup/install-role.sh designer --agent claude-code

# Windsurf
bash setup/install-role.sh designer --agent windsurf

# Standalone plugin (Claude Code only — 4 Figma skills + MCP config)
claude plugin install sdlc-ux-designer
```

## Prerequisites

The 4 Figma-backed skills require the Figma MCP server. The installer creates a `.mcp.json` at the project root, or you can add it manually:

```json
{
  "mcpServers": {
    "figma": {
      "type": "http",
      "url": "https://mcp.figma.com/mcp"
    }
  }
}
```

## Common Workflows

### 1. Translate a Figma Design to Code

Extract design context from Figma, check component mappings, and generate production code.

**Claude Code:**
```
/design-to-code https://figma.com/design/abc123/MyDesign?node-id=1-234
```

**Cursor / Windsurf (natural language):**
```
Run design-to-code for https://figma.com/design/abc123/MyDesign?node-id=1-234
```

Or run the full pipeline:

```
/run-pipeline designer/design-implementation https://figma.com/design/abc123/MyDesign?node-id=1-234
```

### 2. Sync Design Tokens

Extract colors, spacing, and typography from Figma variables and sync with codebase token files.

**Claude Code:**
```
/design-token-sync https://figma.com/design/abc123/DesignSystem --format tailwind
```

Or run the full pipeline:

```
/run-pipeline designer/design-system-sync https://figma.com/design/abc123/DesignSystem
```

### 3. Audit Component Coverage

Check which Figma components have Code Connect mappings and which codebase components are orphaned.

**Claude Code:**
```
/component-audit https://figma.com/design/abc123/DesignSystem --scope full
```

### 4. Visual Fidelity Review

Compare the implemented UI against the original Figma design.

**Claude Code:**
```
/visual-review https://figma.com/design/abc123/MyDesign?node-id=1-234 --implementation src/components/Hero.tsx
```

### 5. Collaborate on a Spec

Generate or refine a spec, then review it for design-relevant completeness.

**Claude Code:**
```
/spec-gen "Add user onboarding flow with progressive disclosure"
/spec-review specs/onboarding/spec.md
```

Or run the full pipeline:

```
/run-pipeline designer/spec-collaboration "Add user onboarding flow"
```

### 6. Design Handoff to Engineering

Prepare a complete handoff package — extract design, generate spec, review, and produce documentation.

```
/run-pipeline designer/design-handoff https://figma.com/design/abc123/MyDesign?node-id=1-234
```

### 7. Validate a Design Against the Spec

Review architecture and API contracts to verify the implementation matches design intent.

**Claude Code:**
```
/design-review src/onboarding/
/api-contract-analyzer full
```

Or run the full pipeline:

```
/run-pipeline designer/design-validation specs/onboarding/spec.md
```

### 8. Generate Documentation

**Claude Code:**
```
/doc-gen api
/doc-gen src/components/
```

## Key Skills

| Skill | When to Use |
|-------|------------|
| `design-to-code` | Translate a Figma design into production code |
| `design-token-sync` | Sync design tokens (colors, spacing, typography) from Figma |
| `component-audit` | Audit component coverage between Figma and codebase |
| `visual-review` | Compare implemented UI against Figma for visual fidelity |
| `spec-gen` | Generate or co-author a structured technical spec |
| `spec-review` | Validate that the implementation matches spec intent |
| `design-review` | Review architecture and design patterns for consistency |
| `api-contract-analyzer` | Verify API surfaces have not diverged from spec |
| `doc-gen` | Generate or update documentation for components or APIs |
| `bug-report` | Generate a structured bug report from a plain-English description |
| `codebase-qa` | Ask plain-English questions about the codebase |
| `user-story-refiner` | Transform a rough idea into a structured user story |
| `changelog-plain` | Translate technical changelogs into plain language |

## Pipelines

| Pipeline | Steps | Purpose |
|----------|-------|---------|
| `design-implementation` | 5 | Figma design to verified code implementation |
| `design-system-sync` | 4 | Token extraction, component audit, and sync |
| `design-handoff` | 4 | Design to engineering handoff package |
| `spec-collaboration` | 2 | Spec generation and review |
| `design-validation` | 2 | Architecture and API contract validation |

## Handoff

Once the spec is reviewed and design-validated, hand it to the **Architect** to begin planning:

```
/run-pipeline architect/design-to-plan specs/onboarding/spec.md
```

The architect receives the spec with your design review notes as context for creating the implementation plan.
