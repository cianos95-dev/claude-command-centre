---
name: issue-lifecycle-ownership
description: |
  Agent/human ownership model for issue and project management. Defines who owns which actions on issues (status, labels, priority, estimates, closure) and projects (summary, description, updates, resources). Includes closure rules matrix, session hygiene protocols, spec lifecycle labels, project hygiene protocol with staleness detection, and daily update format.
  Use when determining what the agent can change vs what requires human approval, closing issues, updating issue status, managing labels, handling session-end cleanup, maintaining project descriptions, posting project updates, or managing project resources.
  Trigger with phrases like "can I close this issue", "who owns priority", "issue ownership rules", "session cleanup protocol", "what labels should I set", "closure evidence requirements", "project description stale", "post project update", "add resource to project", "update project summary".
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

## Carry-Forward Items Protocol

When adversarial review findings or implementation tasks cannot be fully resolved within the current issue's scope, they must be explicitly tracked rather than silently dropped.

### When This Applies

- Adversarial review findings rated **Important** or **Consider** that are deferred during implementation
- Implementation discoveries that reveal work outside the current issue's scope
- Technical debt identified during implementation that is not blocking

### The Protocol

1. **Create a new issue** for each carry-forward item (or group closely related items into one issue)
2. **Link the new issue** as "related to" the source issue using ~~project-tracker~~ relations
3. **Reference the source** in the new issue description: "Carry-forward from CIA-XXX adversarial review finding I3"
4. **Add the carry-forward item** to the fix-forward summary in the source issue's closing comment (see adversarial-review skill)
5. **Apply appropriate labels** to the new issue (`spec:draft` if it needs a spec, or appropriate exec mode if scope is clear)

### What NOT to Do

- Do not leave findings untracked in a review document without corresponding issues
- Do not close the source issue without documenting what was deferred and where
- Do not add carry-forward items to the source issue's own scope (this causes scope creep and blocks closure)

## Issue Content Discipline

Issue comments, descriptions, sub-issues, and resources each serve a distinct purpose. Using the wrong container for content creates clutter and makes issues hard to navigate.

### Where Content Belongs

| Content Type | Container | Why |
|---|---|---|
| Status updates, @mentions, decisions | **Comments** | Comments are a chronological conversation thread. Keep them for communication, not data storage. |
| Evidence tables, audit findings, detailed analysis | **Resources** (documents or linked files) | Rich content belongs in a document. Link from the description. |
| Plans, specs, research from repos | **Resources** (linked to repo files or Linear documents) | Repo artifacts are the source of truth. Resources point to them. |
| New work discovered during implementation | **Sub-issues** | Sub-issues maintain parent-child traceability. Never add scope to the parent issue. |
| Session orchestration for batched work | **Master session plan issue** (parent) | When multiple sessions or sequential issues form a batch, create a parent issue that tracks the overall plan. Sub-issues represent individual sessions or steps. |

### Anti-Patterns

- **Comment dumping**: Do not write evidence tables, credential audits, or spec content as comments. Comments get buried in the thread and are not searchable or linkable.
- **Orphan work items**: Do not track new work discovered during implementation as informal notes. Create sub-issues immediately.
- **Implicit session plans**: When you identify a sequence of sessions (e.g., "Session 1: merge PR, Session 2: add Mailchimp, Session 3: add geo"), create a master plan issue with sub-issues. Do not leave the orchestration implicit in a plan file or conversation.

### Master Session Plan Pattern

When a project phase involves multiple sequential or parallel sessions:

1. **Create a parent issue** titled "Session Plan: [Phase/Feature Name]"
2. **Create sub-issues** for each session, with blocking relationships reflecting the execution order
3. **Update the parent description** with the overall plan, linking to sub-issues
4. **As sessions complete**, close sub-issues with evidence and update the parent with progress notes
5. **Close the parent** when all sub-issues are complete

This pattern replaces ad-hoc session planning in plan files or conversation context, making the plan visible and trackable in the ~~project-tracker~~.

## Applying This in Practice

When working with `~~project-tracker~~`:

1. **Issue creation:** Set initial status, apply `spec:draft` if a spec is needed, assign to agent or human
2. **Triage:** Agent evaluates scope, applies `exec:*` label, sets estimate
3. **Implementation start:** Agent moves to In Progress immediately, applies `spec:implementing` if applicable
4. **Completion:** Follow the closure rules matrix. Always include evidence in the closing comment.
5. **Session end:** Run the normalization protocol across all touched issues

The ownership model scales from solo agent work to multi-agent teams. In multi-agent setups, each agent follows these same rules for issues assigned to it, and proposes closure for issues assigned to other agents.

## Issue Naming Convention

Every issue title must follow these rules:

### Verb-First, No Brackets

Issue titles start with an action verb, lowercase after first word. No bracket prefixes.

| Pattern | Correct | Incorrect |
|---------|---------|-----------|
| Feature | `Build avatar selection UI component` | `[Feature] Avatar Selection UI` |
| Research | `Survey limerence measurement instruments` | `[Research] Limerence Instruments` |
| Infrastructure | `Configure Supabase pgvector` | `[Infrastructure] Supabase pgvector` |

**Common verb starters:** Build, Implement, Fix, Add, Create, Evaluate, Survey, Design, Migrate, Configure, Audit, Ship, Set up, Wire up

### Reference Content Goes to Documents

Non-actionable content (research notes, decisions, session learnings) should be Linear Documents, not issues. Apply the "Can someone mark this Done?" test — if no, it's a Document.

See the `project-cleanup` skill for the full Content Classification Matrix.

## Project Hygiene Protocol

Projects are the container that gives issues strategic context. A well-maintained project makes milestone progress visible, keeps descriptions honest, and ensures new contributors (or future sessions) can orient quickly. This section defines what the agent maintains at the project level.

### Project Artifacts

| Artifact | Purpose | Cadence | Owner |
|----------|---------|---------|-------|
| **Summary** | One-line elevator pitch visible in project lists | On creation, rename, or major pivot | Agent |
| **Description** | Living document: milestone map, delineation table, hygiene rules, decision log | When milestones added/completed/restructured | Agent |
| **Resources** | Links to repo, specs, key docs, insights reports | When new key artifacts ship | Agent |
| **Project Update** | Daily status: what changed, what's next, health signal | End of each active working session | Agent |
| **Milestone progress** | Issue completion percentages | Automatic (on issue status change) | Agent (auto) |

### Project Description Structure

Every project description should contain these sections (adapt as needed):

1. **Opening line** — What this project is, in one sentence
2. **Repo link** — Clickable link to source code
3. **Milestone Map** — Table showing all milestones, their focus, and dependencies
4. **Delineation** — What's shareable/public vs personal/temporal (for plugin projects)
5. **Hygiene Protocol** — Cadence table (copy from this skill, configure per project)
6. **Decision Log** — Date + decision + context for major choices

### Staleness Detection Rule

The agent must check for project description staleness using these triggers:

| Trigger | Action |
|---------|--------|
| `updatedAt` on description is >14 days old AND any milestone has new Done issues | Flag "Project description may be stale" and propose an update |
| Milestone count changes (added or removed) | Update description in same session |
| Project renamed | Update summary and description opening line in same session |
| Major pivot or restructuring | Rewrite description; add entry to decision log |

**Configuration for plugin users:** The staleness threshold (default: 14 days) and trigger conditions should be documented in the project description itself so the agent knows what rules to follow for each project. Projects with daily active development may use 7 days; maintenance projects may use 30 days.

### Daily Project Update Format

```markdown
# Daily Update — YYYY-MM-DD

**Health:** On Track | At Risk | Off Track

## What happened today
- [Grouped by theme: milestone work, triage, infra, etc.]
- [Reference issue IDs for traceability]

## What's next
- [Immediate next actions for the next session]
- [Any blockers or decisions needed]
```

**Rules:**
- Post at end of each working session where issue statuses changed
- Skip if no issue status changes occurred (no empty updates)
- Create as a Linear document attached to the project (titled "Project Update — YYYY-MM-DD")
- Health signal: "On Track" if milestone progress is positive, "At Risk" if blockers exist, "Off Track" if milestone is overdue
- Keep updates concise — 3-5 bullets per section maximum

### Resource Management

Resources are added as a Linear document attached to the project. Maintain a single "Key Resources" document with sections for:

- Source code repositories
- Specs and plans (with local file paths or URLs)
- Insights reports and archives
- Methodology references
- Linear navigation references (team, prefix, milestone names)

**Update rule:** When a new key artifact is created (new spec, new plan, new insights report), add it to the resources document in the same session. Do not create separate resource documents per artifact.

### Applying Project Hygiene

When the agent completes any of these actions, it should check the project hygiene checklist:

1. **Created a milestone** → Update project description milestone map
2. **Completed a triage/routing session** → Post daily update, update description if structure changed
3. **Shipped a key deliverable** → Add to resources document
4. **Renamed or pivoted a project** → Update summary + description + decision log
5. **End of any session with status changes** → Post daily update

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
