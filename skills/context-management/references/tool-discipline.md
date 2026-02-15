# Tool-Specific Output Discipline

Consolidated rules for controlling output from the most common sources of context bloat: project trackers, web scraping tools, and research library APIs.

## Linear Output Discipline

The project tracker is the most common source of context bloat. These rules prevent it:

- **NEVER** `list_issues` without explicit `limit` parameter. Default returns 100KB+ JSON.
- **NEVER** `list_issues` in the main context. Always delegate to a subagent returning a markdown table.
- **Single `get_issue`** is OK directly. 2+ issues must go through a subagent.
- **Zotero `get_collection_items`**: Same rules as `list_issues`.

### Subagent Return Format for Issues

The subagent should return a compact markdown table:

```markdown
| ID | Title | Status | Assignee | Priority |
|----|-------|--------|----------|----------|
| CIA-101 | Fix login flow | In Progress | Claude | High |
| CIA-102 | Update API docs | Todo | Unassigned | Medium |
```

No descriptions, no full metadata dumps, no nested JSON. The main context uses this table for decision-making and can call `get_issue` on specific IDs if deeper detail is needed.

## Linear Query Specificity

- **ALWAYS** use `limit: 10` (or less) on `list_issues` calls. There is no valid reason to fetch more than 10 issues at once.
- **NEVER** run `list_issues` in the main context. Always delegate to a subagent that returns a markdown table.
- **Single `get_issue`** is OK directly in the main context. It returns a predictable ~500 bytes to 1KB.
- **2+ issues** must go through a subagent, even if you know the exact IDs. The subagent fetches and returns a summary table.
- **Zotero `get_collection_items`:** Same rules as `list_issues`. Collections can contain thousands of items.

## Firecrawl Discipline

Web scraping tools produce the largest raw outputs. Control them:

- **Prefer `WebFetch`** for single-page reads. Only use Firecrawl for batch/search/extract/map operations.
- **Always set:** `onlyMainContent: true`, `formats: ["markdown"]`, `removeBase64Images: true`
- **Never** return raw scraped markdown to main context. Summarize in 2-3 bullets or write to file.

## MCP-First Principle

When choosing between an MCP tool and a custom script for the same operation:

- **Prefer MCP.** MCPs account for only ~6.5% of session tool calls (evidence from Feb 1 infrastructure audit). They are lightweight, not overhead.
- **Scripts only** when no MCP exists or the MCP can't reach the operation.
- **Never create new scripts** if an MCP can accomplish the task.
