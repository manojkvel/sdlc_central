# Borrow list — patterns to absorb from AI-DLC into SDLC-Central

> Concrete PR plan to bring AI-DLC's strongest execution patterns into SDLC-Central without losing the multi-agent scope. Five PRs, ordered by cost/benefit. Each PR is self-contained and revertable.

## Source

`TheBushidoCollective/ai-dlc` (Apache-2.0, 2026-04-06 repo, Claude Code plugin, 2 weeks old). Architectural wins worth stealing: filesystem state model, DAG via frontmatter, hard-blocking quality gates, hats as per-task mental models, MCP visual review.

## Scoping principles

1. **Agent-agnostic first.** If a pattern can live in `skills/` or `pipelines/`, it goes there — usable by all 9 agents.
2. **Claude-Code-specific goes in `adapters/claude-code/`.** Stop hooks, plugin manifests, MCP servers — these don't port to Cursor/Copilot, so scope them to the adapter.
3. **Don't rebuild what you have.** SDLC-Central already has `quality-gate`, `spec-evolve`, `feedback-loop`, `parallel-kanban`. Extend them; don't clone AI-DLC's skill names.
4. **One pattern per PR.** No mega-PRs. Each PR ships independently and is revertable.

## PR order (cost/benefit)

| # | Pattern | Scope | Effort | Value | Depends on |
|---|---|---|---|---|---|
| 1 | Filesystem state model | universal | S | **high** | — |
| 2 | DAG via `depends_on` frontmatter | universal | M | **high** | PR 1 |
| 3 | Hard-blocking quality gate hook | claude-code adapter | M | high | PR 1 |
| 4 | Hats (per-task mental models) | universal + claude-code hook | S–M | medium | — |
| 5 | MCP visual review server | claude-code adapter | L | medium | PR 1 |

Ship PR 1–2 first (foundational). PR 3–4 in parallel. PR 5 optional / deferred.

---

## PR #1 — Filesystem state model (`skills/_lib/state.sh`)

### Goal
Central, atomic, filesystem-backed state for any skill that tracks iteration, blockers, or in-progress work. Replaces the ad-hoc `.md` writes scattered across `spec-evolve`, `feedback-loop`, `parallel-kanban`, `incident-triager`.

### What to borrow from AI-DLC
`plugin/lib/state.sh`'s `dlc_state_save` pattern: write to `tmp` + `mv` for atomicity; scoped per-feature dir; standard files (`iteration.json`, `blockers.md`, scratchpads).

### Files to add
- `skills/_lib/state.sh` — helpers: `sc_state_save`, `sc_state_load`, `sc_state_append`, `sc_find_active_spec`.
- `skills/_lib/state.md` — convention doc: state dir layout `docs/specs/<slug>/state/{iteration.json,blockers.md,scratchpad.md}`, JSON schemas.

### Files to modify
- `skills/spec-evolve/prompt.md` — call `sc_state_save` when writing reprocess-manifest.
- `skills/feedback-loop/prompt.md` — write pipeline-calibration.json via the lib.
- `skills/parallel-kanban/prompt.md` (new from three-skills-plan) — use state lib for board snapshots.
- `skills/incident-triager/prompt.md` — blockers.md via state lib.

### Roleplay (smoke test)
1. Dev runs `/spec-evolve --section AC-7 --input "use docker not vm"` mid-sprint.
2. Skill writes `docs/specs/001-nutrition-app/state/iteration.json` via `sc_state_save`. If process is killed mid-write, the tmp file stays; real file is untouched.
3. Next skill run calls `sc_state_load` → gets the last committed iteration, not a half-written file.
4. `parallel-kanban` reads the same state file, renders current status.

### Token budget
**Net-negative cost.** Replaces per-skill YAML/JSON parsing prompts with a 20-line shell include. Each affected skill saves ~500 output tokens (no more "write this JSON carefully"). First skill using it pays ~200 input tokens for the convention doc; subsequent skills reuse cache.

### Risks / rollback
- Risk: concurrent writes from parallel agents. **Mitigation:** tmp+mv is atomic at the FS level; no lock file needed for single-writer-per-spec model. Document that assumption.
- Rollback: delete `skills/_lib/state.sh`; the affected skills have fallback markdown-write paths.

---

## PR #2 — DAG via `depends_on` frontmatter in task files

### Goal
Task files declare dependencies in YAML frontmatter; a DAG engine computes ready-set and blocks waves. Replaces the current "linear pipeline chain" model for within-sprint task scheduling.

### What to borrow from AI-DLC
`plugin/shared/src/dag.ts` + `plugin/lib/dag.sh`: each unit has `depends_on: [unit-01, unit-02]`, engine computes topological order, Mermaid rendering for visualization.

### Files to add
- `skills/_lib/dag.sh` — `build_dag`, `ready_tasks`, `blocked_tasks`, `mermaid_from_dag`.
- `skills/task-dag-viz/` — new skill that reads `docs/specs/<slug>/tasks/*.md` frontmatter, emits Mermaid + ready/blocked report.

### Files to modify
- `skills/task-gen/prompt.md` — emit `depends_on:` in task frontmatter (from the three-skills-plan this was already planned; formalize the schema now).
- `skills/parallel-kanban/prompt.md` — read DAG instead of guessing parallelism from task text.
- `pipelines/_engine/` — add a DAG-aware wave scheduler step.

### Roleplay (smoke test)
1. `task-gen` outputs `docs/specs/001-nutrition-app/tasks/TASK-012-add-docker.md` with frontmatter `depends_on: [TASK-003]`.
2. `parallel-kanban` calls `ready_tasks` → TASK-012 shows as blocked (TASK-003 in progress).
3. When TASK-003 flips to `status: completed`, next kanban refresh unblocks TASK-012.
4. `task-dag-viz` renders the graph to `docs/specs/001-nutrition-app/dag.mmd` — PM views it in GitHub.

### Token budget
- **Input:** parsing frontmatter deterministically in shell, 0 LLM tokens.
- **Output:** `task-dag-viz` renders mermaid from parsed structure — ~1k output tokens one-shot, vs the current ~4k to re-reason over the task list.
- **Net:** ~60% reduction on any skill that currently re-derives task order from prose.

### Risks / rollback
- Risk: old task files without `depends_on` break the DAG. **Mitigation:** migration script sets `depends_on: []` defaults; tasks are independent unless declared.
- Rollback: DAG tools read frontmatter additively; skills still work if lib is removed (they just fall back to linear order).

---

## PR #3 — Hard-blocking quality-gate Stop hook (claude-code adapter only)

### Goal
Move the `quality-gate` skill from "LLM judge reads a checklist" to "shell hook that blocks the agent from stopping if `npm test` / `pytest` / `cargo test` fails." Stronger enforcement; zero-token cost per gate check.

### What to borrow from AI-DLC
`plugin/hooks/quality-gate.sh` + `plugin/hooks/hooks.json`: registers `Stop` and `SubagentStop` hooks, reads `quality_gates:` array from spec/unit frontmatter, runs each with 30s timeout, returns `{"decision":"block","reason":"..."}` if any fails.

### Files to add
- `adapters/claude-code/hooks/quality-gate.sh` — port of AI-DLC's script, adapted to SDLC-Central's spec layout.
- `adapters/claude-code/hooks/hooks.json` — registers Stop/SubagentStop hooks.
- `adapters/claude-code/templates/quality-gates.example.yaml` — sample gates per stack.

### Files to modify
- `adapters/claude-code/adapter.sh` — copy hooks into `~/.claude/hooks/` on install.
- `skills/quality-gate/prompt.md` — document the hook-enforced path; keep the LLM-judge path for agents that can't run hooks.
- `skills/spec-evolve/prompt.md` (and spec templates) — add `quality_gates:` frontmatter field with schema.

### Roleplay (smoke test)
1. Dev working on TASK-012. Spec has `quality_gates: [{name: tests, command: "cd src && npm test"}]` in frontmatter.
2. Claude implements, writes tests, tries to Stop.
3. Stop hook fires, runs `npm test` — 1 failing test.
4. Hook returns `{"decision":"block","reason":"npm test failed: auth.test.ts line 42"}`.
5. Claude cannot exit; must fix the test. Dev didn't have to notice.

### Token budget
- **Per-gate cost: 0 LLM tokens** (it's a subprocess).
- Replaces the current `quality-gate` skill invocation (~3k input + 1k output per check).
- **Net:** saves ~4k tokens per Stop event for Claude Code users; other agents keep the LLM path.

### Risks / rollback
- Risk: slow test suites (>30s) always fail. **Mitigation:** per-gate `timeout` field; docs recommend smoke subset for Stop hooks, full suite in CI.
- Risk: hook is Claude Code specific — other agents fall back to LLM judge. **Mitigation:** document this explicitly; the `quality-gate` skill's prompt chooses path based on env detection.
- Rollback: remove hook files; LLM path still works for everyone.

---

## PR #4 — Hats (per-task mental models)

### Goal
Lightweight per-task "mindset" prompts — `builder`, `reviewer`, `red-team`, `designer`, `refactorer` — injected for the duration of a specific task, not a permanent role. Complements (doesn't replace) SDLC-Central's 8 role templates.

### What to borrow from AI-DLC
`plugin/hats/*.md` — 16 single-purpose prompt files with frontmatter; `plugin/lib/hat.sh`'s `load_hat_instructions` (built-in + project override at `.sdlc/hats/<hat>.md` appended as "Project Augmentation"). Injected via subagent PreToolUse hook.

### Why this doesn't duplicate role templates
Role templates = *who the user is* (PO vs Dev vs QA), installed once. Hats = *what mindset to adopt for this task* (build vs adversarially review vs visually design), activated per invocation. A Dev wearing the Red Team hat is different from just being a Dev.

### Files to add
- `skills/_hats/{builder,reviewer,red-team,refactorer,designer,test-writer,observer,hypothesizer}.md` — 8 starter hats.
- `skills/_hats/README.md` — convention + project override path.
- `adapters/claude-code/hooks/hat-inject.sh` — PreToolUse hook that appends hat content to subagent invocations (optional; without it, users reference hats via `/hat:<name>` style slash commands or direct file paths).

### Files to modify
- `skills/pr-review/prompt.md` — suggest wearing `reviewer` or `red-team` hat.
- `skills/task-briefing-gen/prompt.md` (from three-skills-plan) — include a "suggested hat" field.

### Roleplay (smoke test)
1. Dev receives briefing for TASK-015: "Harden login endpoint."
2. Briefing suggests `red-team` hat.
3. Dev runs `/task-implementer --hat red-team`. The hat file gets prepended; agent now enumerates attack surface, injection vectors, authZ bypass before writing code.
4. After implementation, switches to `reviewer` hat for self-review pass.

### Token budget
- Each hat: ~400–600 input tokens (small, cacheable).
- Avoids bloating role templates with every mindset variant (current role templates would otherwise grow 10×).
- **Net:** neutral to slight positive — saves role-template bloat.

### Risks / rollback
- Risk: too many hats → decision fatigue. **Mitigation:** ship 8 starters; let users add more. Don't pre-enumerate 50.
- Rollback: delete `skills/_hats/`; no pipeline depends on them (PR #4 doesn't hard-wire hats into any pipeline).

---

## PR #5 — MCP visual review server (claude-code adapter, deferred)

### Goal
Interactive visual review gates — mount an MCP server that exposes `open_review`, `get_review_status`, `ask_visual_question`. User clicks through design direction, UI mocks, PR screenshots in a browser instead of reading markdown.

### What to borrow from AI-DLC
`plugin/mcp-server/src/{server.ts,http.ts,sessions.ts,archetypes.ts}` — TS/Bun MCP server with embedded HTTP for form-based visual questions; design-direction archetype picker.

### Files to add
- `adapters/claude-code/mcp-server/` — new TS workspace (review-only scope; don't port AI-DLC's whole thing).
- `adapters/claude-code/.mcp.json` — registers `sdlc-review` server.

### Files to modify
- `skills/design-review/prompt.md` — offer MCP path when available.
- `skills/pr-review/prompt.md` — optional visual-PR path.

### Why deferred
Large (TS/Bun workspace), medium value (visual reviews only help UI-heavy work), and Claude-Code-only. Do it after PR 1–4 prove out.

### Token budget
- **Not applicable** — MCP server is code, not LLM calls. Per-interaction cost = HTTP request.
- Visual reviews replace 3–5k-token markdown-rendering design docs with a URL. **Big savings** for UI-heavy features; negligible for backend work.

### Risks / rollback
- Risk: MCP server is a new runtime dependency (Bun). **Mitigation:** optional adapter; falls back to markdown review.
- Rollback: delete `adapters/claude-code/mcp-server/`.

---

## Timeline & sequencing

```
Week 1   PR #1 state lib ──┐
                           ├── PR #2 DAG frontmatter
Week 2   PR #3 Stop hook ──┘
         PR #4 hats (parallel)
Week 3   stabilize, measure token savings, decide PR #5
Week 4+  PR #5 MCP server (optional)
```

PR #1 must merge first — PR #2, #3 write state via the lib. PR #4 is independent. PR #5 depends on no one.

## Aggregate token-budget estimate (sprint-scale impact)

| Skill usage | Before | After PR 1–3 | Saving |
|---|---|---|---|
| Quality-gate check × 20/sprint | 80k | ~0 (hooks) | 80k |
| Task wave scheduling × 5 | 20k | ~5k (DAG lib) | 15k |
| State reads/writes × 40 | 24k | ~8k (lib, cacheable) | 16k |
| **Sprint total** | **~124k** | **~13k** | **~89% on these paths** |

(These are the paths that change. Overall sprint token cost is dominated by code-gen, which is untouched.)

## What NOT to borrow

- **AI-DLC's 16-hat taxonomy wholesale.** Too many; ship 8, grow from real usage.
- **Their `autopilot` mode.** Conflicts with SDLC-Central's HITL gates for compliance/migration.
- **The full Bushido workflow.yml (6 workflows).** You already have 30 pipelines; adding 6 more creates naming chaos.
- **Their dashboard TS CLI.** Nice but large; `parallel-kanban` renders enough for now.

## Non-goals for this set of PRs

- Not porting AI-DLC's skill names (`/ai-dlc:elaborate` → don't map to yours).
- Not making SDLC-Central Claude-Code-only. PR #3 and PR #5 are adapter-scoped; others stay universal.
- Not breaking backward compatibility with existing skills. All PRs are additive + optional.

## Bottom line

PRs 1–3 give you AI-DLC's execution discipline (state, DAG, hard gates) in ~2 weeks without losing multi-agent scope. PR 4 is a nice ergonomic add. PR 5 waits for proof that UI-heavy work justifies the MCP overhead.

The patterns worth stealing are the plumbing (atomic state, DAG, Stop hooks), not the shape of the framework. SDLC-Central's role/pipeline/multi-agent design is already broader than AI-DLC's feature-cycle focus — don't fold into them, absorb what they do better.
