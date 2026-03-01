
# Bug Report Generator

Take a plain-English description of unexpected behavior and produce a structured, actionable bug report. Scans the codebase to identify the likely affected area, suggests reproduction steps, and outputs a report ready for the issue tracker.

## CRITICAL RULES

1. **Don't require technical knowledge from the reporter.** Accept descriptions like "the button doesn't work" and do the detective work.
2. **Never blame the reporter.** Frame everything constructively.
3. **Be specific in the report.** Vague bug reports waste developer time. Pin down the area, the behavior, and the expected outcome.

---

## Phase 1 — Gather the Bug Description

Read `$ARGUMENTS` as a plain-English description of the problem. If the description is too vague, ask clarifying questions:

- **What happened?** — the unexpected behavior
- **What did you expect?** — what should have happened instead
- **Where?** — which page, screen, feature, or workflow
- **When?** — always, sometimes, only after a specific action?
- **Any error messages?** — exact text if they saw one

If the user provides a screenshot path, read and analyze it for visible error messages, UI state, or clues.

## Phase 2 — Locate the Affected Area

Based on the description, search the codebase to identify the likely source:

1. **Keyword search** — grep for terms from the description (feature names, button labels, page titles, error messages)
2. **Route/page mapping** — if the user mentions a page or URL, find the corresponding route handler or page component
3. **Component search** — if the user describes a UI element, search for components matching that description
4. **Recent changes** — check `git log --since="2 weeks ago" --oneline` for recent changes in the suspected area

Record the likely files and modules. Don't modify anything — this is read-only investigation.

## Phase 3 — Assess Severity

Based on what you found, suggest a severity level:

| Severity | Criteria |
|----------|----------|
| **Critical** | Feature is completely broken, data loss possible, no workaround |
| **High** | Major feature broken but workaround exists, or affects many users |
| **Medium** | Feature partially broken, minor impact, or cosmetic issue affecting usability |
| **Low** | Cosmetic issue, edge case, or minor inconvenience |

## Phase 4 — Generate the Bug Report

Format the report for direct copy-paste into an issue tracker:

```markdown
## Bug Report

**Title:** [Short, specific title — e.g., "Checkout fails when cart has more than 50 items"]

**Severity:** [Critical | High | Medium | Low]

**Reported by:** [Reporter name if provided, otherwise "User report"]

### Description
[2-3 sentences describing the bug in clear language]

### Steps to Reproduce
1. [Step 1 — be specific about starting state]
2. [Step 2 — exact actions]
3. [Step 3 — what triggers the bug]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens — include error messages if any]

### Affected Area
- **Page/Feature:** [user-facing name]
- **Likely code location:** [file path(s) identified during investigation]
- **Recent changes:** [any relevant recent commits in that area]

### Environment
- **Platform:** [if mentioned — web, mobile, desktop]
- **Browser/Device:** [if mentioned]

### Additional Context
[Screenshots, related issues, workarounds, frequency]
```

## Phase 5 — Suggest Related Issues

If the codebase has an existing `reports/` directory with past bug reports or review findings, scan for related issues:
- Similar bugs in the same area
- Known tech debt that might be contributing
- Recent review findings that flagged the same module

## Phase 6 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Create a slug from the bug title (e.g., `checkout-fails-large-cart`)
4. Save to: `reports/bug-report-<slug>-<DATE>.md`
   - Include YAML front-matter: `date`, `severity`, `affected_area`, `reporter`
5. Print the file path so the user knows where to find it
