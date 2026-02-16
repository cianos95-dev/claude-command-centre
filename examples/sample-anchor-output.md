# Example: Anchor Check Output

> **Funnel position:** Mid-implementation utility -- output of `/ccc:anchor`
> **Purpose:** Re-anchors to the active spec by re-reading source artifacts and detecting drift
> **Prerequisite:** An active issue with a spec and ongoing implementation work
> **Related:** Drift prevention skill governs the anchoring protocol. Codebase awareness skill provides the index that anchor consults.

This example shows what `/ccc:anchor` produces when run mid-session during implementation of a feature. It demonstrates the full alignment check: acceptance criteria tracking, drift detection, open items, and the recommended next action.

---

## Anchor Check -- PROJ-042

**Spec:** Collaborative Session Notes | **Mode:** exec:tdd | **Status:** spec:implementing

### Acceptance Criteria

- [x] Real-time co-editing works with up to 10 concurrent users with <500ms sync latency -- implemented in `src/lib/crdt-sync.ts:42-98`, tested in `src/lib/__tests__/crdt-sync.test.ts` (6 tests, all passing)
- [x] Action items (AI: or @person patterns) are highlighted in real-time as typed -- implemented in `src/components/session-editor.tsx:115-143`, pattern matcher in `src/lib/action-item-parser.ts`
- [~] "Close Session" extracts decisions, action items, and open questions -- extraction logic exists in `src/lib/session-extractor.ts` but only handles action items. Decisions (`DECIDED:`) and open questions (`?`) patterns are not yet implemented.
- [ ] Extracted action items create issues in connected project tracker with correct assignee -- not yet started
- [ ] Session summary posted to configured communication channel -- not yet started
- [x] Users can edit/delete extracted items before confirming creation -- implemented in `src/components/extraction-review-modal.tsx`, tested with 4 unit tests
- [ ] Offline edits sync correctly when connection is restored -- not yet started

**Progress: 3/7 complete, 1 partial, 3 not started**

### Drift Detected

- **Scope creep: custom emoji reactions.** The session editor now includes a reaction picker component (`src/components/reaction-picker.tsx`, 87 lines) that is not in the spec. This was added during the co-editing implementation "because it was easy" but no acceptance criterion calls for it. The component is wired into the editor and has 2 tests.

- **Pattern deviation: extraction logic location.** The spec's pre-mortem recommended pure NLP extraction without syntax requirements (finding I2 from adversarial review, severity: Important). The current implementation uses rigid regex patterns (`/^AI:\s/`, `/^DECIDED:\s/`, `/^@\w+/`). This contradicts the review finding that was accepted at Gate 2. The regex approach is simpler but does not match the agreed direction.

- **Stale assumption: auth model.** Early in the session, implementation assumed session links would be unauthenticated (shareable URLs). Adversarial review finding C3 (severity: Critical) required workspace authentication by default. The current `src/lib/session-auth.ts` still uses unauthenticated link sharing. This was addressed in the review but the implementation predates the fix.

### Open Items

- **Unresolved review finding C1:** Conflict resolution UX is not specified. The CRDT sync layer uses last-write-wins but no user-facing conflict indicator exists. The review recommended showing both versions with a merge prompt. This is blocked on a design decision.
- **Unresolved review finding I3:** Offline-first architecture is not described in the spec. Implementation of criterion 7 (offline sync) cannot proceed without a decision on local storage mechanism and maximum offline divergence time.
- **Open question from spec FAQ Q9:** Action item extraction accuracy threshold is undefined. Current implementation has no accuracy tracking. Review finding C2 recommended 95% precision / 80% recall targets before removing the confirmation step.
- **Carry-forward from session 1:** PROJ-055 (Rate limiting for real-time sync) was created as a carry-forward from review finding N3. Not blocking current work, but should be prioritized before production launch.

### Git State

- **Branch:** `feat/session-notes` (12 commits ahead of `main`)
- **Uncommitted changes:** 3 files modified (`session-extractor.ts`, `session-extractor.test.ts`, `extraction-review-modal.tsx`)
- **Last commit:** `Add extraction review modal with edit/delete` (32 minutes ago)
- **Stashed:** 1 stash entry -- `WIP: offline sync experiment` (from 2 hours ago, abandoned approach)

### Next Action

- **Address the authentication drift immediately.** Finding C3 was rated Critical and was accepted at Gate 2. The current unauthenticated implementation is a known security gap. Refactor `src/lib/session-auth.ts` to require workspace authentication before continuing with new criteria.

---

## Second Example: Clean Anchor (No Drift)

> This shorter example shows what a healthy anchor check looks like when implementation is on track.

## Anchor Check -- PROJ-038

**Spec:** Authentication System Refactor | **Mode:** exec:checkpoint | **Status:** spec:implementing

### Acceptance Criteria

- [x] JWT token generation uses RS256 with rotating keys -- implemented in `src/auth/token.ts:18-45`, 8 tests passing
- [x] Refresh token rotation invalidates previous token on use -- implemented in `src/auth/refresh.ts:22-67`, 5 tests passing
- [x] Token revocation endpoint returns 204 on success -- implemented in `src/api/auth/revoke.ts`, integration test passing
- [x] All existing sessions remain valid during migration -- migration script tested against staging copy, zero session drops

**Progress: 4/4 complete**

### Drift Detected

- None. Implementation aligns with spec across all acceptance criteria.

### Open Items

- **Checkpoint gate pending.** The `exec:checkpoint` mode requires explicit human approval before merging the migration script (criterion 4). PR #125 is open and awaiting review. Do not merge without approval.

### Git State

- **Branch:** `feat/auth-refactor` (3 PRs: #121 merged, #123 merged, #125 open)
- **Uncommitted changes:** None
- **Last commit:** `Add token revocation integration test` (8 minutes ago)

### Next Action

- **All criteria met.** Suggest running `/ccc:close` to evaluate closure. Note: this is a multi-PR issue, so closure will be PROPOSE (not auto-close) per the closure rules matrix.

---

## Third Example: Anchor After Context Compaction

> This example shows the critical case where anchoring occurs after context compaction, which is the most dangerous time for drift.

## Anchor Check -- PROJ-051

**Spec:** Data Pipeline Backfill | **Mode:** exec:checkpoint | **Status:** spec:implementing

### Acceptance Criteria

- [x] Backfill script processes records in batches of 1000 -- implemented in `scripts/backfill.ts:34-78`
- [x] Progress is resumable from last successful batch -- checkpoint file at `data/backfill-checkpoint.json`
- [~] Dry-run mode writes to staging table, not production -- dry-run flag exists but staging table connection is hardcoded to production credentials. **This is a regression risk.**
- [ ] Rollback script restores previous state from snapshot -- not yet started

**Progress: 2/4 complete, 1 partial with risk, 1 not started**

### Drift Detected

- **Context compaction occurred.** This anchor check is rebuilding state from artifacts. The following context may have been lost:
  - Conversation history about the staging table decision (check issue comments for PROJ-051)
  - Any in-progress design notes for the rollback script
  - The rationale for batch size 1000 (was this tested or arbitrary?)
- **Partial criterion risk.** The dry-run mode pointing to production credentials is a serious concern given this is a `checkpoint` mode task. The checkpoint gate for "after data transformation logic, before running on production data" has NOT been passed.

### Open Items

- **Checkpoint gate not yet reached.** Per the `exec:checkpoint` rules, implementation must pause for human review after the data transformation logic is complete. Criterion 3 (dry-run mode) must be verified safe before any production data operations.
- **Rollback design needed.** No design exists for the rollback script (criterion 4). Given the checkpoint mode, this should be designed and reviewed before implementation, not improvised.

### Git State

- **Branch:** `feat/data-backfill` (5 commits ahead of `main`)
- **Uncommitted changes:** 1 file (`scripts/backfill.ts` -- the staging table connection fix is in progress)
- **Last commit:** `Add resumable checkpoint to backfill script` (47 minutes ago)

### Next Action

- **Fix the staging table connection immediately.** This is a safety issue in a checkpoint-mode task. Change the dry-run mode to use the staging credentials, commit, then pause for checkpoint review before proceeding to criterion 4.

---

## Notes on This Example

**What to look for in a good anchor output:**

1. **Acceptance criteria map to code locations.** Each criterion marked `[x]` includes the file and line range where it is implemented, plus test references. This makes verification auditable.

2. **Drift detection is specific and actionable.** Each drift item names the exact file, the spec requirement it violates, and the review finding it relates to. Vague statements like "implementation may have drifted" are not useful.

3. **Open items distinguish blocking from non-blocking.** Carry-forward items and nice-to-have review findings are listed but clearly marked as non-blocking. Critical gaps (like the auth model mismatch) are flagged for immediate action.

4. **The "Next Action" is singular.** The anchor check recommends exactly one next step -- the most important thing to do right now to stay aligned. Multiple next actions dilute focus.

5. **Context compaction is explicitly acknowledged.** When compaction has occurred (Example 3), the anchor check lists what context may have been lost and suggests where to recover it. This is the primary safety net against post-compaction drift.

6. **Git state provides grounding.** The branch name, commit history, uncommitted changes, and stash state give concrete evidence of where the implementation stands, independent of what the agent "remembers" from the session.
