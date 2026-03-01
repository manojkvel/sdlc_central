
# Demo Prep

Generate a sprint demo walkthrough script from recent changes. Lists what's new, what to show, a suggested click path, and known limitations to avoid during the demo. Sprint review prep in 30 seconds.

## CRITICAL RULES

1. **Write for the person giving the demo**, not the developer who built it. Assume the presenter may not know the code.
2. **Highlight what's visually demonstrable.** Backend-only changes get a mention but not a walkthrough step.
3. **Flag landmines.** Known bugs, incomplete features, or unreliable test data that could embarrass the presenter — call them out early.

---

## Phase 1 — Determine the Demo Scope

From `$ARGUMENTS`:

| Argument | Scope |
|----------|-------|
| `sprint` | Last 14 days of changes (default) |
| `--since <date>` | Changes since a specific date |
| Path to spec | Changes related to a specific feature spec |
| No arguments | Default to `sprint` |

## Phase 2 — Gather What Changed

### 2.1 Collect Recent Changes

- `git log --since="<window>" --oneline --no-merges` — all commits
- `git log --since="<window>" --format="%s" --no-merges` — commit messages only
- `git diff --stat <baseline>..HEAD` — scope of file changes

### 2.2 Identify User-Facing Changes

Categorize each change:

| Type | Demoable? | Example |
|------|-----------|---------|
| New UI feature | Yes | New settings page, new button, new form |
| UI improvement | Yes | Faster loading, redesigned layout, new animation |
| Bug fix (visible) | Maybe | "This used to crash, now it works" |
| API change | No | New endpoint — mention but don't demo |
| Backend logic | No | Performance improvement — mention as "faster" |
| Infrastructure | No | Skip entirely unless user-relevant |

### 2.3 Check for Landmines

Scan for potential demo failures:
- `git log --since="<window>" --grep="WIP\|TODO\|FIXME\|HACK\|BROKEN" --oneline` — incomplete work
- Recent reports with `CRITICAL` or `HIGH` findings
- Known test failures in `reports/` directory
- Hardcoded test data or placeholder content that could confuse an audience

## Phase 3 — Build the Demo Script

### 3.1 Opening

Write a 2-3 sentence intro summarizing the sprint theme:

> "This sprint we focused on improving the onboarding experience and fixing checkout reliability. Three new features are ready to show."

### 3.2 Demo Walkthrough

For each demoable change, create a step:

```
### [Feature Name]
**What's new:** [1 sentence — what it does]
**How to show it:**
1. [Go to specific page/URL]
2. [Do specific action]
3. [Point out the result]
**Talking point:** [What to say while showing it — the "why" behind the feature]
**Avoid:** [Any known issues or broken paths to steer away from]
```

Order the walkthrough by impact — most impressive changes first.

### 3.3 Mention-Only Items

For non-demoable changes, write brief mention items:

> "Behind the scenes, we also improved API response times by about 40% and fixed a security issue with session handling."

### 3.4 Known Limitations

List anything the audience might ask about that isn't ready:

> **Not ready yet:**
> - Dark mode toggle is visible but doesn't persist across sessions (fix coming next sprint)
> - Export feature works for CSV only — PDF export is in progress

## Phase 4 — Format Output

### Sprint Demo Script — [Date]

**Duration:** ~[estimated minutes] minutes
**Sprint theme:** [one sentence]

#### Opening (30 seconds)
[Opening paragraph to read or paraphrase]

#### Demo Walkthrough

[Ordered walkthrough steps — see 3.2]

#### Also Shipped (30 seconds)
[Mention-only items — see 3.3]

#### Not Ready Yet
[Known limitations — see 3.4]

#### Q&A Prep
[2-3 likely questions and suggested answers based on what changed]

---

*Based on [N] changes from [start date] to [end date].*

## Phase 5 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Save to: `reports/demo-prep-<DATE>.md`
   - Include YAML front-matter: `date`, `window`, `demo_items_count`, `estimated_duration`
4. Print the file path so the user knows where to find it
