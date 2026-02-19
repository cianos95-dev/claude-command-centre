---
name: insights-pipeline
description: |
  Guide for archiving Claude Code Insights HTML reports as structured Markdown and
  extracting actionable patterns to improve CLAUDE.md and workflows.
  Use when archiving an Insights report, reviewing past archives, extracting CLAUDE.md
  improvement candidates, or comparing trends across reports.
  Trigger with phrases like "archive insights report", "review insights", "insights trend",
  "what did insights suggest", "insights to CLAUDE.md".
---

# Insights Pipeline

Archive Claude Code Insights reports as structured Markdown and extract patterns to improve your CLAUDE.md and workflows.

This is a methodology skill — it guides the agent through archiving and analysis using standard file tools (Read, Write, Edit, Grep, Glob). The pipeline follows a graduated approach, scaling storage and analysis as the archive grows.

> **Audit note:** Revised per CIA-522 audit findings to reflect the graduated 3-phase approach. SQLite is a future migration target, not an immediate requirement.

## Graduated Storage Phases

The insights pipeline scales with your archive size. Start simple, add structure only when the data justifies it.

### Phase 0 — Flat Markdown (now)

**Active from report 1.** This is the current implementation.

- **Storage:** Flat markdown files in `~/.claude/insights/YYYY-MM-DD.md`
- **Analysis:** Period-over-period deltas computed by reading and comparing archived markdown files directly
- **Index:** None. The agent reads all archives via Glob + Read.
- **Tooling:** Standard file tools only (Read, Write, Edit, Grep, Glob)

No runtime, no database, no external dependencies.

### Phase 1 — Pattern Index (report 10+)

**Activates when 10+ archived reports exist.** Adds a lightweight summary index.

- **Storage:** Same flat markdown files
- **New artifact:** `~/.claude/insights/patterns.json` — a summary file tracking recurring patterns across reports
- **Analysis:** Exact-match counting of friction points, CLAUDE.md suggestions, and feature recommendations across archived reports
- **Migration:** The agent generates `patterns.json` by reading all existing archives; no data migration needed

### Phase 2 — SQLite Migration (report 50+)

**Future target when 50+ archived reports exist.** Full structured storage.

- **Storage:** `~/.claude/insights/insights.db` (SQLite)
- **Analysis:** SQL queries for trend analysis, cross-report correlation, and aggregation
- **Migration:** One-time import from flat markdown archives into SQLite tables
- **Tooling:** Requires SQLite CLI or library access

Phase 2 is a future migration path, not a current requirement. Do not introduce SQLite dependencies until the archive reaches sufficient scale to justify the complexity.

## What This Skill Does

1. **Archives** HTML Insights reports to `~/.claude/insights/YYYY-MM-DD.md` as structured Markdown.
2. **Extracts** actionable patterns: friction points, CLAUDE.md suggestions, feature recommendations, workflow patterns.
3. **Compares** current report against prior archived reports to identify improvement trends (period-over-period deltas).

## Archive Format

Each archived report follows this structure:

```markdown
---
source: Claude Code Insights (Anthropic)
period: YYYY-MM-DD to YYYY-MM-DD
messages: N
sessions: N
archived: YYYY-MM-DD
original: [path to source file]
version: 1
---

# Claude Code Insights — [Period]

## At a Glance
## Project Areas
## Usage Stats
## Big Wins
## Friction Points
## CLAUDE.md Suggestions
## Features Recommended
## Patterns to Adopt
## On the Horizon
## Outcomes
## Satisfaction
```

## Storage

- **Location:** `~/.claude/insights/`
- **Naming:** `YYYY-MM-DD.md` where the date is the end date of the report period.
- **Idempotent:** Re-running on the same report produces the same output. Do not overwrite an existing archive unless the user explicitly requests it.

## Extraction Rules

When converting HTML reports to Markdown:

1. **Strip all CSS and JavaScript.** Extract text content only.
2. **Preserve data fidelity.** Every number, percentage, and metric from the original appears in the archive.
3. **Use tables for structured data.** Charts become tables. Bar charts become `| Label | Value |` tables.
4. **Keep code suggestions verbatim.** CLAUDE.md additions and prompt templates are preserved exactly.
5. **Summarize narratives.** Multi-paragraph prose sections become 2-3 sentence summaries.

## Pattern Extraction

After archiving, extract these actionable outputs:

### CLAUDE.md Candidates

- Any suggestion from the report's "CLAUDE.md Suggestions" section.
- Any friction pattern that occurred 3+ times (indicates a missing rule).
- Any environment assumption error (indicates missing context in CLAUDE.md).

### Skill Candidates

- Any repeated multi-step workflow mentioned in "Features Recommended" or "Patterns to Adopt".
- Any workflow the user performs manually that could be codified as a skill.

### Trend Comparison

When multiple archived reports exist in `~/.claude/insights/`, compare them by reading each archive's frontmatter and section content:

- Are wrong-approach friction counts decreasing?
- Is the ratio of fully-achieved outcomes improving?
- Which CLAUDE.md suggestions were adopted and did friction decrease afterward?

In Phase 0, this comparison is done by the agent reading the archived Markdown files directly — no index or database is involved. In Phase 1+, the agent can consult `patterns.json` for precomputed counts.

## Prerequisites

- Claude Code Insights report (HTML format from Anthropic).
- Write access to `~/.claude/insights/`.

## Related

- `/ccc:insights` command — runs the archive-and-learn cycle with `--archive`, `--review`, `--trend`, and `--suggest` modes.
- CLAUDE.md — destination for extracted rules.
