# Checkpoint Protocol

The checkpoint protocol is a reusable, four-step process for capturing session state before a context boundary (session split, context threshold, explicit handoff request). It is invoked by the `/ccc:checkpoint` command (interactive) and by the stop hook at gate boundaries (automated, non-interactive).

## Design Principles

- **Fail-forward:** Each step runs independently. A failure in one step does not block subsequent steps.
- **Skip-aware:** Steps that have nothing to do skip gracefully with a message rather than erroring.
- **Two profiles:** Manual (interactive, all 4 steps) and automated (non-interactive, steps 1 and 3 only).
- **Upsert model:** Linear comment is updated in place, not created fresh on each checkpoint.
- **Single artifact:** The canonical handoff artifact is `.ccc-progress.md`. No new files per checkpoint.

## The Four Steps

### Step 1: Persist Progress (always — both profiles)

Update `.ccc-progress.md` with the current session state. Create the file if it does not exist.

Required sections:

```markdown
# Session Progress

**Issue:** CIA-XXX — [Title]
**Session:** [timestamp]
**Execution Mode:** exec:[mode]

## Completed Tasks
- [task description] ✓

## Current Task
- [task description] — [status or last action]

## Remaining Tasks
- [task description]

## Decisions Made
- [decision]: [rationale]

## Blockers
- [blocker description] (unblocked by: [condition])

## Continuation Prompt
Resume CIA-XXX. Current task: [task N of M]. Key files: [file list].
Next action: [specific next step].
```

The `## Continuation Prompt` section is the structured prompt read by `/ccc:go` on resume. It must be specific enough to restart work without re-reading the full conversation.

**On failure:** Log warning. Step 2 still runs.

### Step 2: Git Snapshot (optional, skip-aware — manual profile only)

The automated profile skips this step entirely (the execution engine handles commits via `TASK_COMPLETE`).

For manual invocations:

1. Check working tree status (`git status --porcelain`)
2. If clean: output "Git snapshot skipped — working tree clean." Continue to Step 3.
3. If dirty: identify in-scope files using `.ccc-state.json` (`activeTaskFiles` field if available)
4. Stage only in-scope tracked files. Never `git add .` or `git add -A`.
5. Commit with message format from `skills/execution-engine/references/configuration.md`
6. If pre-commit hook fails or nothing to stage: skip gracefully with message

**On failure:** Log warning. Step 3 still runs. Never abort checkpoint on git failure.

### Step 3: Linear Status Update (best-effort, upsert model — both profiles)

Maintain a single "Checkpoint Status" comment on the parent issue. Update it in place on each checkpoint — do not create a new comment.

Comment format:

```markdown
## Checkpoint Status

**Updated:** [timestamp]
**Task:** [N] of [M] — [task description]
**Status:** [In Progress / Blocked / Resuming]

**Decisions:** [key decisions since last checkpoint]
**Blockers:** [active blockers, or "None"]
**Next:** [specific next action]
```

Implementation notes:
- On first checkpoint: create comment, store comment ID in `.ccc-state.json` as `checkpointCommentId`
- On subsequent checkpoints: update existing comment using stored ID
- If `.ccc-state.json` has no `checkpointCommentId`: create new comment and store ID
- If Linear API is unreachable: skip, log warning to stdout

**On failure:** Log warning. Step 4 still runs.

### Step 4: Output Continuation Prompt (always — manual profile only)

The automated profile skips this step (the stop hook injects a continuation prompt via the `reason` field).

For manual invocations, print the `## Continuation Prompt` section from `.ccc-progress.md` to stdout:

```
╔══════════════════════════════════════════════════╗
║  CONTINUATION PROMPT                             ║
╚══════════════════════════════════════════════════╝

[Content of ## Continuation Prompt from .ccc-progress.md]

Copy this prompt into your next session's first message.
```

**On failure:** If `.ccc-progress.md` cannot be read, print a warning and provide a generic prompt template.

## Completion Report

After all steps complete, output a summary:

```
Checkpoint complete: 4/4 steps succeeded.
```

Or with failures:

```
Checkpoint complete: 3/4 steps succeeded.
Failed: Linear update (HTTP 503) — status not persisted to issue tracker.
```

Never suppress partial success. The human needs to know which steps failed so they can take manual action if needed.

## Invocation Profiles

| Step | Manual (`/ccc:checkpoint`) | Automated (stop hook) |
|------|--------------------------|----------------------|
| 1. Persist progress | ✓ Always | ✓ Always |
| 2. Git snapshot | ✓ Skip-aware | ✗ Skipped |
| 3. Linear update | ✓ Best-effort | ✓ Best-effort |
| 4. Output continuation prompt | ✓ Always | ✗ Skipped (stop hook handles) |

## Error Model Summary

| Step | On Failure | Blocks Subsequent Steps? |
|------|-----------|--------------------------|
| 1. Persist progress | Log warning | No |
| 2. Git snapshot | Log warning, skip | No |
| 3. Linear update | Log warning | No |
| 4. Continuation prompt | Log warning, use template | No |

## Integration Points

- **`/ccc:go`** reads `.ccc-progress.md` → `## Continuation Prompt` on session resume. No new integration point needed.
- **`ccc-stop-handler.sh`** calls the automated profile (steps 1 and 3) at checkpoint gates. See `hooks/scripts/ccc-stop-handler.sh` for the integration point.
- **`/ccc:checkpoint` command** calls the manual profile (all 4 steps). See `commands/checkpoint.md`.
- **`.ccc-state.json`** provides `checkpointCommentId` and `activeTaskFiles` for steps 2 and 3.
