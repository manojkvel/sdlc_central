---
name: component-audit
description: Audit codebase components against the Figma design system to detect drift, unmapped components, and stale mappings
argument-hint: "<figma-url-or-file-key> [--scope full|unmapped|stale]"
allowed-tools: Read, Write, Glob, Grep, Bash(git log, ls, find, tree, wc, date), MCP(figma)
---

# Component Audit

Audit codebase components against the Figma design system to detect drift. Identifies unmapped components, orphaned implementations, stale Code Connect mappings, and usage gaps between design and code.

> **MCP tools used:** `get_code_connect_map`, `get_code_connect_suggestions`, `get_metadata`

## CRITICAL RULES

1. **Audit is read-only.** This skill reports findings — it does not modify code or Figma mappings.
2. **Both directions matter.** Check for design components missing from code AND code components missing from the design system.
3. **Context over counts.** A component used in 50 places but not mapped to Figma is more critical than an unused helper.

---

## Phase 1 — Parse the Input

Determine the Figma reference from `$ARGUMENTS`:

1. **Figma URL** — extract `fileKey` from the URL
2. **File key** — use directly
3. **`--scope` flag** — controls audit depth:
   - `full` (default) — complete bidirectional audit
   - `unmapped` — only show components without Code Connect mappings
   - `stale` — only show mappings that reference moved or deleted code

If no arguments are provided, ask the user for a Figma file URL or key.

## Phase 2 — Gather Design System Data

### 2.1 Get Code Connect Map

Call the Code Connect mapping tool with the `fileKey`. This returns all existing mappings between Figma components and codebase files. Record:

- **Component name** in Figma
- **Mapped file path** in the codebase
- **Props mapping** (if available)
- **Last updated** timestamp (if available)

### 2.2 Get Code Connect Suggestions

Call the suggestions tool to discover Figma components that could be mapped but currently aren't. These are candidates for new mappings.

### 2.3 Get File Metadata

Call the metadata tool with the `fileKey` to understand the overall structure of the Figma file — page count, component count, style count.

## Phase 3 — Scan the Codebase

### 3.1 Find Component Directories

Search for component directories in the project:
- `src/components/`, `app/components/`, `lib/components/`, `ui/`
- Framework-specific: `pages/`, `views/`, `layouts/`
- Look for barrel files (`index.ts`, `index.js`) that export components

### 3.2 Build Component Inventory

For each discovered component:
- **Name** — derived from file name or export name
- **Path** — full file path
- **Export type** — default export, named export, re-export
- **Usage count** — grep for imports of this component across the codebase
- **Has tests** — check for co-located or matching test files

### 3.3 Cross-Reference

Match codebase components against Code Connect mappings:

| Status | Meaning |
|--------|---------|
| `MAPPED` | Component exists in both Figma and code with a Code Connect mapping |
| `UNMAPPED-IN-CODE` | Component exists in code but has no Figma mapping |
| `UNMAPPED-IN-FIGMA` | Component exists in Figma (from suggestions) but has no code implementation |
| `STALE` | Mapping exists but the referenced code file is missing or moved |
| `ORPHANED` | Code component exists but is never imported anywhere |

## Phase 4 — Analyze Findings

### 4.1 Coverage Metrics

```
Design System Coverage:
  Figma components total: <N>
  Mapped to code: <N> (<percent>%)
  Unmapped (need mapping): <N>

Codebase Coverage:
  Code components total: <N>
  Mapped to Figma: <N> (<percent>%)
  Unmapped (code-only): <N>
  Orphaned (unused): <N>

Mapping Health:
  Active mappings: <N>
  Stale mappings: <N>
```

### 4.2 Priority Assessment

Rank findings by impact:
- **Critical** — stale mappings (actively broken), high-use unmapped components
- **High** — Figma components with no code (design intent not implemented)
- **Medium** — code components with no Figma mapping (documentation gap)
- **Low** — orphaned components (cleanup opportunity)

## Phase 5 — Format Output

### Component Audit Report

#### Summary
One-paragraph overview of design system health.

#### Coverage Dashboard

```
Design → Code:  ████████░░  78% mapped
Code → Design:  ██████░░░░  62% mapped
Mapping Health: █████████░  94% active
```

#### Findings

For each finding:
```
[CRITICAL|HIGH|MEDIUM|LOW] <Status>
Component: <name>
Figma: <component-path-in-figma or "none">
Code: <file-path or "none">
Usage: <import count across codebase>
Action: <recommended action>
```

#### Recommended Actions
Prioritized list:
1. Fix stale mappings (broken references)
2. Map high-usage code components to Figma
3. Implement missing Figma components
4. Clean up orphaned code components

## Phase 6 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Save the report to: `reports/component-audit-<DATE>.md`
   - Include YAML front-matter: `date`, `figma_file`, `design_coverage_pct`, `code_coverage_pct`, `stale_mappings`
4. Print the file path so the user knows where to find it
