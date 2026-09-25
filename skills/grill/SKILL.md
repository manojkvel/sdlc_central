---
name: grill
description: Interview the requester before the spec is written until nothing is left assumed: ask every question that is ready in one numbered round, each with a recommended answer, look up facts yourself, and record each answer as a decision (D id) in CONTEXT.md and decisions.md. Use before spec, or when someone says 'grill me' or 'ask me questions first'.
argument-hint: "[.track/phases/NN-slug] (defaults to the current phase)"
allowed-tools: Read, Write, Edit, Grep, Glob, Task, Agent, Bash(git log, git diff, ls, find, date, shasum)
---
# Grill

Before a spec is written, find every decision the work depends on and get the human to make it.
You act as the **aidlc-product-strategist**. Use **aidlc-domain-expert** (a subagent on Claude Code)
to look up facts in the code, docs and wiki. The human only answers what only a human can decide.

## AIDLC contract

- Track root: `track_root` in the agent's `sdlc-central.json`; default `.track/`. Phase: `CURRENT_PHASE`.
- Read only the `## AIDLC_RESUME` block of `state.md` first. If `BLOCKED_GATE` is not `none`, stop and
  end with `## AIDLC GATE BLOCKED`.
- After writing, append one lineage line per artifact:
  `<ISO time> | - | stage.grilled: <n> decisions | <path> | sha256:<hash> | model=<model id> | sdlc=<version>`
- Never write `human-decisions.md`. Grill answers are design decisions, not gate approvals.

## 1. Build the question tree

Read `unit.yaml` (its `request`), `CONTEXT.md` if it exists, and only the code the request touches.
List every open point: scope edges, behaviour on errors and empty input, data ownership, users and
permissions, performance and limits, rollout and rollback, what is explicitly out of scope.
Order them so a question comes after the questions it depends on.

**Facts are your job.** If the answer is in the code, config, docs or wiki, look it up and record it
under `## Facts`. Never ask the human something you can find.

## 2. Ask in rounds

Each round, ask **every** question whose prerequisites are already answered, numbered, in one
message. For each give your recommended answer and one line of why:

```text
Round 2 (4 questions). Reply with the numbers you disagree with; silence means you accept.
1. Should reset links expire? ➜ Recommend: yes, after 30 minutes (matches session policy in auth/config.ts).
2. ...
```

Accept short replies: "all fine", "2: 24 hours", "3 no". Then ask the next round. Stop when no
question is left. Do not end the turn with a question the tree does not need.

## 3. Record

When the tree is empty, read back the decisions in a short list and ask: "Anything I assumed that
you did not decide?" Only when the human confirms:

1. Append each decision to `<track root>/decisions.md` with the next free `D-NNN` id, the phase, the
   question, the answer and who answered.
2. Write or update `<phase>/CONTEXT.md` with these sections, in this order:

```markdown
## Request
## Facts
- <fact> (source: <path or doc>)
## Decisions
- D-012: reset links expire after 30 minutes (answered by <name>)
## Assumptions
- none
## Open questions
- none
## GRILL COMPLETE
```

Every decision under `## Decisions` must be carried into `PLAN.md` later: the traceability check
fails with T05 if one is missing. Anything left under `## Open questions` blocks source writes (T06).

## Rules

- One round per message; never one question per message when several are ready.
- Always give a recommended answer. The human edits a proposal faster than they write one.
- Never ask for facts. Never invent a decision the human did not make; list it as an open question.
- End with `## GRILL COMPLETE`, or with the next round of questions if the tree is not empty.
