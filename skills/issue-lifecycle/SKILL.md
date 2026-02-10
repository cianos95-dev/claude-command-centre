---
name: issue-lifecycle-ownership
description: |
  Agent/human ownership model for issue management. Defines who owns which actions on issues (status, labels, priority, estimates, closure), closure rules matrix, session hygiene protocols, and spec lifecycle labels. The most critical skill for agent autonomy boundaries.
  Use when determining what the agent can change vs what requires human approval, closing issues, updating issue status, managing labels, or handling session-end cleanup.
  Trigger with phrases like "can I close this issue", "who owns priority", "issue ownership rules", "session cleanup protocol", "what labels should I set", "closure evidence requirements".
---

# Issue Lifecycle Ownership

AI agents and humans have complementary strengths in issue management. This skill defines clear ownership boundaries so the agent acts autonomously where appropriate and defers where human judgement is required. The goal is maximum agent autonomy within safe, well-defined rails.

## Core Principle

The agent owns **process and implementation artifacts** (status, labels, specs, estimates). The human owns **business judgement** (priority, deadlines, capacity). Either can create and assign work. Closure follows a rules matrix based on assignee and complexity.

## Ownership Table

| Action | Owner | Rationale |
|--------|-------|-----------|
| Create issue | Either | Agent creates from plans, specs, or discovered work. Human creates ad hoc or from external input. |
| Status to In Progress | Whoever starts work | Agent marks as soon as implementation begins. Human marks for manual work. Never batch -- update immediately when work starts. |
| Status to Done | Agent (auto-close per rules) | Only when: agent is assignee + single PR + merged + deploy green. See closure rules below. |
| Status to Done (propose) | Agent proposes, human confirms | For human-owned issues, multi-PR efforts, pair work, or research tasks. Agent provides evidence, waits for confirmation. |
| Status to Todo/Backlog | Agent during triage | After planning sessions, during batch status normalization. |
| Add/remove labels | Agent | Labels are programmatic workflow markers, not human-facing metadata. Agent maintains label hygiene. |
| Update description/spec | Agent | Spec content is the agent's domain. Agent keeps specs current as understanding evolves. |
| Assign/delegate | Either | Agent assigns to self or proposes assignment. Human assigns based on capacity or expertise. |
| Set priority | Human | Priority reflects business value, stakeholder urgency, and strategic context that only humans can assess. |
| Set estimates | Agent | The implementer owns complexity assessment. Estimates inform execution mode selection. |
| Set due dates | Human | Due dates represent commitments to stakeholders. Only humans make commitments. |
| Assign to cycle/sprint | Human | Capacity planning requires awareness of team bandwidth, competing priorities, and external constraints. |
| Close stale items | Agent proposes, human confirms | Never auto-close without evidence. Agent surfaces candidates with rationale; human decides. |

## Closure Rules Matrix

Closure is the highest-stakes status transition. These rules prevent premature closure while allowing full agent autonomy for clear-cut cases.

| Condition | Action | Rationale |
|-----------|--------|-----------|
| Agent assignee + single PR + merged + deploy green | **Auto-close** with comment | Agent owns the issue end-to-end. Merge is the quality gate. Deploy green confirms no regression. Include PR link in closing comment. |
| Agent assignee + multi-PR issue | **Propose** closure with evidence | Multi-PR efforts are complex enough to warrant human sign-off. List all PRs and their status. |
| Agent assignee + `needs:human-decision` label | **Propose** closure: "Appears complete, shall I close?" | A human decision is explicitly pending. Agent cannot resolve it unilaterally. |
| Issue assigned to human (not agent) | **Never** auto-close | Human-owned issues are closed by humans. Agent may comment with completion evidence but must not change status. |
| `exec:pair` label | **Propose** with evidence | Shared ownership requires explicit sign-off from the human participant. |
| No PR linked (research/design/planning) | **Propose** with deliverable summary | No merge trigger exists. Agent summarizes what was delivered (document, decision, analysis) and asks for closure confirmation. |

**Every Done transition requires a closing comment.** The comment must include evidence: PR link, deliverable reference, decision rationale, or explicit human confirmation. Status changes without evidence are not permitted.

## Session Hygiene

### Mid-Session Rules

- **Mark In Progress immediately** when work begins on an issue. Do not wait until the work is complete to update status. The issue tracker should reflect reality at all times.
- **Update labels in real-time** as understanding evolves. If an issue turns out to need `exec:checkpoint` instead of `exec:quick`, change the label as soon as you realize it.
- **Do not batch status updates.** Each status change should happen at the moment the transition occurs, not at the end of a session.

### Session Exit Protocol

At the end of every work session, perform status normalization:

1. Review all issues touched during the session
2. Ensure every issue reflects its true current state
3. Add closing comments to any issues marked Done (with evidence)
4. Issues that are partially complete remain In Progress with a comment describing current state and next steps
5. Issues that were started but blocked get a comment explaining the blocker

### Re-open Protocol

If a human re-opens a closed issue within 48 hours:

1. Acknowledge the premature closure in a comment
2. Review what was missed or incomplete
3. Adjust approach based on the feedback
4. Do not re-close without addressing the reason for re-opening

This is a signal to calibrate. If premature closures happen repeatedly, tighten the closure criteria (e.g., require human confirmation for all closures in that project for a period).

## Spec Lifecycle Labels

Specs progress through a defined lifecycle. Apply these labels to track where a spec stands:

| Label | State | Description |
|-------|-------|-------------|
| `spec:draft` | Authoring | Initial spec being written. May be incomplete, have open questions, or lack acceptance criteria. |
| `spec:ready` | Review-ready | Spec is complete enough for adversarial review. All sections filled, acceptance criteria defined. |
| `spec:review` | Under review | Adversarial review in progress. Reviewer is actively challenging assumptions, finding gaps. |
| `spec:implementing` | In development | Spec passed review and implementation has begun. Spec content is now the source of truth for the implementer. |
| `spec:complete` | Delivered | Implementation matches spec. Acceptance criteria met. Spec is now documentation. |

**Transition rules:**
- `draft` to `ready`: Agent or human asserts completeness
- `ready` to `review`: Reviewer (agent or human) begins adversarial review
- `review` to `implementing`: Review passes with no blocking issues. Minor issues can be noted for implementation.
- `review` to `draft`: Review reveals fundamental gaps. Spec returns for rework.
- `implementing` to `complete`: All acceptance criteria verified. Tests pass. Deployment confirmed.

**Spec labels coexist with execution mode labels.** An issue can be both `spec:implementing` and `exec:tdd`. The spec label tracks the document lifecycle; the execution label tracks the implementation approach.

## Applying This in Practice

When working with `~~project-tracker~~`:

1. **Issue creation:** Set initial status, apply `spec:draft` if a spec is needed, assign to agent or human
2. **Triage:** Agent evaluates scope, applies `exec:*` label, sets estimate
3. **Implementation start:** Agent moves to In Progress immediately, applies `spec:implementing` if applicable
4. **Completion:** Follow the closure rules matrix. Always include evidence in the closing comment.
5. **Session end:** Run the normalization protocol across all touched issues

The ownership model scales from solo agent work to multi-agent teams. In multi-agent setups, each agent follows these same rules for issues assigned to it, and proposes closure for issues assigned to other agents.

## Scope Limitation Handoff Protocol

When the agent encounters an action it cannot perform due to OAuth scope limitations, API restrictions, or ownership rules that require human execution, follow this protocol instead of silently skipping the action:

### When This Applies

- API operations requiring scopes the agent token does not have (e.g., creating initiatives, modifying workspace settings)
- Actions explicitly owned by humans per the ownership table (e.g., setting priority, assigning to cycles)
- Platform operations that require UI interaction (e.g., enabling integrations, configuring webhooks)
- Any destructive or irreversible action the agent is not authorized to perform

### The Handoff Pattern

1. **Output the exact content needed.** Write the complete text, configuration, or values the human needs to enter. Do not summarize or abbreviate -- provide copy-paste-ready content.
2. **State the specific action required.** Name the platform, the UI location, and the exact steps (e.g., "In Linear > Settings > Initiatives > Create New").
3. **Document what was output.** Add a comment to the relevant `~~project-tracker~~` issue recording that a handoff was made, what content was provided, and what action the human needs to take.
4. **Do not block on completion.** Continue with other tasks. The handoff is asynchronous -- the human will complete it when they can.

### Example

```
## Scope Limitation Handoff

**Action needed:** Create a Linear initiative (requires OAuth scope `initiative:read/write` which the agent token does not have)

**Where:** Linear > Initiatives > Create New

**Content to enter:**
- Name: [exact name]
- Status: Active
- Owner: [person]
- Description: [exact text]
- Projects linked: [project names]

**Documented on:** [issue ID] — comment added with handoff details
```

This pattern ensures no work is lost when the agent hits a capability boundary. The human receives a complete, actionable handoff rather than a vague request.
