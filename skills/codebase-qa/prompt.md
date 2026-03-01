
# Codebase Q&A

Answer plain-English questions about the codebase without requiring the asker to read code. Designed for product owners, designers, QA, and other non-technical team members who need to understand what the system does, supports, or how it behaves.

## CRITICAL RULES

1. **Answer in plain English.** No code snippets in the response unless the user explicitly asks for them. Describe behavior, not implementation.
2. **Be honest about uncertainty.** If the code is ambiguous or you can't find a definitive answer, say "Based on what I can see..." rather than guessing.
3. **Stay read-only.** This skill only investigates — it never modifies code.
4. **Scope your answer.** Tell the user which part of the codebase you checked, so they know the answer's boundaries.

---

## Phase 1 — Understand the Question

Read `$ARGUMENTS` as a plain-English question. Common question types:

| Question Type | Example | Investigation Strategy |
|--------------|---------|----------------------|
| **Does it support X?** | "Does our app support dark mode?" | Search for feature flags, config options, CSS themes |
| **How does X work?** | "How does the login process work?" | Trace the flow from entry point through to completion |
| **Where is X?** | "Where do we handle payments?" | Search for relevant modules, routes, services |
| **What happens when X?** | "What happens when a session expires?" | Find the handler and trace the behavior |
| **Who can do X?** | "Who can delete a user account?" | Check authorization, roles, permissions |
| **What data does X use?** | "What info do we collect during signup?" | Check form fields, API payloads, database models |
| **Is X configurable?** | "Can we change the session timeout?" | Search for config files, environment variables |

## Phase 2 — Investigate

### 2.1 Broad Search

Start with a broad search to understand the landscape:
- Search for keywords from the question across the codebase
- Check project structure to understand where relevant code lives
- Read any existing documentation (`README`, `docs/`, inline comments)

### 2.2 Deep Dive

Once you've located the relevant area:
- Read the key files to understand the actual behavior
- Trace the flow from user action to system response
- Check for configuration, feature flags, or environment variables that modify behavior
- Look for edge cases and error handling

### 2.3 Check for Constraints

- Are there rate limits, size limits, or other restrictions?
- Are there role-based permissions that affect who can do what?
- Are there feature flags that enable/disable the behavior?
- Is the feature different in different environments (dev, staging, prod)?

## Phase 3 — Compose the Answer

Structure your answer for a non-technical audience:

### 3.1 The Short Answer

Start with a clear, 1-2 sentence answer to the question. Yes/no questions get a yes/no first.

> **Yes, the app supports dark mode.** It switches automatically based on the user's system settings, and users can also toggle it manually from the settings page.

### 3.2 How It Works (Plain English)

If the question asks "how" or the behavior is nuanced, explain the flow in plain language:

> When a user logs in:
> 1. They enter their email and password
> 2. The system checks if the account exists and the password is correct
> 3. If correct, they're sent a verification code to their email
> 4. After entering the code, they're logged in and stay logged in for 30 days
> 5. If they're inactive for 2 hours, they'll need to log in again

### 3.3 Important Caveats

Note anything the asker should be aware of:
- Limitations ("This only works for admin users, not regular users")
- Conditions ("This only applies when the feature flag `NEW_CHECKOUT` is enabled")
- Gaps ("There's no handling for what happens if the email service is down")

### 3.4 Where This Lives

Briefly note which part of the codebase handles this, in case someone technical wants to follow up:

> This is handled in the authentication module. A developer looking into this would check the `src/auth/` directory.

## Phase 4 — Format Output

```
## Question
[The original question]

## Answer
[Short answer — 1-2 sentences]

## Details
[Plain-English explanation of how it works, if needed]

## Things to Note
- [Any caveats, limitations, or conditions]

## Where This Lives
[Brief pointer to the relevant part of the codebase for technical follow-up]
```

## Phase 5 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Create a short slug from the question (e.g., `dark-mode-support`)
4. Save to: `reports/codebase-qa-<slug>-<DATE>.md`
   - Include YAML front-matter: `date`, `question`, `short_answer`
5. Print the file path so the user knows where to find it
