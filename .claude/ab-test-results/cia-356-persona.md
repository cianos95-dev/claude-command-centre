# Adversarial Review Panel: CIA-356 -- Normalize conventions across remaining Linear projects

**Spec:** CIA-356
**Exec Mode:** quick
**Status:** ready
**Review Date:** 15 Feb 2026
**Panel:** Security Skeptic, Performance Pragmatist, Architectural Purist, UX Advocate

---

## Security Skeptic Review: CIA-356

**Threat Model Summary:** The primary threat surface is the Linear MCP's `update_issue` behavior (full label array replacement) combined with OAuth agent token access. A careless or compromised execution could silently strip labels, escalate agent permissions beyond intended scope, or expose issue metadata through overly broad list queries.

### Critical Findings

_None._

This is an internal workspace hygiene task operating on a personal Linear workspace with a single human user and a single agent identity. There is no multi-tenant boundary, no external data ingestion, and no user-facing surface. The threat model is appropriately narrow.

### Important Findings

- **Label replacement race condition as data-loss vector:** The spec correctly warns that `update_issue` replaces the entire label array rather than appending. However, it does not define a defensive pattern beyond "read labels before updating." If two subagents update the same issue concurrently (unlikely given the 15-issue batch cap, but possible if retries overlap), one agent's label read becomes stale and overwrites the other's changes. -> Mitigation: Enforce sequential issue updates within a project (no parallel subagent writes to the same issue). The spec should state this explicitly as a constraint, not just imply it through the batch size.

- **GraphQL delete for CIA-248 bypasses MCP guardrails:** The spec notes that Linear MCP has no delete operation and suggests using raw GraphQL for CIA-248 deletion. This bypasses any permission checks or audit logging built into the MCP layer. If the GraphQL mutation is malformed or targets the wrong issue ID, deletion is irreversible. -> Mitigation: Prefer archive over delete. If delete is required, add a verification step: fetch the issue by ID immediately before the delete mutation, confirm the title matches "Idea Dump Test," and log the full issue payload before executing.

### Consider

- **Token scope audit:** The spec runs ~42 issue updates under an OAuth agent token. Confirm that the `LINEAR_AGENT_TOKEN` has the minimum required scopes (read + write on issues, labels, documents) and does not carry admin-level access (team deletion, workspace settings). This is a good moment to verify least-privilege alignment.

- **Audit trail:** After completion, there is no mechanism to verify what was changed beyond the verification sweep. Consider exporting a before/after snapshot of issue titles and labels for each project (write to a local file) so that unintended changes can be detected and reversed.

### Quality Score (Security Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Auth boundaries | 4 | Single-agent, single-workspace. Agent token is well-scoped. Minor concern on GraphQL bypass. |
| Data protection | 4 | No PII handling. Issue metadata is low-sensitivity. No external exposure. |
| Input validation | 3 | The spec does not define validation for the label arrays being written. A typo in a label name would silently create a new label rather than failing. |
| Attack surface | 5 | No new endpoints, integrations, or external-facing surface introduced. |
| Compliance | N/A | Not applicable -- internal tooling, no regulated data. |

### What the Spec Gets Right (Security)

- Explicitly calls out the destructive nature of `update_issue` (full array replacement) and warns implementers to read-before-write. This is the single most important safety constraint for this task and the spec elevates it appropriately.
- Correctly identifies that the Linear MCP lacks a delete operation and plans an alternative path, rather than assuming the capability exists.
- Clearly demarcates human-owned fields (priority, due dates, cycle assignment) as off-limits, creating a permission boundary even within the agent's technical access scope.

---

## Performance Pragmatist Review: CIA-356

**Scaling Summary:** This is a fixed-scope batch operation over ~42 issues. There is no ongoing runtime, no recurring load, and no user-facing latency. Performance concerns are limited to API rate limits and session duration, both well within safe bounds.

### Critical Findings

_None._

At N=42, there is no scaling cliff. The Linear API can handle hundreds of requests per minute. This task completes in a single session.

### Important Findings

- **Subagent context window pressure:** The spec batches 15 issues per subagent call. Each `get_issue` response (with `includeRelations: true`) can return 1-3KB. At 15 issues, that is 15-45KB of response data per subagent, plus the update payloads. This is within safe limits but approaches the "delegate to subagent" threshold. The spec should confirm that subagent responses are summarized (not raw JSON) to avoid context bloat. -> The constraint is stated (max 15 per agent) but the return format is not specified. Add: "Subagent returns markdown summary table, not raw API responses."

- **Sequential vs. parallel project processing:** The spec processes 4 projects plus unassigned issues. These are independent and could be parallelized across subagents. However, the spec is silent on whether projects are processed sequentially or in parallel. For a 30-45 minute session, sequential processing is fine, but stating the strategy prevents an implementer from accidentally spawning 5 parallel subagents that compete for context. -> Add a brief note: "Process projects sequentially (Phase 0 through Phase 3) to maintain clear progress tracking."

### Consider

- **Verification sweep cost:** Phase 4 queries all active issues across all 4 projects. If this is implemented as 4 separate `list_issues` calls (one per project), that is 4 API calls. If implemented as a single unfiltered query, it could return issues from all 5 workspace projects (including Alteri's ~117 issues), creating unnecessary data transfer. -> Specify: "Verification sweep queries each of the 4 target projects individually, not the full workspace."

### Quality Score (Performance Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Scalability | N/A | Fixed-scope task, not a system. Scaling is not applicable. |
| Resource efficiency | 4 | Batch size of 15 is reasonable. Could waste context if return format is not disciplined. |
| Latency design | N/A | No user-facing latency. Session duration is the relevant metric. |
| Operational cost | 5 | Zero ongoing cost. One-time task with no recurring infrastructure. |
| Failure resilience | 3 | No checkpointing or partial completion strategy defined. If the session crashes at project 3 of 4, there is no record of which projects are already clean. |

### What the Spec Gets Right (Performance)

- The 30-45 minute time estimate is realistic for ~42 issues with read-modify-write cycles. The spec does not underestimate the effort.
- The 15-issue subagent batch cap prevents context window overflow, which is the actual "performance" constraint for an AI agent session.
- Choosing `exec:quick` is correct -- this task does not warrant TDD, pairing, or checkpointing overhead.

---

## Architectural Purist Review: CIA-356

**Structural Summary:** This spec is not building a system -- it is applying a codified maintenance playbook to existing data. The architectural value lies in whether the playbook itself is well-abstracted and whether this execution creates or resolves structural debt in the workspace. The spec is structurally clean for its scope but has a notable gap in how it relates to the source playbook.

### Critical Findings

_None._

This is a data normalization task, not a system design. There are no coupling, contract, or abstraction decisions being made.

### Important Findings

- **Playbook reference is implicit, not explicit:** The spec says "Apply the project cleanup playbook (codified from the Alteri cleanup session in skills/project-cleanup/SKILL.md)" but does not inline or link the specific steps from that playbook. If the playbook evolves between spec authoring and execution, the spec executes a different procedure than intended. -> Either pin the playbook version (git SHA or date snapshot) or inline the critical decision rules (e.g., "An issue is a document candidate if it contains no actionable verb and describes a plan, template, or reference material"). The spec should be self-contained enough to execute without consulting the playbook.

- **Document conversion criteria are undefined:** The spec lists "Document Candidates" in the audit table (templates, plans, 1 session plan) but provides no criteria for when an issue should be converted to a Linear Document versus remaining as an issue. The Alteri cleanup presumably established these criteria, but they are not restated here. -> Add a decision rule: "Convert to Document if the issue describes reference material, a plan with no remaining tasks, or a template. Keep as issue if there is at least one actionable task remaining."

- **Unassigned issue routing lacks decision rationale:** Phase 0 routes 5 issues to specific projects with specific labels, but the routing decisions are presented as facts without justification. For example, why does CIA-218 (Obsidian vault PARA migration) go to Ideas & Prototypes rather than being its own project or going to AI PM Plugin? -> Add a one-line rationale per routing decision. This is important for auditability -- if someone revisits these decisions, they should understand why without re-deriving.

### Consider

- **"Key Resources document" concept is not defined:** The acceptance criteria require "Each project has Key Resources document (or confirmed not needed)" but the spec never defines what a Key Resources document contains, what format it uses, or what distinguishes it from a project description. Is this a Linear Document? A pinned comment? A project description section? -> Define the artifact type and its minimum content (e.g., "A Linear Document titled 'Key Resources: [Project Name]' containing links to the project's primary repository, spec directory, and any relevant external tools").

- **No schema for the "hygiene table":** The verification sweep produces a "Final hygiene table with pass/fail per check per project" but the table schema is not defined. Without a consistent schema, the verification output from this spec cannot be compared to future hygiene sweeps. -> Define the table columns: Project, type:* coverage (pass/fail), bracket prefix count, verb-first compliance (pass/fail), deprecated label count, unassigned issue count.

### Quality Score (Architecture Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Coupling | 4 | Low coupling -- this spec touches only Linear issues and documents, no code systems. Minor coupling to the playbook file. |
| Cohesion | 5 | Single responsibility: normalize workspace conventions. Tightly cohesive. |
| API contracts | 3 | The "contracts" here are the naming/labeling conventions, and they are stated in acceptance criteria but some decision rules are missing (document conversion, routing rationale). |
| Extensibility | 4 | The phased structure (audit, fix, verify) is reusable for future projects. The playbook reference enables repeatability. |
| Naming clarity | 4 | "Normalize conventions" is clear. Issue-level naming rules are well-defined. "Key Resources document" is slightly ambiguous. |

### What the Spec Gets Right (Architecture)

- Referencing a codified playbook (skills/project-cleanup/SKILL.md) rather than ad-hoc cleanup rules is architecturally sound. It treats workspace maintenance as a repeatable process, not a one-off chore.
- The phased execution structure (Route Unassigned -> Per-project cleanup -> Verification sweep) follows a clean pipeline pattern: prepare data, transform data, validate output.
- Separating human-owned fields (priority, due dates, cycles) from agent-owned fields (labels, titles, descriptions) is a clear ownership boundary that prevents scope creep.
- The pre-cleanup audit table establishes a baseline, making the verification sweep meaningful. Before/after comparison is a basic but essential architectural hygiene pattern.

---

## UX Advocate Review: CIA-356

**User Impact Summary:** The "user" of this spec is the human operator (Cian) who will consume the cleaned-up workspace and the AI agent (Claude) who will execute the cleanup. For Cian, the spec improves daily UX by eliminating inconsistencies that create cognitive friction when scanning issue lists. For Claude, the spec is mostly clear but has a few ambiguities that could cause execution hesitation.

### Critical Findings

_None._

This spec improves workspace UX by definition -- its entire purpose is to reduce friction from inconsistent naming, missing labels, and misrouted issues.

### Important Findings

- **No "before" visibility for the human stakeholder:** The spec includes a pre-cleanup audit table, but it is a snapshot in the spec document, not a runtime artifact. Cian has no way to review the planned changes before they are executed. For a workspace with 42 issues, a "dry run" report showing proposed changes (old title -> new title, labels to add/remove, project reassignments) would let Cian catch errors before they propagate. -> Add a Phase 0.5: Generate a change preview document listing all planned modifications, and pause for human approval before executing. This is especially important for the document conversion decisions, which involve judgment calls.

- **Verification sweep output has no defined destination:** The spec says "Report: Final hygiene table with pass/fail per check per project" but does not specify where this report is written or presented. Is it a Linear comment? A terminal output? A file? If it is only in the session transcript, it is effectively invisible to Cian after the session ends. -> Specify: "Write the verification report as a Linear Document titled 'Hygiene Report: CIA-356' in the AI PM Plugin project."

### Consider

- **Title normalization examples would reduce ambiguity:** The acceptance criteria say "verb-first, lowercase after first word" but provide no examples of the transformation. What does `[SDD] Build marketplace integration` become? `Build marketplace integration`? `Build SDD marketplace integration`? Concrete before/after examples for 2-3 titles from the audit would remove guesswork. -> Add to the spec: "Example: `[SDD] Build X` -> `Build X`. `Document security findings` -> `Document security findings` (already compliant)."

- **The phrase "confirmed not needed" for Key Resources documents is ambiguous:** Who confirms? Is it Claude making a judgment call and recording it, or is it Cian making the decision? If Claude decides a project does not need a Key Resources document, the rationale should be recorded (e.g., "Cognito SoilWorx: No Key Resources document needed -- project has fewer than 5 active issues and no external dependencies"). -> Specify the confirmation mechanism and where the rationale is recorded.

- **No rollback plan:** If the cleanup introduces errors (wrong labels, wrong project assignments), there is no documented way to undo the changes. Linear does not have bulk undo. -> At minimum, export the current state of all 42 issues (title, labels, project, status) to a local JSON file before making changes. This serves as both an audit trail and a manual rollback reference.

### Quality Score (UX Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| User journey | 3 | The agent's journey is clear (phases 0-4). The human stakeholder's journey (review, approve, verify) is underdefined. |
| Error experience | 2 | No rollback plan. No dry-run preview. If something goes wrong, recovery is manual and painful. |
| Cognitive load | 4 | The phased structure is easy to follow. The checklist format is scannable. |
| Discoverability | 3 | The verification report destination is unspecified. Post-cleanup, Cian needs to know where to look to confirm success. |
| Accessibility | N/A | Not applicable -- this is a backend data normalization task with no UI. |

### What the Spec Gets Right (UX)

- The spec's entire purpose is a UX improvement: consistent naming, complete labeling, and correct routing directly reduce the cognitive load of scanning Linear issue lists.
- The pre-cleanup audit table gives the implementer a clear mental model of the current state and the scope of changes needed.
- The constraint "DO NOT modify priority, due dates, cycle assignment" protects the human user's mental model -- these are the fields Cian uses for personal planning, and changing them would be disorienting.
- The verification sweep as a mandatory final phase ensures the human stakeholder can trust the output, not just the process.

---

## Combined Panel Summary

### Panel Agreement (all 4 reviewers concur)

1. **The spec is appropriate for its scope.** All four reviewers agree that `exec:quick` is the correct execution mode and that the 30-45 minute estimate is realistic. No reviewer finds a blocking issue.

2. **The `update_issue` label replacement warning is essential.** All reviewers acknowledge this as the spec's most important safety constraint. It is well-placed and well-stated.

3. **Human-owned field boundaries are correctly drawn.** The separation of agent-writable fields (labels, titles, descriptions) from human-owned fields (priority, due dates, cycles) is praised by Security (permission boundary), Architecture (ownership boundary), and UX (mental model protection).

4. **The playbook reference is a strength.** All reviewers recognize that codifying the cleanup process as a reusable skill (SKILL.md) is the right approach, though the Architectural Purist wants the key decision rules inlined.

### Panel Disagreement / Tension Points

| Topic | Position A | Position B |
|-------|-----------|-----------|
| **Dry-run preview** | UX Advocate (Important): Produce a change preview for human approval before execution. | Performance Pragmatist (implicit): Adding a preview phase doubles the API calls and session duration for a low-risk task. At N=42, the cost is marginal, but the principle matters. |
| **Rollback / audit snapshot** | UX Advocate + Security Skeptic: Export current state before making changes. | Performance Pragmatist: For a single-session, single-operator workspace, this is overhead that will never be used. The verification sweep is sufficient. |
| **GraphQL delete for CIA-248** | Security Skeptic (Important): Bypasses MCP guardrails; prefer archive. | Architectural Purist (implicit): If the issue is truly dead (Done, test data), delete is the correct semantic operation. Archive pollutes the workspace with noise. |
| **Playbook inlining** | Architectural Purist (Important): Inline critical decision rules so the spec is self-contained. | Performance Pragmatist (implicit): The playbook exists and is version-controlled. Duplicating it creates a maintenance burden. Reference is sufficient. |

### Consolidated Recommendations (ordered by impact)

1. **Define the verification report destination** (UX + Architecture): Specify that the final hygiene table is written as a Linear Document, not just terminal output.
2. **Add document conversion decision rules** (Architecture): One sentence defining when an issue becomes a Document.
3. **Export before-state snapshot** (Security + UX): Write current issue metadata to a local file before execution begins. Low cost, high insurance value.
4. **Specify subagent return format** (Performance): "Subagent returns markdown summary table, not raw JSON."
5. **Add routing rationale for Phase 0** (Architecture): One-line justification per unassigned issue routing decision.
6. **Clarify "Key Resources document" format** (Architecture + UX): Define the artifact type and minimum content.

### Overall Panel Verdict

**APPROVE with minor revisions.** The spec is clear, appropriately scoped, and ready for execution. The six recommendations above would strengthen it but none are blockers. The highest-priority addition is defining where the verification report lands (recommendation 1) -- without it, the spec produces work that cannot be audited after the session ends.
