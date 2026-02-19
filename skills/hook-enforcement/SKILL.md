---
name: hook-enforcement
description: |
  Documents the Claude Code hooks shipped with the CCC plugin and what each one enforces.
  Covers circuit-breaker error-loop protection, task-loop driving, session lifecycle,
  prompt enrichment, style injection, and Agent Teams hooks.
  Use when configuring hooks, understanding what a hook enforces, debugging hook failures,
  or choosing which hooks to enable for a project.
---

# Hook Enforcement

The CCC plugin ships shell-based Claude Code hooks that enforce workflow constraints at runtime. Unlike prompt-based rules (which are advisory), hooks block or enrich tool calls structurally.

> **Audit note:** This document was rewritten per CIA-522 audit findings to match actual implementation. Spec-enforcement (conformance auditing) hooks are documented separately as planned work (CIA-396).

## Why Hooks

| Approach | Enforcement | Failure Mode |
|----------|-------------|--------------|
| CLAUDE.md rules | Advisory | Agent forgets or ignores |
| Skills (SKILL.md) | Methodology | Agent applies inconsistently |
| Hooks | Runtime | Violation blocked before execution |

## Hook Registry

All hooks are registered in `hooks/hooks.json`. The plugin uses seven event types:

| Event | Scripts | Purpose |
|-------|---------|---------|
| SessionStart | `session-start.sh`, `style-injector.sh` | Initialize session context, inject style preferences |
| PreToolUse | `pre-tool-use.sh`, `circuit-breaker-pre.sh` | Scope-check file writes, block destructive ops during error loops |
| PostToolUse | `post-tool-use.sh`, `circuit-breaker-post.sh` | Audit tool usage, detect error loops |
| Stop | `ccc-stop-handler.sh`, `stop.sh` | Drive task loop, report session hygiene |
| UserPromptSubmit | `prompt-enrichment.sh` | Inject worktree/issue context into prompts |
| TeammateIdle | `teammate-idle-gate.sh` | Prevent idle when tasks remain (Agent Teams) |
| TaskCompleted | `task-completed-gate.sh` | Validate task completion claims (Agent Teams) |

## Circuit Breaker

The circuit breaker is the primary runtime safety mechanism. It detects error loops and blocks destructive operations to prevent the agent from compounding mistakes.

### How It Works

1. **`circuit-breaker-post.sh`** (PostToolUse) monitors every tool execution for errors.
2. On each error, it builds a signature from the tool name + first 200 chars of the error message.
3. If the same error signature repeats consecutively, a counter increments.
4. At the threshold (default 3, configurable via `.ccc-preferences.yaml`), the circuit **opens**.
5. On open, the script writes `.ccc-circuit-breaker.json` and auto-escalates execution mode from `quick` to `pair` (human-in-the-loop).
6. Successful tool executions reset the counter (but do not close an already-open circuit).

### Blocking Behavior

When the circuit is open, **`circuit-breaker-pre.sh`** (PreToolUse) classifies each tool call:

| Classification | Tools | When Circuit Open |
|---------------|-------|-------------------|
| Destructive | `Write`, `Edit`, `MultiEdit`, `NotebookEdit`, `Bash` | **Blocked** (exit 2, `permissionDecision: "deny"`) |
| Destructive (MCP) | `mcp__*__create`, `mcp__*__update`, `mcp__*__delete`, etc. | **Blocked** |
| Read-only | `Read`, `Glob`, `Grep`, `Ls`, `WebFetch`, `WebSearch`, `Task`, `TodoWrite` | **Allowed** |

### Recovery

- **Recommended:** Use `/rewind` to undo the last few tool calls and try a different approach.
- **Manual reset:** Delete `.ccc-circuit-breaker.json` from the project root.
- The circuit does not auto-close on success — explicit reset is required once opened.

### Configuration

In `.ccc-preferences.yaml`:

```yaml
circuit_breaker:
  threshold: 3  # consecutive identical errors before opening (default: 3)
```

## Hook Details

### session-start.sh

**Event:** SessionStart
**Purpose:** Verify prerequisites and report session context.

What it does:

- Validates that `git` and `jq` are available (warns if missing)
- Notes if `yq` is missing (preferences will use defaults)
- Loads the active spec path from `CCC_SPEC_PATH`
- Reports git state (branch, uncommitted files)
- Warns if `.ccc-state.json` is stale (>24h old)
- Checks for `.claude/codebase-index.md` freshness
- Reports active execution state (issue, phase, task progress) if `.ccc-state.json` exists

Fail-open: exits 0 on all paths. Informational only.

### style-injector.sh

**Event:** SessionStart
**Purpose:** Inject audience-aware output style instructions.

Reads the `style.explanatory` preference from `.ccc-preferences.yaml`:

| Level | Behavior |
|-------|----------|
| `terse` (default) | No injection |
| `balanced` / `detailed` | Injects `styles/explanatory.md` |
| `educational` | Injects `styles/educational.md` |

Strips YAML frontmatter from the style file and returns it via `hookSpecificOutput.additionalContext`.

### pre-tool-use.sh

**Event:** PreToolUse
**Matcher:** `Write|Edit|MultiEdit|NotebookEdit`
**Purpose:** Scope-check file writes against allowed paths.

What it does:

- Extracts `file_path` from the tool call
- If `CCC_ALLOWED_PATHS` is set, checks the file against the colon-separated path patterns
- In strict mode (`SDD_STRICT_MODE=true`): blocks out-of-scope writes (exit 1)
- In non-strict mode: logs a warning but allows the write

### circuit-breaker-pre.sh

**Event:** PreToolUse
**Matcher:** `Write|Edit|MultiEdit|NotebookEdit|Bash`
**Purpose:** Block destructive operations when an error loop is detected.

What it does:

- Reads `.ccc-circuit-breaker.json` to check if the circuit breaker is open
- Destructive tools (Write, Edit, Bash, MCP create/update/delete): **blocked** when circuit is open
- Read-only tools (Read, Glob, Grep, WebFetch, Task, TodoWrite): **allowed** even when circuit is open
- Returns `permissionDecision: "deny"` for blocked tools

### post-tool-use.sh

**Event:** PostToolUse
**Matcher:** (all tools)
**Purpose:** Audit tool execution and detect drift.

What it does:

- Appends to daily evidence log at `.claude/logs/tool-log-YYYYMMDD.jsonl`
- Checks current branch against protected branches (main, master, production)
- Warns if uncommitted file count exceeds 20 (suggests `/ccc:anchor`)
- In strict mode: blocks writes on protected branches

### circuit-breaker-post.sh

**Event:** PostToolUse
**Matcher:** (all tools)
**Purpose:** Detect consecutive identical errors and trip the circuit breaker.

What it does:

- Tracks error signatures (tool name + first 200 chars of error message)
- Increments counter on consecutive identical errors
- At threshold (default 3, configurable via `.ccc-preferences.yaml`): opens circuit breaker
- Writes state to `.ccc-circuit-breaker.json`
- Auto-escalates execution mode from `quick` to `pair` (human-in-the-loop)
- Resets counter on successful tool execution (when circuit is closed)

### ccc-stop-handler.sh

**Event:** Stop
**Purpose:** Drive the autonomous task execution loop across decomposed tasks.

What it does:

- Reads `.ccc-state.json` for execution phase, task index, and iteration counts
- Checks for `TASK_COMPLETE` signal in the last assistant output
- If task incomplete: increments retry counter, generates continue prompt with enrichments
- If task complete: advances to next task, resets per-task counter
- Detects `REPLAN` signal for mid-execution task regeneration (max 2 replans, configurable)
- Safety caps: global iteration limit (default 50), per-task limit (default 5)
- Allows immediate stop when awaiting human approval gates
- Only loops during the `execution` phase; `pair` and `swarm` modes do not loop
- Reads preferences from `.ccc-preferences.yaml` for iteration limits, prompt enrichments, eval settings, and context budgets

### stop.sh

**Event:** Stop
**Purpose:** Report session hygiene and activity summary.

What it does:

- Reports git state (branch, uncommitted files, unpushed commits)
- Displays session exit protocol checklist (issue normalization, evidence, sub-issues)
- Counts tool executions from today's evidence log
- Reports Agent Teams activity if `.ccc-agent-teams-log.jsonl` exists

### prompt-enrichment.sh

**Event:** UserPromptSubmit
**Purpose:** Inject worktree and issue context into user prompts.

What it does:

- Detects worktree sessions (checks if `.git` is a file, not a directory)
- Extracts CIA-XXX issue ID from the git branch name
- Injects context at configurable levels (`minimal`, `standard`, `full`) via `.ccc-preferences.yaml`:
  - **minimal:** Issue link only
  - **standard:** Issue link + branch name + isolation notice
  - **full:** Issue link + branch + isolation + commit conventions

### teammate-idle-gate.sh

**Event:** TeammateIdle (Agent Teams)
**Purpose:** Prevent teammates from going idle when tasks remain.

Configurable via `agent_teams.idle_gate` in `.ccc-preferences.yaml`:

- `allow` (default): always allow idle
- `block_without_tasks`: re-prompt teammate if pending tasks > 0 in `.ccc-agent-teams.json`

### task-completed-gate.sh

**Event:** TaskCompleted (Agent Teams)
**Purpose:** Validate task completion claims with basic heuristics.

Configurable via `agent_teams.task_gate` in `.ccc-preferences.yaml`:

- `off`: no validation
- `basic` (default): rejects if description is <=10 chars or contains error keywords (error, failed, exception, traceback, cannot, unable)

Updates `.ccc-agent-teams.json` task counters and appends to `.ccc-agent-teams-log.jsonl`.

## Planned: Spec-Enforcement Hooks (CIA-396)

The following conformance auditing hooks are implemented as scripts but not yet fully integrated into the standard workflow. They are gated behind `CCC_SPEC_PATH` and require a spec file to activate:

| Script | Event | Purpose |
|--------|-------|---------|
| `conformance-cache.sh` | SessionStart | Parse acceptance criteria from active spec into keyword cache |
| `conformance-log.sh` | PostToolUse (writes) | Append write metadata to conformance queue |
| `conformance-check.sh` | Stop | Batch-audit writes against acceptance criteria, produce conformance report |

These hooks form a three-stage pipeline:

1. **Cache** (session start): Extracts unchecked `- [ ]` checkboxes from the spec, tokenizes each criterion into keywords (lowercase, >=4 chars, stop words removed), writes `.ccc-conformance-cache.json`.
2. **Log** (each write): Appends tool name, file path, and parameter keys to `.ccc-conformance-queue.jsonl`. O(1) append, never blocks.
3. **Check** (session stop): For each logged write, tokenizes file path and parameters, calculates keyword overlap with each criterion. A write is "conforming" at >=50% overlap. Checks for `// ccc:suppress` comments. Produces `.ccc-conformance-report.json`.

Full integration — including automatic spec path detection and workflow-level gating — is tracked in CIA-396.

## State Files

The hooks use these state files in the project root:

| File | Purpose | Lifecycle |
|------|---------|-----------|
| `.ccc-state.json` | Task loop state (phase, task index, iterations) | Persistent across sessions |
| `.ccc-circuit-breaker.json` | Error loop detection state | Cleared on manual reset |
| `.ccc-agent-teams.json` | Agent Teams task counters | Persistent |
| `.ccc-preferences.yaml` | User preferences for all hooks | User-managed |
| `.ccc-agent-teams-log.jsonl` | Task completion audit trail | Append-only |
| `.claude/logs/tool-log-YYYYMMDD.jsonl` | Daily tool evidence log | Daily rotation |

### Planned State Files (CIA-396)

| File | Purpose | Lifecycle |
|------|---------|-----------|
| `.ccc-conformance-cache.json` | Acceptance criteria keywords | Session-scoped, cleared on Stop |
| `.ccc-conformance-queue.jsonl` | Write event buffer | Session-scoped, cleared on Stop |
| `.ccc-conformance-report.json` | End-of-session conformance audit | Generated on Stop |

## Fail-Open Design

All hooks exit 0 when prerequisites or input files are missing. Only three hooks intentionally block operations:

- **circuit-breaker-pre.sh**: denies destructive tools when circuit is open (exit 2)
- **teammate-idle-gate.sh**: re-prompts teammate when pending tasks remain (exit 2, when gate is `block_without_tasks`)
- **task-completed-gate.sh**: rejects incomplete task completion claims (exit 2, when gate is `basic`)

## Environment Variables

| Variable | Used By | Purpose |
|----------|---------|---------|
| `CCC_SPEC_PATH` | session-start.sh, conformance-cache.sh | Path to active spec file |
| `CCC_ALLOWED_PATHS` | pre-tool-use.sh | Colon-separated allowed write paths |
| `CCC_PROJECT_ROOT` | ccc-stop-handler.sh, conformance hooks | Project root directory |
| `CLAUDE_PLUGIN_ROOT` | style-injector.sh | Plugin installation directory |
| `SDD_STRICT_MODE` | pre-tool-use.sh, post-tool-use.sh | Enable strict enforcement |
| `SDD_LOG_DIR` | post-tool-use.sh, stop.sh | Directory for evidence logs |
| `SDD_PROJECT_ROOT` | session-start.sh, stop.sh, circuit-breaker hooks | Project root (legacy alias) |

## Installation

1. Install the CCC plugin — hooks are registered via `hooks/hooks.json` automatically
2. Create `.ccc-preferences.yaml` in your project root to configure hook behavior
3. Set `CCC_SPEC_PATH` if using conformance auditing (CIA-396)
4. Set `CCC_ALLOWED_PATHS` if using write scope enforcement

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Hook blocks all writes | Circuit breaker is open | Delete `.ccc-circuit-breaker.json` or use `/rewind` to recover from the error loop |
| Hook doesn't fire | Script missing executable bit | `chmod +x` the script, verify path in hooks.json |
| Session start slow | Too many prereq checks failing | Ensure `git`, `jq` are installed |
| Stop hook keeps re-entering session | ccc-stop-handler.sh driving task loop | Check `.ccc-state.json` for task progress; adjust iteration caps in `.ccc-preferences.yaml` |
| Style not injected | `yq` not installed or style.explanatory is `terse` | Install `yq` and set `style.explanatory` to `balanced`, `detailed`, or `educational` |
