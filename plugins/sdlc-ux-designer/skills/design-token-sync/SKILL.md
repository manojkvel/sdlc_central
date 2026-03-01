---
name: design-token-sync
description: Extract design tokens from Figma variables and sync colors, spacing, and typography with the codebase token files
argument-hint: "<figma-url-or-file-key> [--format css|tailwind|json|scss]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls, find, cat, date), MCP(figma)
---

# Design Token Sync

Extract design tokens (colors, spacing, typography, shadows, border radii) from Figma variables and synchronize them with the codebase token files. Produces a diff of changes and applies updates to keep design and code in lockstep.

> **MCP tools used:** `get_variable_defs`, `get_screenshot`

## CRITICAL RULES

1. **Never overwrite token files without showing a diff first.** Always present changes for review.
2. **Preserve custom tokens.** If the codebase has tokens not in Figma (e.g., code-only utility tokens), keep them.
3. **Respect the project's token format.** Output must match the existing format — CSS custom properties, Tailwind config, JSON, SCSS variables, etc.

---

## Phase 1 — Parse the Input

Determine the Figma reference from `$ARGUMENTS`:

1. **Figma URL** — extract `fileKey` from the URL
2. **File key** — use directly if passed as a plain key
3. **`--format` flag** — if provided, use as the output format override (css, tailwind, json, scss)

If no arguments are provided, ask the user for a Figma file URL or key.

## Phase 2 — Extract Figma Tokens

### 2.1 Get Variable Definitions

Call the variable definitions tool with the `fileKey`. This returns all Figma variables organized by collection:

- **Colors** — primitives (hex, rgba) and semantic aliases (primary, secondary, error, etc.)
- **Spacing** — numeric scale values (4, 8, 12, 16, 24, 32, etc.)
- **Typography** — font families, sizes, weights, line heights, letter spacing
- **Border radius** — corner radius values
- **Shadows** — elevation and shadow definitions
- **Opacity** — opacity scale values

### 2.2 Organize by Category

Group the extracted tokens into a normalized structure:

```
tokens:
  color:
    primary: "#1A73E8"
    primary-hover: "#1557B0"
    ...
  spacing:
    xs: "4px"
    sm: "8px"
    ...
  typography:
    font-family-body: "Inter"
    font-size-base: "16px"
    ...
  radius:
    sm: "4px"
    md: "8px"
    ...
```

Handle mode variants (light/dark theme) by creating separate token sets per mode.

## Phase 3 — Survey Existing Tokens

Scan the codebase for existing token definitions:

1. **CSS custom properties** — search for `:root` blocks or `--token-` patterns in `.css` files
2. **Tailwind config** — check `tailwind.config.*` for `theme.extend` entries
3. **JSON tokens** — look for `tokens.json`, `design-tokens.json`, or similar
4. **SCSS variables** — search for `$token-` or `$color-` patterns in `.scss` files
5. **JavaScript/TypeScript theme** — check for `theme.ts`, `theme.js`, `tokens.ts` exports

Determine the primary token format used in the project. If `--format` was specified, use that instead.

## Phase 4 — Generate Diff

Compare Figma tokens against codebase tokens:

| Status | Meaning |
|--------|---------|
| `ADDED` | Token exists in Figma but not in codebase — new token |
| `MODIFIED` | Token exists in both but values differ — value changed |
| `UNCHANGED` | Token exists in both with same value — no action needed |
| `CODE-ONLY` | Token exists in codebase but not in Figma — preserve as-is |

### Diff Table

```
Status     | Token Name        | Figma Value   | Code Value    |
-----------|-------------------|---------------|---------------|
ADDED      | color/accent      | #FF6B35       | —             |
MODIFIED   | spacing/lg        | 32px          | 24px          |
UNCHANGED  | color/primary     | #1A73E8       | #1A73E8       |
CODE-ONLY  | color/code-bg     | —             | #F5F5F5       |
```

Present this diff to the user before applying any changes.

## Phase 5 — Apply Updates

After the user confirms (or if running in a pipeline with auto-apply):

1. **Add new tokens** — insert `ADDED` tokens into the appropriate file, following existing ordering and formatting
2. **Update changed tokens** — modify `MODIFIED` token values in place
3. **Preserve code-only tokens** — leave `CODE-ONLY` tokens untouched
4. **Handle theme modes** — if the project uses light/dark themes, update both mode files

Write changes to the correct files based on the detected (or specified) format:
- CSS: update `:root { }` or theme-specific blocks
- Tailwind: update `tailwind.config.*` theme section
- JSON: update the tokens JSON file
- SCSS: update variable declarations

## Phase 6 — Format Output

### Token Sync Summary

```
Source: Figma file <file-key>
Format: <css|tailwind|json|scss>
Tokens scanned: <total>
  Added: <count>
  Modified: <count>
  Unchanged: <count>
  Code-only (preserved): <count>
```

### Files Modified

List each file that was updated, with the number of token changes in each.

### Recommendations
- Tokens that exist in Figma but have no clear codebase mapping
- Tokens with naming mismatches that suggest a convention drift
- Missing theme modes (e.g., Figma has dark mode tokens but codebase doesn't)

## Phase 7 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Save the report to: `reports/design-token-sync-<DATE>.md`
   - Include YAML front-matter: `date`, `figma_file`, `tokens_added`, `tokens_modified`, `tokens_unchanged`
4. Print the file path so the user knows where to find it
