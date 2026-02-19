---
description: |
  Capture session state for structured handoff before a context boundary or session split.
  Writes progress to .ccc-progress.md, optionally snapshots git state, updates the Linear issue in place, and prints a continuation prompt for the next session.
  Use when approaching context limits, stepping away mid-task, or explicitly handing off to another session.
  Integrates with /compact and /resume as a CCC-layer complement — /compact reduces context, /ccc:checkpoint preserves task state.
  Trigger with phrases like "checkpoint", "save progress", "hand off session", "save state", "continuation prompt", "prepare for session split", "pre-exit checkpoint".
argument-hint: "[--skip-git] [--skip-linear]"
allowed-tools: Read, Write, Edit, Bash
platforms: [cli]
---

# Checkpoint Command

Invoke the CCC checkpoint protocol to capture session state before a context boundary. This is the **manual interactive profile** — it runs all four steps and prints the continuation prompt to stdout.

For the automated (non-interactive) profile used by the stop hook, see [skills/session-exit/references/checkpoint-protocol.md](../skills/session-exit/references/checkpoint-protocol.md).

## When to Use

- Context usage is approaching 50-70% and you want to ensure state is preserved before `/compact`
- You are about to end the session and want a structured handoff for the next session
- You are at a natural task boundary (completed a subtask, waiting on a review, blocked)
- The stop hook did not fire at the expected gate and you want to manually checkpoint

## What This Command Does

Executes the four-step checkpoint protocol defined in [skills/session-exit/references/checkpoint-protocol.md](../skills/session-exit/references/checkpoint-protocol.md):

1. **Persist progress** (always) — Updates `.ccc-progress.md` with completed tasks, current state, remaining work, decisions, blockers, and a structured continuation prompt
2. **Git snapshot** (optional, skip-aware) — Stages and commits in-scope tracked files if the working tree is dirty; skips gracefully if clean or if no in-scope files are staged
3. **Linear status update** (best-effort, upsert) — Updates a single "Checkpoint Status" comment on the active issue in place; creates it on first checkpoint, updates it thereafter
4. **Output continuation prompt** (always) — Prints the `## Continuation Prompt` section from `.ccc-progress.md` to stdout for immediate use in the next session

## Execution

### Step 1: Determine Active Issue

Read `.ccc-state.json` to get `activeIssue`. If not found, check the session branch name for a CIA-XXX pattern. If still not found, prompt the user: "Which CIA issue should this checkpoint be associated with?"

### Step 2: Execute Checkpoint Protocol

Follow the protocol in `skills/session-exit/references/checkpoint-protocol.md` exactly, in the manual interactive profile:

**Step 1 — Persist progress:**
- Read `.ccc-progress.md` if it exists (to preserve existing structure)
- Update or create with current session state
- Ensure `## Continuation Prompt` section is present and specific

**Step 2 — Git snapshot:**
- Run `git status --porcelain`
- If clean: output "Git snapshot skipped — working tree clean." Proceed to Step 3.
- If `--skip-git` flag provided: output "Git snapshot skipped (--skip-git)." Proceed to Step 3.
- If dirty: identify in-scope files from `.ccc-state.json` (`activeTaskFiles`) or ask user which files to stage
- Stage only identified files. Never `git add .`.
- Commit. If pre-commit hook fails or nothing stages: skip gracefully.

**Step 3 — Linear update:**
- If `--skip-linear` flag provided: output "Linear update skipped (--skip-linear)." Proceed to Step 4.
- Read `checkpointCommentId` from `.ccc-state.json`
- If present: update existing comment with current state
- If absent: create new "Checkpoint Status" comment, write ID back to `.ccc-state.json`
- On API failure: log warning, proceed to Step 4

**Step 4 — Output continuation prompt:**
- Read `## Continuation Prompt` from `.ccc-progress.md`
- Print formatted to stdout (see format below)

### Step 3: Report Completion

```
Checkpoint complete: [N]/4 steps succeeded.
[Failed: <step> — <reason>]
```

## Continuation Prompt Output Format

```
╔══════════════════════════════════════════════════╗
║  CONTINUATION PROMPT — CIA-XXX                   ║
╚══════════════════════════════════════════════════╝

[Content of ## Continuation Prompt from .ccc-progress.md]

Use /resume or paste this prompt into a new session to continue.
```

## Flags

| Flag | Effect |
|------|--------|
| `--skip-git` | Skip Step 2 (git snapshot). Useful when git state is intentionally dirty. |
| `--skip-linear` | Skip Step 3 (Linear update). Useful when Linear API is unavailable. |

## Relationship to Other Commands

| Command | Relationship |
|---------|-------------|
| `/compact` | Reduces context window. `/ccc:checkpoint` preserves task state. Use together: checkpoint first, then compact. |
| `/resume` | Restores a previous session. The continuation prompt generated by checkpoint feeds directly into `/resume`. |
| `/ccc:go` | Reads `.ccc-progress.md` on session start. Checkpoint ensures this file is current. |
| `session-exit` skill | Checkpoint is a pre-exit option, not a replacement. Session exit still runs normalization; checkpoint handles task-level state. |

## Error Handling

Each step runs independently. Failure in one step does not prevent subsequent steps from running. At the end, the summary reports which steps succeeded and which failed with the reason.

The human can take manual action for failed steps (e.g., manually update Linear if the API was unreachable).
