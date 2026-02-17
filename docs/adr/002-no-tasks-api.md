# ADR-002: CCC Does Not Adopt Claude Code Tasks API

**Status:** Accepted
**Date:** 2026-02-17
**Context:** CIA-497

## Decision

CCC will NOT integrate with Claude Code's Tasks API (`CLAUDE_TASK_LIST_ID`, `.claude/tasks/` files) for cross-session state management. CCC will continue using its own `.ccc-state.json` + `.ccc-progress.md` for execution loop state.

## Context

Claude Code introduced a Tasks system (January 2026) that replaces the older Todos API. Tasks are written to `.claude/tasks/{session_id}/` as JSON files and can be read/written via tool calls (`TaskRead`, `TaskWrite`) or the `CLAUDE_TASK_LIST_ID` environment variable.

Pierce Lamb's Deep Trilogy plugins (`/deep-project`, `/deep-plan`, `/deep-implement`) attempted to use the Tasks API for cross-session state persistence. His published learnings (February 2026) document the experience.

## Why Not

1. **Hallucination-prone at scale.** Pierce found that chaining 40+ Tasks API tool calls in a single session led to hallucinated task IDs, duplicate entries, and lost state. He ultimately bypassed the API and wrote Task files directly to `.claude/tasks/` using the filesystem.

2. **Schema coupling.** Writing directly to `.claude/tasks/` couples the plugin to Claude Code's internal file format. If the Tasks schema changes (field names, nesting, session ID format), the plugin breaks silently.

3. **CCC's state model is simpler.** `.ccc-state.json` is a single flat JSON file with 14 well-defined fields. `.ccc-progress.md` is append-only markdown. Both are self-contained, easy to debug (just `cat` them), and require zero knowledge of Claude Code internals.

4. **Different purpose.** The Tasks API is designed for ephemeral in-session task tracking visible in Claude Code's UI. CCC's state files are designed for cross-session execution loop persistence. These are fundamentally different use cases.

5. **TodoWrite fills the ephemeral gap.** For in-session progress tracking (what Tasks API was designed for), CCC now instructs the agent to use `TodoWrite` at the start of each task session. This is ephemeral by design and doesn't require persistent state.

## Consequences

- CCC state files (`.ccc-state.json`, `.ccc-progress.md`) remain the single source of truth for execution loop state.
- The stop hook (`ccc-stop-handler.sh`) continues to read/write these files directly via `jq`.
- No dependency on Claude Code internal file schemas.
- CCC execution state is not visible in Claude Code's native Tasks UI. This is acceptable because CCC provides its own status view via `/ccc:go --status`.

## References

- Pierce Lamb, "What I Learned While Building a Trilogy of Claude Code Plugins" (Feb 2, 2026)
- ADR-001: Plugin Distribution (for prior architectural decision context)
- `skills/execution-engine/SKILL.md` -- State file schemas and lifecycle
