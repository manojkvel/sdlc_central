---
name: design-to-code
description: Translate a Figma design into production code using MCP-backed design context, component mappings, and project conventions
argument-hint: "<figma-url-or-node-id> [--file-key KEY]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git diff, git log, ls, find, tree, date), MCP(figma)
---

# Design to Code

Translate a Figma design into production-ready code. This skill uses MCP-backed design tools to extract layout, styling, component structure, and design tokens from Figma, then generates code that respects the project's existing stack, component library, and conventions.

> **MCP tools used:** `get_design_context`, `get_screenshot`, `get_code_connect_map`

## CRITICAL RULES

1. **Never generate code without first reading the design.** Always extract design context before writing any code.
2. **Adapt to the project stack.** The raw design output is framework-agnostic reference material — always map it to the project's actual framework, component library, and token system.
3. **Reuse before creating.** Check for existing components, utilities, and design tokens in the codebase before generating new ones.
4. **Preserve design intent.** Spacing, alignment, color, and typography must match the design — do not "improve" or deviate without explicit instruction.

---

## Phase 1 — Parse the Input

Determine the Figma reference from `$ARGUMENTS`:

1. **Figma URL** — extract `fileKey` and `nodeId` from the URL:
   - `figma.com/design/:fileKey/:fileName?node-id=:nodeId` — convert `-` to `:` in nodeId
   - `figma.com/design/:fileKey/branch/:branchKey/:fileName` — use `branchKey` as fileKey
   - `figma.com/make/:makeFileKey/:makeFileName` — use makeFileKey
2. **File key + node ID** — if passed as separate arguments, use directly
3. **No arguments** — ask the user for a Figma URL or file key

If a `--file-key` flag is provided, use it to override the extracted file key.

## Phase 2 — Extract Design Context

Use the MCP design tools to gather all relevant information:

### 2.1 Get Design Context

Call the design context tool with the `fileKey` and `nodeId`. This returns:
- **Code snippet** — a reference implementation (typically React + Tailwind)
- **Screenshot** — visual representation of the design
- **Contextual hints** — annotations, component documentation, design tokens

Review the returned data carefully. The code snippet is a **starting point**, not final output.

### 2.2 Get Screenshot

If the design context didn't include a clear visual, request a screenshot separately. Use this as the visual source of truth for layout, spacing, and styling decisions.

### 2.3 Check Code Connect Mappings

Call the Code Connect mapping tool with the `fileKey` to see if any Figma components already have mapped codebase counterparts:

- **Mapped components** — use the codebase component directly instead of generating new code
- **Component documentation links** — follow them for usage context and prop signatures
- **Unmapped components** — these need fresh implementation

Record which components are mapped vs. unmapped. This determines what you generate vs. import.

## Phase 3 — Survey the Project

Before generating code, understand the target codebase:

1. **Framework detection** — scan for `package.json`, `requirements.txt`, `go.mod`, etc. Identify the UI framework (React, Vue, Svelte, Angular, vanilla)
2. **Component library** — check for shared component directories (`src/components/`, `ui/`, `lib/ui/`)
3. **Styling approach** — identify the CSS strategy:
   - Tailwind (`tailwind.config.*`)
   - CSS Modules (`*.module.css`)
   - Styled-components / Emotion
   - Plain CSS / SCSS
   - Design tokens file (CSS custom properties, JSON tokens)
4. **Existing patterns** — read 2-3 existing components to understand:
   - File naming conventions
   - Component structure (functional vs. class, export style)
   - Prop typing approach
   - Test file co-location

## Phase 4 — Generate Implementation

### 4.1 Map Design to Code

For each element in the design:

| Design Element | Code Mapping |
|---------------|-------------|
| Mapped component (Code Connect) | Import from codebase — use existing component with correct props |
| Design tokens (colors, spacing) | Map to project's token system (CSS vars, Tailwind config, theme) |
| Typography | Map to project's type scale or font configuration |
| Layout (auto-layout, frames) | Convert to flexbox/grid using project's utility classes or CSS approach |
| Icons | Check project's icon system first; only add new icons if missing |
| Images | Use project's image component or pattern (`<Image>`, `<img>`, lazy loading) |
| Interactions (hover, focus) | Implement using project's interaction patterns (pseudo-classes, event handlers) |

### 4.2 Write the Component

Generate the component following these rules:

1. **File location** — place in the project's component directory structure
2. **Naming** — follow project conventions (PascalCase, kebab-case, etc.)
3. **Props** — derive from design variants and content slots; type them properly
4. **Styling** — use the project's styling approach, not the raw Tailwind from design context
5. **Accessibility** — include ARIA attributes, keyboard handlers, semantic HTML
6. **Responsiveness** — if the design shows multiple breakpoints, implement responsive behavior

### 4.3 Handle Variants

If the design contains component variants (states, sizes, themes):
- Map each variant to a prop or prop combination
- Implement all variants shown in the design
- Use the project's pattern for variant management (cva, classnames, style props, etc.)

## Phase 5 — Validate

### 5.1 Visual Comparison

Compare the generated code against the design screenshot:
- Layout and spacing match
- Colors match design tokens
- Typography (font, size, weight, line-height) is correct
- Icons and images are placed correctly

### 5.2 Code Quality

- Component is self-contained with clear prop boundaries
- No hardcoded values that should be tokens
- Imports use project conventions (absolute vs. relative paths)
- No unused imports or dead code

## Phase 6 — Format Output

### Design Source
```
Figma: <file-key> / <node-id>
Screenshot: [attached]
Components mapped via Code Connect: <count>
Components generated new: <count>
```

### Files Created/Modified

List each file with a brief description of what was generated or changed.

### Token Mappings

| Design Token | Codebase Value |
|-------------|---------------|
| `color/primary` | `var(--color-primary)` or `text-primary` |
| `spacing/md` | `var(--space-4)` or `p-4` |

### Implementation Notes
- Decisions made during translation (e.g., "Used existing `<Button>` component instead of generating a new one")
- Any design elements that couldn't be directly translated
- Suggested follow-ups (missing tokens, components to extract, etc.)

## Phase 7 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Save the report to: `reports/design-to-code-<DATE>.md`
   - Include YAML front-matter: `date`, `figma_file`, `components_mapped`, `components_generated`
4. Print the file path so the user knows where to find it
