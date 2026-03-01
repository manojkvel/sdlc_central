---
name: visual-review
description: Compare implemented UI against the Figma design to identify layout, spacing, color, and typography discrepancies
argument-hint: "<figma-url-or-node-id> [--implementation path/to/component]"
allowed-tools: Read, Write, Glob, Grep, Bash(ls, find, cat, date), MCP(figma)
---

# Visual Review

Compare the implemented UI against the original Figma design to verify visual fidelity. Identifies discrepancies in layout, spacing, colors, typography, and component rendering between the design source of truth and the running implementation.

> **MCP tools used:** `get_screenshot`, `get_design_context`, `get_variable_defs`

## CRITICAL RULES

1. **Design is the source of truth.** Unless the user says otherwise, the Figma design defines correct behavior.
2. **Pixel precision is not the goal.** Focus on perceivable differences — a 1px rounding difference is not a finding, but 8px of missing padding is.
3. **Categorize by severity.** A wrong brand color is critical; a slightly different shadow blur is low.

---

## Phase 1 — Parse the Input

Determine the Figma reference from `$ARGUMENTS`:

1. **Figma URL** — extract `fileKey` and `nodeId` from the URL
2. **File key + node ID** — use directly
3. **`--implementation` flag** — path to the implemented component or page for comparison

If no arguments are provided, ask the user for:
- The Figma URL or node reference for the design
- The file path, URL, or screenshot of the implementation

## Phase 2 — Gather Design Reference

### 2.1 Get Design Screenshot

Request a screenshot of the target Figma node. This is the visual source of truth. Study it carefully for:
- Overall layout structure (rows, columns, sections)
- Spacing between elements
- Color usage (backgrounds, text, borders, accents)
- Typography (font sizes, weights, line heights)
- Component states (hover, active, disabled if visible)
- Icons and imagery placement

### 2.2 Get Design Context

Call the design context tool to extract structured data:
- Exact color values used in the design
- Spacing values (padding, margins, gaps)
- Font specifications
- Component hierarchy
- Auto-layout properties (flex direction, gap, padding)

### 2.3 Get Design Tokens

Call the variable definitions tool to get the canonical token values. This lets you check whether the implementation is using the correct token rather than a close-but-wrong hardcoded value.

## Phase 3 — Gather Implementation Reference

The implementation reference comes from the user. Accept any of:

1. **Component file path** — read the component source code, identify rendered elements and their styling
2. **Screenshot file** — if the user provides a screenshot, analyze it visually
3. **Running URL** — if the user provides a URL, note that you cannot directly fetch/render it but can analyze the source code

If given a file path, read the component and trace its styling:
- CSS classes — resolve to actual values via stylesheets or Tailwind config
- Inline styles — extract directly
- Theme references — resolve through the project's theme system
- Design token references — verify they map to correct Figma values

## Phase 4 — Compare

Perform a systematic comparison across these dimensions:

### 4.1 Layout

| Check | What to Compare |
|-------|----------------|
| Structure | HTML element hierarchy matches Figma frame/group hierarchy |
| Direction | Flex direction matches auto-layout direction |
| Alignment | Justify/align matches Figma alignment settings |
| Wrapping | Wrap behavior matches design responsiveness |
| Ordering | Visual order of elements matches design |

### 4.2 Spacing

| Check | What to Compare |
|-------|----------------|
| Padding | Inner spacing matches Figma frame padding |
| Gap | Space between children matches auto-layout gap |
| Margin | Outer spacing between sections |
| Consistent scale | Spacing values use design tokens, not arbitrary numbers |

### 4.3 Color

| Check | What to Compare |
|-------|----------------|
| Background | Background colors match design fills |
| Text | Text colors match design text fills |
| Border | Border colors match design stroke colors |
| State colors | Hover, focus, active states use correct palette |
| Opacity | Any opacity values match design |

### 4.4 Typography

| Check | What to Compare |
|-------|----------------|
| Font family | Matches design font |
| Font size | Matches design text size |
| Font weight | Matches design text weight |
| Line height | Matches design line height |
| Letter spacing | Matches design letter spacing |
| Text alignment | Matches design text alignment |
| Text transform | Case transformation matches design |

### 4.5 Visual Details

| Check | What to Compare |
|-------|----------------|
| Border radius | Corner radius matches design |
| Shadows | Box shadow matches design effects |
| Icons | Correct icon, correct size, correct color |
| Images | Correct aspect ratio, object-fit behavior |

## Phase 5 — Format Output

### Visual Review Summary

```
Design source: Figma <file-key> / <node-id>
Implementation: <file-path or URL>
Overall fidelity: <High|Medium|Low>
```

### Discrepancies Found

For each discrepancy:
```
[CRITICAL|HIGH|MEDIUM|LOW] <Category>
Element: <component or element identifier>
Design: <expected value from Figma>
Implementation: <actual value in code>
Fix: <specific correction to make>
```

**Severity guide:**
- **Critical** — wrong brand color, missing component, broken layout
- **High** — wrong font size, wrong spacing scale step, missing state
- **Medium** — slightly off padding, minor alignment issue
- **Low** — shadow difference, subtle border radius mismatch

### Fidelity Score

```
Layout:     ████████░░  80%
Spacing:    █████████░  90%
Colors:     ██████████  100%
Typography: ████████░░  85%
Details:    ███████░░░  70%
Overall:    ████████░░  85%
```

### Recommended Fixes
Ordered list of changes to bring the implementation into alignment with the design. Group by file when multiple fixes apply to the same component.

## Phase 6 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Save the report to: `reports/visual-review-<DATE>.md`
   - Include YAML front-matter: `date`, `figma_file`, `fidelity_score`, `discrepancies_count`
4. Print the file path so the user knows where to find it
