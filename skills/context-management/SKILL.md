---
name: context-window-management
description: |
  Context window management strategies for multi-tool AI agents. Covers a 3-tier delegation model for controlling what enters the main conversation, context budget thresholds, subagent return discipline, and model mixing recommendations. Prevents context exhaustion during complex sessions.
  Use when planning subagent delegation, managing long sessions, deciding what to delegate vs handle directly, or choosing model tiers for subtasks.
  Trigger with phrases like "context is getting long", "should I delegate this", "subagent return format", "model mixing strategy", "context budget", "session splitting", "when to use haiku vs opus".
---

# Context Window Management

The context window is a finite, non-renewable resource within a session. Every token consumed by tool output, file content, or verbose responses reduces the agent's capacity for reasoning about the actual task. Disciplined context management is the difference between completing a complex task in one session and hitting compaction mid-flight.

## Core Principle

**Never let raw tool output flow into the main conversation when a summary will do.** The main context is for reasoning, planning, and communicating with the human. Data retrieval, scanning, and bulk operations belong in subagents that return concise summaries.

## 3-Tier Delegation Model

Every tool call should be evaluated against these tiers before execution:

### Tier 1: Always Delegate

Any tool call expected to return more than ~1KB of content must be delegated to a subagent. The subagent processes the output and returns a summary to the main conversation.

| Operation | Why Delegate |
|-----------|-------------|
| Web page scrapes | Pages routinely produce 10-50KB of markdown |
| File reads (large files) | Source files can be thousands of lines |
| PR diffs and file change lists | Diffs scale with change size |
| Bulk search results | Search returns multiple full-text matches |
| API responses with nested data | JSON payloads from list endpoints are large |
| Documentation lookups | Library docs pages are content-heavy |

**Rule of thumb:** If the tool is _reading_ something, it probably belongs in Tier 1.

### Tier 2: Delegate for Bulk

Single-item operations are fine in the main context. But when the operation fans out to multiple items, delegate.

| Operation | Direct OK | Delegate |
|-----------|-----------|----------|
| Issue lookup | Single issue by ID | List of 10+ issues |
| Project items | Single project metadata | All items in a project |
| Collection contents | Single item metadata | Full collection listing |
| Commit history | Latest commit | Full branch history |
| User lookups | Single user | Team member listing |

**Threshold:** If the list endpoint could return more than 10 items, delegate. When using list operations directly, always set explicit limits (e.g., `limit: 10`).

### Tier 3: Direct in Main Context

Small-output operations that return structured, predictable responses. These are safe to execute directly.

| Operation | Typical Output Size |
|-----------|-------------------|
| Create/update operations | Confirmation + ID (~100 bytes) |
| Metadata lookups | Single object (~200-500 bytes) |
| Single item get | One issue/page/document (~500 bytes-1KB) |
| Status checks | Boolean or enum (~50 bytes) |
| Label operations | Confirmation (~100 bytes) |

## Context Budget Protocol

Monitor context usage throughout the session and take action at defined thresholds:

### Under 50%: Normal Operation

Work freely. Use subagents for Tier 1 and Tier 2 operations. Keep tool output concise.

### 50% to 70%: Caution Zone

- **Warn the human.** Explicitly state context usage level and remaining capacity.
- **Consider checkpointing.** If the task has natural break points, suggest splitting the session.
- **Tighten delegation.** Move Tier 2 operations into subagents even for smaller counts.
- **Summarize aggressively.** Reduce inline explanations. Reference previous context instead of restating.

### Above 70%: Critical Zone

- **Insist on session split.** Do not continue hoping it will fit. Tell the human clearly that context is running low and a new session is needed.
- **Never silently let compaction happen.** Compaction loses context in unpredictable ways. A deliberate session split with a handoff note preserves continuity.
- **Write a handoff file** if splitting: summarize current state, remaining tasks, decisions made, and open questions. The next session starts by reading this file.

### Compaction Prevention

If compaction is imminent and cannot be avoided:
1. Write all in-progress work to files immediately
2. Summarize the session state in a handoff note
3. Tell the human what was saved and where
4. The next session reads the handoff to resume

## Subagent Return Discipline

Subagents must follow strict output constraints. Unbounded subagent returns defeat the purpose of delegation.

### Return Format Rules

- **Summary length:** 3-5 sentences, maximum 200 words
- **Structure:** Lead with the answer, follow with supporting details
- **Tables:** Use markdown tables for structured data (compact, scannable)
- **No raw content:** Never return raw scraped markdown, full file contents, or unprocessed API responses
- **Large content:** Write to a file and return the file path, not the content itself

### Example: Good vs. Bad Returns

**Bad return** (wastes context):
> Here is the full content of the page... [2000 words of scraped markdown]

**Good return** (preserves context):
> The documentation page covers 3 authentication methods: API key, OAuth 2.0, and JWT. API key is recommended for server-to-server. OAuth is required for user-facing flows. JWT is supported but deprecated. Key setup steps are in the "Getting Started" section. Full content written to `/tmp/auth-docs.md`.

**Bad return** (unstructured dump):
> Issue 1: Title is "Fix login bug", status is In Progress, assigned to... Issue 2: Title is "Update API docs"...

**Good return** (structured summary):
> Found 8 open issues in the project. 3 are In Progress, 5 are Todo. Summary:
>
> | ID | Title | Status | Assignee |
> |----|-------|--------|----------|
> | ~~PREFIX-101~~ | Fix login bug | In Progress | Agent |
> | ~~PREFIX-102~~ | Update API docs | Todo | Unassigned |
> | ... | ... | ... | ... |

## Model Mixing for Subagents

Not all subagent tasks require the same reasoning capability. Match the model tier to the cognitive demand of the subtask:

| Model Tier | Characteristics | Best For |
|------------|----------------|----------|
| **Fast/cheap** (e.g., haiku) | Lowest cost, highest throughput, adequate for structured tasks | File scanning, data retrieval, search queries, bulk reads, simple transformations |
| **Balanced** (e.g., sonnet) | Good quality-to-cost ratio, strong analysis | Code review synthesis, PR summaries, test analysis, documentation review, multi-source reconciliation |
| **Highest quality** (e.g., opus) | Maximum reasoning capability, highest cost | Critical implementation, architectural decisions, complex debugging, spec writing, adversarial review |

### Routing Guidelines

- **Default to fast/cheap** for read-only operations. Most data retrieval does not need deep reasoning.
- **Use balanced** when the subagent needs to synthesize, compare, or evaluate across multiple inputs.
- **Reserve highest quality** for tasks where incorrect output has high cost (wrong implementation, missed security issue, flawed architecture).
- **Never use highest quality for scanning.** It is wasteful and slower. A fast model reading 20 files and returning summaries is better than an expensive model reading 3 files deeply.

### Anti-Patterns

- Running all subagents at the highest quality tier (wasteful, slow)
- Running implementation subagents at the fast tier (too many errors, net negative)
- Not delegating at all (context exhaustion, compaction risk)
- Delegating everything (overhead of subagent coordination exceeds benefit for small tasks)

## Practical Integration

When working in a multi-tool environment with `~~project-tracker~~`, `~~version-control~~`, and web tools:

1. **Before any tool call,** classify it by tier
2. **Tier 1 calls** go to a subagent with explicit return format instructions
3. **Tier 2 calls** with small counts execute directly; large counts get delegated
4. **Tier 3 calls** execute directly in the main context
5. **After every major section of work,** mentally assess context usage
6. **At 50%,** tell the human and adjust strategy
7. **At 70%,** stop and plan a session split

This discipline compounds. A session that delegates properly can accomplish 3-5x more work than one that lets raw output flood the context window.

## Linear Output Discipline

The project tracker is the most common source of context bloat. These rules prevent it:

- **NEVER** `list_issues` without explicit `limit` parameter. Default returns 100KB+ JSON.
- **NEVER** `list_issues` in the main context. Always delegate to a subagent returning a markdown table.
- **Single `get_issue`** is OK directly. 2+ issues must go through a subagent.
- **Zotero `get_collection_items`**: Same rules as `list_issues`.
- **Subagent return format for issues:** Linked markdown table with Title, Status, Assignee, Priority columns.

## Firecrawl Discipline

Web scraping tools produce the largest raw outputs. Control them:

- **Prefer `WebFetch`** for single-page reads. Only use Firecrawl for batch/search/extract/map operations.
- **Always set:** `onlyMainContent: true`, `formats: ["markdown"]`, `removeBase64Images: true`
- **Never** return raw scraped markdown to main context. Summarize in 2-3 bullets or write to file.

## Pilot Batch Pattern

Before any operation involving 10+ items:

1. Run a **pilot batch of 3 items** first
2. Verify the output format, error handling, and item correctness
3. Only then proceed with the full batch

This pattern caught errors in URL formatting, sync storms, and MCP path issues before they affected 40+ items (EventKit Canvas Sync, Feb 8 2026).

## Session Exit Summary Tables

At the end of every working session, present structured summaries:

### Issues Table

```markdown
| Title | Status | Assignee | Milestone | Priority | Estimate | Blocking | Blocked By |
```

- Title = `[Issue title](linear-url)` (linked, opens in desktop app)
- Populate all fields from `get_issue(includeRelations: true)`. Use `—` for empty.
- Verify accuracy before presenting.

### Documents Table

```markdown
| Title | Project |
```

- Title = `[Doc title](linear-url)` (linked)
- Include only documents created or modified during the session.

## MCP-First Principle

When choosing between an MCP tool and a custom script for the same operation:

- **Prefer MCP.** MCPs account for only ~6.5% of session tool calls (evidence from Feb 1 infrastructure audit). They are lightweight, not overhead.
- **Scripts only** when no MCP exists or the MCP can't reach the operation.
- **Never create new scripts** if an MCP can accomplish the task.

## Authoring Session Detection

When a session involves editing more than 3 files within the plugin itself, it qualifies as an "authoring session." Authoring sessions consume context faster because both the source material and the edit targets compete for the same window.

### Rules for Authoring Sessions

- **Source files over 100 lines:** NEVER read in the main context. Delegate to a subagent.
- **Subagent workflow:** The subagent reads the source file plus the existing target file, then either writes edits directly or returns edit instructions to the main context.
- **Main context receives only:**
  - File paths and line counts
  - Issue IDs and their new status
  - Error summaries (if edits failed)
- **Plan file size limit:** Keep the plan itself under 100 lines. Supporting detail (appendices, reference tables, raw data) goes in separate files.

### Why This Matters

A 200-line source file read into the main context costs ~2-3% of the window. Across 5 source files, that is 10-15% consumed before any reasoning happens. Delegating the reads to subagents keeps the main context free for decision-making while the subagents handle the mechanical read-summarize-edit cycle.

## Session Economics Framework

Every session has a fixed context budget. These constraints prevent the common failure mode where ambitious plans collapse at 70% context with work half-persisted.

### Context Budget Allocation

| Phase | Target % | Cumulative | Action |
|-------|:--------:|:----------:|--------|
| Planning + startup | ~15% | 15% | Approve plan, set up context |
| Core work batches | ~40-45% | 55-60% | Execute in batched subagent calls |
| Wrap-up + persistence | ~5-7% | 60-67% | Persist results, write summaries |
| **Buffer** | 3-7% | 67-70% | Safety margin before hard stop |

### Hard Rules

- **Plan wrap-up by 60% context.** Begin persistence and summarization.
- **Hard stop at 67%.** Everything must be persisted by this point.
- **Compaction at ~70% is catastrophic.** It loses context in unpredictable ways. Never let it happen silently.
- **Subagent output caps:**
  - Classification/metadata tasks: keep under 3KB per subagent return
  - Research/synthesis tasks: 15KB maximum per subagent return
- **Max 6 subagent spawns per research session.** Each spawn costs overhead for setup and return processing. Beyond 6, coordination overhead exceeds the benefit.

### Decision Rules at Checkpoints

Use these when evaluating whether to continue or split:

| Checkpoint | If Over Target | Action |
|------------|:-------------:|--------|
| After ~37% | >40% | Compress batch summaries before continuing |
| After ~54% | >58% | Skip remaining batches, persist what exists, split to next session |
| At 67% | Any | Persist all results immediately, write exit summary |

## Checkpoint Decision Rules

Context checkpoints are not suggestions. They are hard gates that require explicit evaluation and action.

### 30% Context: Working Memory Audit

Evaluate whether working details from completed phases can be discarded. At this point, early-phase outputs (search results, intermediate classifications, draft tables) may still be in context but are no longer needed for reasoning.

- **Keep:** Outcomes, decisions, file paths, issue IDs
- **Discard mentally:** Raw search results, intermediate drafts, superseded plans
- **Action:** If context feels heavy, delegate the next phase to a subagent instead of running it inline

### 50% Context: Caution Threshold

This is the first mandatory warning point.

- **Warn the human** about context usage level
- **Tighten delegation:** Move all Tier 2 operations into subagents regardless of item count
- **Summarize aggressively:** Reference previous decisions instead of restating them

### 56% Context: Handoff Evaluation

If remaining work is substantial (more than one major phase), write a session handoff file now rather than risking compaction later.

- **Handoff file contents:** Completed phases, remaining work items, all issue IDs with current status, decisions made, open questions
- **Location:** `~/.claude/plans/` with the session's animal name
- **Consider starting a new session** if the remaining work involves research or bulk operations

### 70% Context: Hard Stop

Do NOT continue working. This is not a warning, it is a stop signal.

1. **Write handoff file** with: completed phases, remaining work, issue IDs pending, file paths modified
2. **Persist all in-progress work** to files (not just in context)
3. **Tell the human** what was completed and what remains
4. **Do NOT let compaction happen.** A deliberate split preserves continuity. Compaction destroys it.

## Linear Query Specificity

The project tracker is the single largest source of context bloat when used carelessly. A single unfiltered `list_issues` call can return 100KB+ of JSON, consuming 15-20% of the context window in one operation.

### Mandatory Rules

- **ALWAYS** use `limit: 10` (or less) on `list_issues` calls. There is no valid reason to fetch more than 10 issues at once.
- **NEVER** run `list_issues` in the main context. Always delegate to a subagent that returns a markdown table.
- **Single `get_issue`** is OK directly in the main context. It returns a predictable ~500 bytes to 1KB.
- **2+ issues** must go through a subagent, even if you know the exact IDs. The subagent fetches and returns a summary table.
- **Zotero `get_collection_items`:** Same rules as `list_issues`. Collections can contain thousands of items.

### Subagent Return Format for Issues

The subagent should return a compact markdown table:

```markdown
| ID | Title | Status | Assignee | Priority |
|----|-------|--------|----------|----------|
| CIA-101 | Fix login flow | In Progress | Claude | High |
| CIA-102 | Update API docs | Todo | Unassigned | Medium |
```

No descriptions, no full metadata dumps, no nested JSON. The main context uses this table for decision-making and can call `get_issue` on specific IDs if deeper detail is needed.
