
# User Story Refiner

Transform a rough feature idea into a structured user story with acceptance criteria, edge cases, and scope boundaries. Designed for product owners, designers, and business analysts who know what they want but need help formatting it for a development team.

## CRITICAL RULES

1. **Preserve the original intent.** Don't reinterpret or expand the idea beyond what the user described. Clarify, don't invent.
2. **Write acceptance criteria that a QA person can test.** Each criterion must be verifiable — pass or fail, no ambiguity.
3. **Scope is a feature, not a bug.** Explicitly state what's out of scope so developers don't over-build.

---

## Phase 1 — Understand the Idea

Read `$ARGUMENTS` as a rough feature idea. It might be:

- A casual request: "users should be able to export their data"
- A problem statement: "customers keep asking how to download invoices"
- A partial requirement: "add dark mode to the settings page"
- A one-liner: "password reset"

### 1.1 Extract the Core

Identify:
- **Who** is this for? (all users, admin users, new users, etc.)
- **What** do they want to do? (the action)
- **Why** do they want it? (the benefit or problem being solved)

If any of these are unclear, ask the user before proceeding.

### 1.2 Check the Codebase for Context

Scan the codebase to understand:
- Does something similar already exist? (partial implementation, related feature)
- What's the current user flow in this area?
- Are there existing patterns (auth, navigation, data export) that this feature should follow?
- Any technical constraints visible (e.g., no existing PDF library, no email service configured)?

This context helps write realistic acceptance criteria.

## Phase 2 — Write the User Story

### 2.1 Story Format

Use the standard format:

```
As a [type of user],
I want to [action],
So that [benefit].
```

If the feature has multiple user types, write a separate story for each.

### 2.2 Acceptance Criteria

Write 4-8 acceptance criteria using "Given / When / Then" format:

```
Given [precondition],
When [action],
Then [expected result].
```

Each criterion must be:
- **Specific** — not "it works correctly" but "the export file contains all transactions from the selected date range"
- **Testable** — a QA person can verify pass/fail
- **Independent** — each criterion stands alone

### 2.3 Edge Cases

List 3-5 edge cases the developer should handle:

- What happens with empty data?
- What happens with very large data sets?
- What happens if the user loses connection mid-action?
- What happens with special characters or unusual input?
- What about permissions — can all users do this or only some?

### 2.4 Scope Boundary

Explicitly state what's **in scope** and **out of scope**:

**In scope:**
- [What this story covers]

**Out of scope (future stories):**
- [Related features that are explicitly NOT part of this story]
- [Extensions or enhancements to handle later]

## Phase 3 — Estimate Complexity

Provide a rough complexity indicator for sprint planning:

| Size | Criteria |
|------|----------|
| **Small** | Single component/page, no new API, no new data model |
| **Medium** | New API endpoint or data model change, 2-3 components |
| **Large** | Multiple new endpoints, data migration, cross-cutting concerns |
| **Epic** | Too large for one sprint — suggest breaking into smaller stories |

If the story is **Epic**, suggest 2-4 smaller stories it could be broken into.

## Phase 4 — Format Output

```markdown
## User Story: [Short Title]

### Story
As a [user type],
I want to [action],
So that [benefit].

### Acceptance Criteria
1. Given [precondition], When [action], Then [result].
2. Given [precondition], When [action], Then [result].
3. ...

### Edge Cases
- [Edge case 1 — what should happen]
- [Edge case 2 — what should happen]
- ...

### Scope
**In scope:**
- [item]

**Out of scope:**
- [item]

### Complexity: [Small | Medium | Large | Epic]

### Context
- **Existing related features:** [what already exists in the codebase]
- **Patterns to follow:** [existing conventions to reuse]
- **Dependencies:** [anything this depends on or blocks]

### Suggested Follow-Up Stories
- [Future enhancement 1]
- [Future enhancement 2]
```

## Phase 5 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Create a slug from the story title (e.g., `export-user-data`)
4. Save to: `reports/user-story-<slug>-<DATE>.md`
   - Include YAML front-matter: `date`, `title`, `complexity`, `acceptance_criteria_count`
5. Print the file path so the user knows where to find it
