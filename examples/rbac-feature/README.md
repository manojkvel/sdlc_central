# RBAC Feature — Example Artifacts

These are reference outputs from SDLC Central skills, showing what each skill produces for a realistic feature: adding Role-Based Access Control (RBAC) to a web application.

## How They Chain Together

The artifacts follow the spec-driven pipeline:

1. **spec.md** — `/spec-gen` defines *what* to build (problem, goals, acceptance criteria)
2. **gate-pass.md** — `/quality-gate spec-to-plan` validates the spec before planning proceeds
3. **plan.md** — `/plan-gen` defines *how* to build it (architecture, phases, risks)
4. **tasks.md** — `/task-gen` breaks the plan into 12 atomic, assignable tasks
5. **review.md** — `/review` evaluates the implemented code against the spec
6. **gate-fail.md** — `/quality-gate spec-to-plan` shows what a *failed* gate looks like and how recovery routing works

## How to Use These

- **Learn the format.** Read each file to understand what a well-formed skill output looks like.
- **Template reference.** Copy and adapt the structure when writing your own specs, plans, or tasks.
- **Test your install.** After installing SDLC Central, run the skills against your own feature and compare your output to these examples.

## Files

| File | Skill | Description |
|------|-------|-------------|
| `spec.md` | `/spec-gen` | Complete specification with acceptance criteria and business rules |
| `plan.md` | `/plan-gen` | Implementation plan with 5 phases, architecture decisions, and risks |
| `tasks.md` | `/task-gen` | 12 tasks across 4 waves with dependency graph and traceability |
| `review.md` | `/review` | Code review report with findings and AC coverage |
| `gate-pass.md` | `/quality-gate` | Passing gate report (all 7 criteria met) |
| `gate-fail.md` | `/quality-gate` | Failing gate report with recovery routing |
