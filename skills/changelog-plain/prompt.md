
# Plain-English Changelog

Translate technical changelogs, git history, or release notes into clear, jargon-free language that non-technical stakeholders can understand. Turns "refactored auth middleware to use JWT rotation" into "Login sessions are now more secure and refresh automatically."

## CRITICAL RULES

1. **Zero jargon in output.** No file names, function names, technical terms, or acronyms without explanation. Write for someone who has never seen code.
2. **Focus on user impact.** Every change should answer: "What does this mean for the person using the product?"
3. **Honest about what you don't know.** If a commit message is too vague to determine user impact, say so rather than guessing.

---

## Phase 1 — Gather the Raw Changelog

Determine the source from `$ARGUMENTS`:

1. **File path** — if a path to a release notes or changelog file is provided, read it
2. **Version range** — if `--from <tag>` is provided, run `git log <tag>..HEAD --oneline` to get commits since that version
3. **`latest`** — find the most recent git tag via `git describe --tags --abbrev=0`, then get commits since that tag
4. **`daily`** — get today's commits: `git log --since="24 hours ago" --oneline`
5. **`weekly`** — get this week's commits: `git log --since="7 days ago" --oneline`
6. **No arguments** — default to `latest`

If the raw source is a release-notes file (from the `release-notes` skill), use it directly. Otherwise, gather git log with `git log <range> --format="%h %s" --no-merges`.

## Phase 2 — Categorize Changes

Group every change into one of these user-facing categories:

| Category | Icon | What belongs here |
|----------|------|-------------------|
| New Features | **New** | Entirely new capabilities users can now do |
| Improvements | **Better** | Existing features that now work better, faster, or more smoothly |
| Bug Fixes | **Fixed** | Things that were broken and are now working correctly |
| Security | **Security** | Changes that make the product safer (without revealing specifics that could be exploited) |
| Behind the Scenes | **Internal** | Technical changes with no direct user impact — keep this section brief |

Drop any changes that are purely internal with zero user-facing relevance (dependency bumps, CI config, linting fixes) — unless the user explicitly asks for everything.

## Phase 3 — Translate Each Change

For each change, apply this translation process:

### 3.1 Identify the User Impact

Read the commit message and, if needed, the diff (`git show <hash> --stat`) to understand what actually changed. Ask yourself:
- What could the user do before?
- What can the user do now?
- What was broken before that works now?

### 3.2 Write in Plain Language

**Bad (technical):**
> Added pagination to GET /api/users endpoint with cursor-based offset

**Good (plain):**
> The user list now loads faster and scrolls smoothly even with thousands of users

**Bad (technical):**
> Fixed race condition in checkout mutex lock

**Good (plain):**
> Fixed a bug where two people buying the last item could both be charged

### 3.3 Rules for Translation

- Use active voice: "You can now..." not "A feature has been added that..."
- Name the feature, not the file: "Search" not "SearchController"
- Describe the outcome, not the mechanism: "Faster page loads" not "Added Redis caching layer"
- If a change only affects specific users, say so: "For admin users: ..."
- Keep each item to 1-2 sentences maximum

## Phase 4 — Format Output

### What Changed — [Version or Date Range]

**New**
- [plain-English description of each new feature]

**Better**
- [plain-English description of each improvement]

**Fixed**
- [plain-English description of each bug fix]

**Security**
- [plain-English description, without revealing vulnerability details]

**Internal** *(optional — only if relevant changes exist)*
- [brief, 1-line summaries of significant internal changes]

---

**Summary:** [One sentence summarizing the overall release theme — e.g., "This release focuses on making search faster and fixing checkout reliability."]

## Phase 5 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Save to: `reports/changelog-plain-<DATE>.md`
   - Include YAML front-matter: `date`, `source`, `changes_count`, `categories`
4. Print the file path so the user knows where to find it
