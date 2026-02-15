# Adversarial Review: CIA-379 -- Multi-Agent Orchestration: Master Plan

**Reviewer:** Claude Opus 4.6 (generic mode, no SDD plugin augmentation)
**Date:** 2026-02-15
**Spec type:** Master plan / consolidation issue
**Recommendation:** REVISE

---

## Critical Findings

### C1: No acceptance criteria whatsoever

The spec contains zero acceptance criteria. A master plan that consolidates multiple workstreams must define what "done" looks like for the plan itself. Without acceptance criteria, there is no testable gate for completion, no way to know when Phase 3 is finished, and no definition of what success means for the overall consolidation effort. Every sub-issue might succeed individually while the orchestration goal fails.

**Blocks implementation because:** Implementers and the PM have no shared definition of completion. Phase 3 especially ("n8n + CIA-317 + CIA-326 + CIA-260 + CIA-270") has no stated outcome -- it is just a list of issue IDs with no description of what they collectively achieve.

**Suggested resolution:** Add a "Done When" section with 3-5 measurable outcomes for the master plan as a whole, e.g., "All source labels route to a designated agent within N seconds," "Agent handoff protocol documented and tested for all 5 intake sources," etc.

### C2: No problem statement or press release

The spec jumps directly into workstreams and sequencing without ever stating the problem it solves. The PR/FAQ methodology requires a press release of at most one page and a problem statement that does not mention the solution. This spec has neither. Without a problem statement, it is impossible to evaluate whether the proposed workstreams actually address the right problem or whether they are a collection of loosely related issues grouped by convenience.

**Blocks implementation because:** Reviewers and implementers cannot assess whether the proposed work is necessary, sufficient, or correctly scoped without understanding the problem it addresses.

**Suggested resolution:** Add a one-paragraph problem statement (what pain exists today, who experiences it, what the cost of inaction is) and a brief press release framing what the completed orchestration system enables.

### C3: No pre-mortem or failure modes

The reviewer methodology requires checking that the pre-mortem covers realistic failure modes. This spec contains no pre-mortem section at all. A multi-agent orchestration system has significant failure modes: agent conflicts (two agents acting on the same issue), dropped intake (a source label produces no routing), incorrect routing (voice input dispatched to the wrong agent), cascading failures across workstreams, and Linear API rate limits when multiple agents operate simultaneously.

**Blocks implementation because:** Without identified failure modes, the implementation will discover these problems reactively. Multi-agent systems are especially failure-prone at integration boundaries.

**Suggested resolution:** Add a pre-mortem with at least 3 failure modes, their likelihood, impact, and mitigation strategy. Focus on inter-agent coordination failures, intake routing errors, and the risk of the system degrading silently (no observability on agent actions).

---

## Important Findings

### I1: Routing table is incomplete and has no fallback logic

The "Draft Intake to Agent Routing Table" has a "TBD" entry for `source:vercel-comments` and lacks any fallback routing. What happens when:
- A new source label is added that has no routing entry?
- The designated agent is unavailable or fails?
- An issue matches multiple source labels?
- An issue has no source label at all?

**Impact:** The routing table as specified will silently fail for edge cases, producing unrouted issues that no one acts on.

**Suggested resolution:** Add a default/fallback route (likely Cian for triage). Specify conflict resolution when multiple labels apply. Resolve the TBD for `source:vercel-comments` -- either assign it now or explicitly defer it with a blocking issue ID.

### I2: Phase dependencies and blocking relationships are underspecified

The sequencing section lists phases but does not clarify all dependencies:
- Can Phase 2A (CIA-383 Cursor Pro config) start before Phase 1B completes? The numbering suggests yes, but no explicit dependency statement exists.
- Phase 3 bundles four issues together (CIA-317, CIA-326, CIA-260, CIA-270) with no internal ordering. Are they independent? Must they be done sequentially?
- Phase 1A is blocked on Cian. What is the escalation path if this block persists for weeks? Is there work that can proceed in parallel?

**Impact:** Without clear dependency modeling, work may stall unnecessarily or proceed in an order that creates rework.

**Suggested resolution:** Add a dependency diagram (Mermaid, per standards) or at minimum a textual dependency chain. For each blocked item, specify the unblocking condition and an escalation timeline.

### I3: "Plugin Capture" section has no structure

"Every phase produces learnings that inform the SDD plugin. After each phase, add a 'Plugin Implications' section to the phase sub-issue." This instruction is vague. What constitutes a "learning"? Who is responsible for writing the Plugin Implications section? What happens if a phase produces no plugin-relevant learnings -- is that explicitly noted, or silently skipped? Without structure, this will be forgotten by Phase 2.

**Impact:** The feedback loop from orchestration work to plugin development will be inconsistent and likely abandoned after Phase 1.

**Suggested resolution:** Define a lightweight template for the Plugin Implications section (e.g., "Pattern observed / Applicable to plugin as / Priority"). Assign ownership (Claude or Cian). Add a checklist item to each phase sub-issue.

### I4: No estimate or timeline

The spec provides no time estimates for any phase or workstream. The SDD methodology states that Claude owns estimates (complexity to execution mode selection). Without estimates, cycle planning is impossible, and there is no way to detect if the plan is falling behind.

**Impact:** The master plan cannot be used for capacity planning or sprint allocation.

**Suggested resolution:** Add rough estimates per phase (T-shirt sizes at minimum: S/M/L). Map to execution modes. Indicate which phases fit in a 1-week cycle.

### I5: WS-3 documentation workstream is a grab-bag with no cohesion

WS-3 bundles CIA-317, CIA-326, CIA-260, and CIA-270 under "Documentation & codification." Without descriptions of what these issues contain, the workstream appears to be a catchall for issues that did not fit elsewhere. The spec provides no rationale for why these four issues belong together or what their collective output is.

**Impact:** WS-3 will be treated as low-priority housekeeping and likely deferred indefinitely.

**Suggested resolution:** Add a one-line description of each issue in WS-3. State the deliverable for the workstream as a whole (e.g., "All agent interaction patterns documented in the SDD plugin's agent standards").

### I6: v1.3.0 Agent Reference Implementation section is informational, not actionable

The section about SDD plugin v1.3.0 establishing 3 reference agents reads as a historical note rather than a requirement. It is unclear whether this section imposes constraints on CIA-379's implementation (e.g., "all agents defined in this plan must use the agent frontmatter standards") or is simply context.

**Impact:** Ambiguity about whether new agents created through this plan must follow the v1.3.0 pattern could lead to inconsistent agent definitions.

**Suggested resolution:** Either promote this to a constraint ("All agents defined through workstreams WS-1 and WS-2 MUST use plugin-dev agent frontmatter standards as established in v1.3.0") or move it to a background/context section with explicit framing.

---

## Consider

### M1: Triage history adds noise

The "Triage History" section is a changelog, not a spec element. It records decisions already made and executed (CIA-400 cancelled, CIA-397 cancelled, etc.). While useful for audit purposes, it obscures the active content of the spec. Consider moving it to a collapsible section, a Linear comment, or a separate Linear document.

### M2: Session Continuation section is ephemeral

"Phase 0 complete. Phase 1A blocked on Cian. Phase 1C complete. Next: Phase 1B (CIA-382), Phase 2A (CIA-383), Phase 3 WS-3 documentation." This is a session handoff note, not a spec element. It will become stale after one session. Consider maintaining this state in the workstream status column of the table instead of as a separate section.

### M3: No observability or monitoring plan

For a multi-agent orchestration system, there is no mention of how to observe agent behavior, detect routing failures, or audit agent actions. This aligns with the Honeycomb/OTEL stack mentioned in the broader workspace but is not referenced here. Consider adding a "Monitoring" requirement, even if deferred to a sub-issue.

### M4: No rollback or degradation strategy

If the orchestration layer introduces problems (e.g., agents acting on issues they should not), there is no stated way to disable it and fall back to manual routing. Consider defining a "kill switch" or graceful degradation path.

---

## Quality Score

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Completeness | 2 | Missing problem statement, acceptance criteria, pre-mortem, estimates, dependency model. Has workstream structure and routing table draft but both are incomplete. |
| Clarity | 3 | Workstream table and phase sequencing are clearly formatted. Issue references are specific. However, WS-3 contents are opaque (issue IDs without descriptions) and the routing table has a TBD. |
| Testability | 1 | Zero testable acceptance criteria. No definition of done for the master plan or individual phases. No measurable outcomes stated anywhere. |
| Feasibility | 3 | The proposed workstreams are individually reasonable and the phased approach is sound. However, without dependency modeling and estimates, feasibility of the overall plan within realistic timelines cannot be assessed. The routing table concept is straightforward. |
| Safety | 2 | No pre-mortem, no failure modes, no rollback strategy, no monitoring plan. Multi-agent systems have significant safety surface area (agents acting on wrong issues, conflicting actions, silent failures) that is entirely unaddressed. |

**Overall: 2.2 / 5**

---

## What Works Well

- **Workstream structure is sound.** Grouping issues into WS-0 through WS-3 by functional area (label hygiene, intake, multi-agent ecosystem, documentation) is a logical decomposition. The status column in the workstream table provides clear visibility into progress.

- **Phase sequencing shows pragmatic ordering.** Starting with label hygiene (WS-0), then building intake routing before multi-agent work, demonstrates correct dependency thinking even if it is not fully formalized.

- **Routing table is a valuable artifact.** Despite being incomplete, the intake-to-agent routing table is the right abstraction for this problem. It makes the routing logic explicit and reviewable rather than implicit in code or configuration.

- **Triage discipline is evident.** The triage history shows active issue management -- cancelling, merging, and completing issues rather than letting them accumulate. This is good PM hygiene.

- **Plugin capture feedback loop is the right instinct.** Recognizing that orchestration work will produce learnings for the SDD plugin and building in a capture mechanism (even if underspecified) shows systems thinking.

---

## Summary

CIA-379 has the skeleton of a good master plan -- clear workstream decomposition, pragmatic phasing, and a useful routing table draft. However, it reads more as a project management tracking document than an implementable spec. It is missing the foundational elements that the SDD methodology requires: a problem statement, acceptance criteria, pre-mortem, and estimates. The most concerning gap is testability -- there is no way to know when this plan is "done" or whether it has succeeded.

The recommendation is **REVISE**: return to draft and address all three critical findings before proceeding. The important findings should be addressed concurrently but are not individually blocking.
