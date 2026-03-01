
# Progress Summary

Generate a plain-English progress report from git activity, open PRs, and spec status. Designed for stakeholder meetings, status emails, and sprint check-ins — no technical jargon, just "what's done, what's in progress, what's blocked."

## CRITICAL RULES

1. **Write for the person asking "how's the project going?"** No commit hashes, branch names, or file paths in the output.
2. **Be honest about progress.** Don't inflate velocity or hide blockers. Stakeholders prefer early warnings over late surprises.
3. **Read-only.** This skill only reads git state and reports — it never modifies anything.

---

## Phase 1 — Determine the Time Window

From `$ARGUMENTS`:

| Argument | Time Window |
|----------|------------|
| `daily` | Last 24 hours |
| `weekly` | Last 7 days |
| `sprint` | Last 14 days (or since last tag) |
| `--since <date>` | Since the provided date |
| No arguments | Default to `weekly` |

## Phase 2 — Gather Data

### 2.1 Git Activity

Run these commands to gather raw data:
- `git log --since="<window>" --oneline --no-merges` — all commits in the window
- `git log --since="<window>" --format="%an" --no-merges | sort | uniq -c | sort -rn` — who contributed
- `git shortlog --since="<window>" -sn --no-merges` — commit counts by author
- `git diff --stat HEAD~<N>` — files changed (approximate scope of changes)

### 2.2 Recent Tags/Releases

- `git tag --sort=-creatordate | head -5` — recent releases
- Check if any releases happened within the time window

### 2.3 Spec and Report Status

Scan for existing SDLC artifacts:
- `reports/` directory — recent reports (reviews, audits, etc.)
- `specs/` directory — spec files and their status
- Look for any `TODO`, `FIXME`, or `BLOCKED` markers in recent changes

### 2.4 Open Work

- Check for uncommitted changes: `git status --short`
- Look for work-in-progress indicators (WIP commits, draft files)

## Phase 3 — Analyze and Categorize

### 3.1 Completed Work

Group finished work into user-facing categories:
- **Features completed** — new capabilities that are done
- **Bugs fixed** — problems that have been resolved
- **Improvements** — existing features made better

Translate each item from technical commit messages to plain language (same rules as `changelog-plain`).

### 3.2 In Progress

Identify work that's started but not finished:
- Branches with recent activity but no merge
- Specs in draft or review state
- Recent commits that indicate ongoing work

### 3.3 Blockers and Risks

Look for signals of blocked or at-risk work:
- Stale branches (no commits in 3+ days despite being recent)
- Failed CI signals in reports
- `BLOCKED` or `FIXME` markers
- Specs with unresolved review findings

### 3.4 Velocity Snapshot

Simple metrics:
- Number of commits in the window
- Number of unique contributors
- Rough scope (files changed)

## Phase 4 — Format Output

### Progress Report — [Date Range]

**Overview:** [One paragraph summary — what was the focus this period, what got done, any concerns?]

#### Completed
- [Plain-English description of each completed item]

#### In Progress
- [What's being worked on and approximate status]

#### Blocked / At Risk
- [Any blockers, risks, or stalled work — with enough context for a stakeholder to ask the right follow-up questions]

#### By the Numbers
| Metric | Value |
|--------|-------|
| Changes shipped | [count] |
| Contributors | [count] |
| Bugs fixed | [count] |
| Open risks | [count] |

#### Coming Up Next
[If there are specs or plans queued, briefly mention what's expected next]

---

*Report generated from git activity [start date] to [end date].*

## Phase 5 — Save Report

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Save to: `reports/progress-summary-<DATE>.md`
   - Include YAML front-matter: `date`, `window`, `commits_count`, `contributors_count`
4. Print the file path so the user knows where to find it
