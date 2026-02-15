# Adversarial Review: CIA-356

**Spec:** Normalize conventions across remaining Linear projects
**Reviewer:** Generic (Opus 4.6, no plugin augmentation)
**Date:** 2026-02-15

**Recommendation:** PASS (with minor revisions)

---

## Critical Findings

None.

---

## Important Findings

1. **Pre-Cleanup Audit uses approximate counts and TBD entries, but the execution checklist treats them as fixed.**
   The audit table says "~2" missing type labels for AI PM Plugin and "TBD" for all Unassigned columns, yet Phase 0 lists exactly 5 unassigned issues with specific routing decisions. If the actual unassigned issue set differs at execution time (issues may have been assigned since the 11 Feb snapshot, or new unassigned issues may have appeared), the executor could miss items or attempt operations on already-routed issues. The spec should either (a) instruct the executor to re-audit unassigned issues at execution time and treat the Phase 0 list as a baseline expectation, or (b) pin the snapshot date and state it is authoritative.
   **Impact:** Missed issues or failed operations on already-moved issues.
   **Suggested resolution:** Add a note to Phase 0: "Re-query unassigned issues at execution time. The list below is the expected set as of 11 Feb 2026; handle any delta (new unassigned issues or already-routed issues) by applying the same routing heuristic."

2. **CIA-248 deletion path lacks a fallback if GraphQL deletion is unavailable or fails.**
   The spec says "Delete or archive" for CIA-248 and references the GraphQL `issueDelete` mutation in Constraints. However, it does not specify what to do if: (a) the `LINEAR_API_KEY` is not available in the session, (b) the `query.ts` script is not present or fails, or (c) the issue has already been deleted. The SKILL.md Deletion Protocol (step 1-5) is more thorough but the spec does not explicitly require following it -- it only references SKILL.md in Constraints for "full methodology."
   **Impact:** Executor gets stuck or silently skips deletion.
   **Suggested resolution:** Add explicit fallback: "If GraphQL deletion is unavailable, cancel the issue with a comment 'Non-actionable test issue, superseded' and move to a 'Done' state. Deletion is preferred but not blocking."

3. **No rollback or error-handling strategy for partial completion.**
   The spec is a multi-phase checklist across 4 projects. If the session is interrupted mid-execution (context limit, API failure, session timeout), there is no guidance on how to resume or what state partial completion leaves the workspace in. Since label updates replace entire arrays (per DO NOT rule #1), a failed mid-batch operation could leave issues with incorrect labels.
   **Impact:** Partial execution could leave issues in a worse state than before (missing labels).
   **Suggested resolution:** Add a Constraints bullet: "If session is interrupted, the verification sweep (Phase 4) serves as the recovery mechanism -- re-run from Phase 4 in the next session to detect and fix any inconsistencies from partial execution. Label operations are idempotent when following the read-then-write pattern."

---

## Consider

1. **The spec does not define what "non-actionable content" means for each project.**
   The Acceptance Criteria says "Non-actionable content converted to Documents where applicable" and the Pre-Cleanup Audit identifies "Templates, plans" and "1 session plan" as document candidates. However, the executor must still make judgment calls at runtime about whether specific issues are actionable. The SKILL.md Content Classification Matrix provides the framework, but the spec could reduce ambiguity by listing the specific issue IDs suspected to be document candidates (similar to how Phase 0 lists specific unassigned issues).
   **Rationale:** For a `quick` exec mode, minimizing runtime judgment calls improves reliability.

2. **The "Key Resources document" acceptance criterion is ambiguous about the "(or confirmed not needed)" case.**
   What counts as "confirmed not needed"? For consistency, the spec could state which projects are expected to need Key Resources and which are not, or define a simple threshold (e.g., "projects with fewer than 3 active issues may skip Key Resources").
   **Rationale:** Minor ambiguity; unlikely to cause problems but could lead to inconsistent decisions across projects.

3. **No explicit ordering of label operations within a single issue.**
   When an issue needs both a deprecated label removed and a `type:*` label added, the spec does not state whether these should be a single update (preferred) or two sequential updates. The DO NOT rules (#1) imply a single read-then-write, but the spec's Phase structure (Phase 4: Rename, then Phase 5: Relabel in SKILL.md) could be misread as separate operations on the same issue.
   **Rationale:** The referenced SKILL.md makes this clear enough, but an explicit note in Constraints ("combine all label changes per issue into a single update_issue call") would remove any doubt.

4. **Duplicate CodeQL issues (CIA-258 and CIA-242) both routed to AI PM Plugin.**
   Both are described as "CodeQL security findings" and routed to the same project with the same label. Are these genuinely distinct issues? If they are duplicates, one should be merged per the SKILL.md Triage Decision Tree (step 2: MERGE). The spec does not address this.
   **Rationale:** Could result in duplicate issues persisting in AI PM Plugin after cleanup, which is ironic for a normalization task.

5. **The estimated effort of 30-45 minutes may be tight for ~42 issues with subagent batching.**
   The Alteri cleanup of 178 issues was a multi-session effort. Here ~42 issues across 4 projects plus verification is scoped at 30-45 minutes. This is plausible for a well-specified checklist but leaves no buffer for unexpected findings (e.g., issues that need splitting per the SKILL.md edge case rule, or content that needs document conversion with description preservation).
   **Rationale:** Not blocking -- the `exec:quick` mode is appropriate for the scope. But the executor should be aware that 45 minutes is the realistic floor, not the ceiling.

---

## Quality Score

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Completeness | 4 | Covers all projects, has a pre-audit snapshot, execution phases are well-structured. Missing: explicit handling of stale snapshot data, rollback strategy, and CIA-258/242 dedup check. |
| Clarity | 5 | Exceptionally clear. Phased execution with specific issue IDs, concrete checklist items, and explicit constraints. No ambiguous language. |
| Testability | 4 | Acceptance criteria are mostly binary (has label / no bracket prefix / verb-first). The "non-actionable content converted to Documents" criterion is less testable -- how does the verifier know all candidates were identified? |
| Feasibility | 5 | Well within the capabilities of the executor. All referenced tools, scripts, and patterns exist. The scope is modest and the methodology is proven (Alteri precedent). |
| Safety | 4 | Constraints correctly call out the label replacement footgun and human-owned field boundaries. Missing: explicit rollback/recovery guidance and fallback for GraphQL deletion. No risk of data loss if DO NOT rules are followed. |

**Overall: 4.4 / 5**

---

## What Works Well

- **Pre-Cleanup Audit table.** Providing a snapshot of the current state per project is excellent practice. It sets expectations for the executor, enables progress tracking, and makes the verification sweep meaningful (compare before/after).

- **Explicit issue routing in Phase 0.** Listing every unassigned issue by ID with its target project and label eliminates guesswork. This is the right level of specificity for a `quick` exec mode.

- **Constraints section is battle-hardened.** The label replacement warning, batch size limit, human-owned field boundaries, and GraphQL deletion note all reference real failure modes from prior sessions. This spec clearly benefits from the Alteri cleanup experience.

- **Phased execution with a mandatory verification sweep.** The Phase 0-4 structure follows the SKILL.md sequence and explicitly includes verification as a non-optional final phase. This matches DO NOT rule #4 exactly.

- **Scope discipline.** The spec correctly limits itself to normalization and does not attempt spec rewrites, priority changes, or cycle planning. It stays in its lane.

- **SKILL.md reference for full methodology.** Rather than duplicating the entire cleanup playbook, the spec references it and only inlines the project-specific decisions. This keeps the spec concise without losing rigor.
