# Adversarial Panel Review: CIA-379 — Multi-Agent Orchestration Master Plan

**Reviewed by:** 4-persona adversarial panel
**Date:** 2026-02-15
**Spec type:** Master plan (consolidation + sequencing)

---

## Security Skeptic Review: CIA-379

**Threat Model Summary:** This spec routes sensitive inputs (voice recordings, code context, Vercel user comments) through multiple AI agents with varying trust levels, yet defines zero authentication boundaries, no credential isolation between agents, and no audit trail for agent-to-agent delegation.

### Critical Findings

- **No agent authentication or authorization model:** The routing table dispatches work to Claude, Cursor, and unspecified future agents without defining how agents authenticate to each other or to Linear/GitHub. If one agent's token is compromised (e.g., Cursor's OAuth), the attacker inherits its full dispatch privileges. -> Define per-agent credential scoping. Each agent should have a dedicated service account with least-privilege permissions. Document which APIs each agent can call and enforce at the routing layer.

- **Voice intake pipeline has no input sanitization spec:** CIA-381 (Whispr Flow) ingests raw voice input for "spec extraction." Voice-to-text output is unstructured user input passed directly into spec creation flows. This is a prompt injection vector — a user (or attacker with mic access) could dictate content that manipulates Claude's spec-writing behavior. -> Define a sanitization boundary between transcription output and spec generation. Treat transcribed text as untrusted user input, not as instructions.

- **`source:vercel-comments` routing is TBD with no threat assessment:** Vercel comments are public-facing user input being routed to an AI agent for code changes. This is a direct path from unauthenticated external input to code modification. -> Before routing Vercel comments to any agent, define: Who can trigger this flow? Is there human approval before code changes? What prevents a malicious comment from generating a harmful PR?

### Important Findings

- **No audit log for agent actions:** The spec defines which agent handles which source but provides no observability into what each agent did, what data it accessed, or what outputs it produced. If an agent misbehaves or is compromised, there is no forensic trail. -> Require every agent action to be logged to a central audit system with: timestamp, agent identity, input source, action taken, output destination.

- **Token/credential management unspecified across agents:** The spec references Claude (OAuth agent token), Cursor Pro, v0, and n8n. Each presumably has its own credentials. The spec does not define where these credentials are stored, how they are rotated, or whether they are shared across environments. -> Reference the existing Keychain strategy from CLAUDE.md and extend it to cover all agents in the ecosystem. Define rotation schedules.

- **@claude mentions MVP (CIA-382) has no scope restriction:** Mentioning @claude in Linear comments to trigger agent behavior is a powerful capability with no guardrails defined. Who can @mention Claude? What actions can a mention trigger? Can it modify issues, close issues, push code? -> Define an explicit allowlist of actions that @claude mentions can trigger. Require confirmation for destructive or high-impact operations.

### Consider

- **Plugin Capture as an information leak vector:** Each phase produces "Plugin Implications" sections. If these contain operational details (API patterns, auth flows, error handling strategies), publishing them in a plugin ecosystem exposes internal architecture to potential attackers. Vet plugin implications for information disclosure before publishing.

- **Agent roster is open-ended:** The spec mentions "various 3rd party AI assistants" without bounding the set. Each new agent added to the ecosystem increases attack surface. Define an agent onboarding checklist that includes a security review before granting any agent access to the workspace.

### Quality Score (Security Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Auth boundaries | 1 | No agent-to-agent auth model defined. No per-agent permission scoping. |
| Data protection | 2 | Voice and comment data flow through agents with no data handling spec. PII in voice transcripts unaddressed. |
| Input validation | 1 | Voice input and Vercel comments are untrusted inputs routed to agents with no sanitization boundary. |
| Attack surface | 2 | Every new agent and source label expands attack surface. No bounding strategy. |
| Compliance | 1 | Voice recording storage, transcription data retention, PII handling — none addressed. |

### What the Spec Gets Right (Security)

- The routing table makes agent assignments explicit rather than implicit, which is the necessary first step toward enforceable boundaries.
- Acknowledging that `source:vercel-comments` routing is TBD is better than prematurely assigning it without a threat model.
- Phased rollout limits blast radius — breaking the work into WS-0 through WS-3 means security can be layered in incrementally rather than retrofitted.

---

## Performance Pragmatist Review: CIA-379

**Scaling Summary:** This is a coordination and workflow spec rather than a runtime system spec, so traditional scaling concerns (throughput, latency) apply primarily to the intake pipeline and agent dispatch frequency. The real performance risk is operational: agent invocation costs, rate limits, and context window exhaustion across concurrent agent sessions.

### Critical Findings

- **No rate limiting or cost model for agent invocations:** The routing table dispatches work to Claude, Cursor, and other agents on every qualifying event (voice input, code session, Vercel comment, @mention). With no throttling, a burst of Vercel comments or a noisy voice session could trigger dozens of concurrent agent invocations. At Claude API pricing (~$15-75/M tokens for Opus-class models), an unmetered intake pipeline could cost $50-200/day during active development. -> Define rate limits per source label. Set a daily token/invocation budget per agent. Add circuit breakers that fall back to human triage when limits are hit.

- **Context window exhaustion in multi-step agent chains is unaddressed:** The spec implies multi-hop flows: voice -> Claude transcription -> spec extraction -> Linear issue creation -> potentially triggering @claude for further processing. Each hop consumes context. With 200K token windows, a chain of 3-4 agent invocations on a complex topic could hit limits. -> Define context budgeting per agent hop. Specify checkpointing strategies between hops so intermediate results are persisted, not carried in context.

### Important Findings

- **n8n orchestration (Phase 3) has no throughput design:** Phase 3 adds n8n as a workflow engine but provides no specification for: concurrent workflow execution limits, queue depth, retry policies, or timeout values. n8n Cloud has execution limits per plan tier. -> Before Phase 3, audit the n8n plan limits. Define expected peak throughput (events/hour) and validate that the plan supports it. Specify retry and timeout policies per workflow.

- **No SLA or latency target for intake-to-dispatch:** When a voice memo or Vercel comment arrives, how quickly should the agent receive and process it? The spec provides no latency expectation. Without a target, there is no way to evaluate whether the architecture is performing adequately. -> Define latency tiers: voice intake < 60s to issue creation; @claude mention < 30s to acknowledgment; Vercel comment < 5 min to agent response.

### Consider

- **Parallel agent invocation cost:** Phase 2A (Cursor) and Phase 2B (v0) run concurrently. If both agents are invoked on the same event (e.g., a code-session source triggers both Claude and Cursor), the cost doubles with no deduplication. Define event deduplication at the routing layer.

- **Linear API rate limits under multi-agent load:** Multiple agents (Claude, Cursor, GitHub Copilot, Sentry, ChatPRD) all have Linear access. Under concurrent operation, they could collectively exceed Linear's API rate limits (documented at ~50 req/s for OAuth apps). Add a shared rate limiter or serialization queue for Linear API calls across agents.

### Quality Score (Performance Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Scalability | 2 | No throughput targets, no rate limiting, no cost model. Acceptable for personal-scale but no runway for growth. |
| Resource efficiency | 2 | Context window budgeting and agent invocation costs unaddressed. |
| Latency design | 1 | No latency targets defined for any intake path. |
| Operational cost | 1 | No budget, no cost projections, no circuit breakers. Multi-agent systems can generate surprise bills. |
| Failure resilience | 2 | Phased rollout provides some resilience. No retry/timeout/fallback specs. |

### What the Spec Gets Right (Performance)

- The phased rollout (WS-0 through WS-3) is the correct approach for a multi-agent system — it allows measuring operational costs after each phase before expanding.
- Blocking Phase 1A on human configuration (Whispr Flow app setup) is an appropriate gate that prevents runaway automation before the infrastructure is validated.
- The explicit sequencing with dependency tracking (Phase 1A blocks 1B, etc.) prevents the "everything at once" anti-pattern that makes cost attribution impossible.

---

## Architectural Purist Review: CIA-379

**Structural Summary:** The spec describes a hub-and-spoke dispatch architecture with Claude as the hub and various agents as spokes, but it defines the routing table without defining the contracts between hub and spokes. The result is an implicit coupling web where every agent depends on undocumented assumptions about Linear's data model, label conventions, and issue lifecycle.

### Critical Findings

- **No agent contract or interface definition:** The routing table assigns agents to source labels, but there is no specification of what an agent receives as input, what it must produce as output, or what lifecycle hooks it must implement. Without a contract, adding a new agent (or replacing one) requires reverse-engineering the current agents' behavior. This is the "plugins defined by implementation, not by contract" anti-pattern. -> Define a formal agent interface: `AgentContract { receive(event: IntakeEvent): Promise<AgentResponse>; capabilities: string[]; requiredPermissions: string[] }`. Every agent in the routing table must implement this contract.

- **Linear is load-bearing infrastructure disguised as a PM tool:** The spec positions Linear as the "PM source of truth," but in practice Linear is the message bus, the state machine, the audit log, and the configuration store for the entire multi-agent system. Labels are routing keys. Issue status is agent workflow state. Comments are inter-agent communication channels. This is a classic "database as integration layer" anti-pattern. If Linear has an outage or API change, the entire orchestration system fails with no fallback. -> Acknowledge Linear's role as infrastructure explicitly. Define what happens during a Linear outage. Consider whether a lightweight local state store should serve as a buffer/fallback.

- **Coupling between WS-0 labels and WS-1/WS-2 routing logic:** The routing table depends on `source:*` labels created in WS-0. But the label semantics (what qualifies as `source:voice` vs `source:cowork`) are defined in WS-0 while the routing behavior is defined in WS-1. This splits a single concern (intake classification + routing) across two workstreams with no shared contract. A label name change in WS-0 silently breaks WS-1. -> Define the label-to-route mapping as a single configuration artifact that both workstreams reference. Version this configuration.

### Important Findings

- **No separation between orchestration logic and agent logic:** The spec conflates "which agent handles this" (orchestration) with "what the agent does" (agent logic). The routing table is orchestration; the Whispr Flow rewrite, Cursor config, and v0 feedback loop are agent-specific implementations. These should be independently deployable. -> Extract the routing/dispatch layer as its own component with its own spec. Agent implementations should be pluggable against the dispatch interface.

- **Dependency direction violation between SDD plugin and agent ecosystem:** The "Plugin Capture" directive requires every phase to feed learnings back into the SDD plugin. This creates a bidirectional dependency: the agent ecosystem depends on the SDD plugin for patterns, and the SDD plugin depends on the agent ecosystem for inputs. Bidirectional dependencies prevent independent evolution. -> Define the dependency as unidirectional: agent ecosystem produces learnings (output), SDD plugin consumes them (input). The plugin should never be a prerequisite for agent work.

- **v1.3.0 Agent Reference Implementation is an assertion, not a contract:** The spec states that SDD plugin v1.3.0 "established 3 reference agents" but does not define what makes them reference-worthy. What frontmatter standards? What lifecycle hooks? A reference implementation without a documented interface is just example code. -> Extract the agent frontmatter standard into a standalone specification that new agents can validate against.

### Consider

- **Mixed granularity in the workstream table:** WS-0 is a single issue (CIA-369). WS-3 is four issues spanning documentation, codification, and multiple domains. This inconsistency suggests WS-3 is under-decomposed or WS-0 is over-isolated. Consider whether WS-3 should be split into WS-3a (documentation) and WS-3b (codification).

- **"TBD" in a routing table is an architectural smell:** The `source:vercel-comments` row has "TBD" as the agent. A routing table with undefined routes is an incomplete state machine. Either define the route or remove the row and track it as a separate future spec.

- **Naming inconsistency:** The spec uses "Multi-Agent Orchestration" in the title but "Intake & dispatch" for WS-1 and "Multi-agent ecosystem" for WS-2. These terms overlap without clear distinction. Is "orchestration" the umbrella? Is "dispatch" a subset of "orchestration"? Define the conceptual hierarchy.

### Quality Score (Architecture Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Coupling | 2 | Implicit coupling via labels, Linear data model, and undocumented agent assumptions. |
| Cohesion | 3 | Workstreams are reasonably focused, but WS-3 mixes concerns. |
| API contracts | 1 | No agent contracts, no dispatch interface, no event schema. |
| Extensibility | 2 | Adding a new agent requires understanding all existing agents' behavior — no plug-in points. |
| Naming clarity | 2 | "Orchestration" vs "dispatch" vs "ecosystem" used interchangeably. Agent roles fuzzy. |

### What the Spec Gets Right (Architecture)

- The hub-and-spoke topology with Claude as the central layer is the correct structural choice for a single-orchestrator multi-agent system. It prevents agent-to-agent spaghetti.
- Workstream decomposition (WS-0 through WS-3) correctly separates infrastructure (labels), intake (dispatch), ecosystem (agents), and documentation. This is a clean separation of concerns at the project level.
- The sequencing with explicit blocking relationships (Phase 1A blocks 1B) prevents the architectural anti-pattern of building consumers before the platform is stable.
- Acknowledging that CIA-284 is "deferred" rather than crammed into a phase shows discipline about scope boundaries.

---

## UX Advocate Review: CIA-379

**User Impact Summary:** The primary users of this system are Cian (the human operator) and the AI agents themselves. The spec defines routing and sequencing but provides no specification for how the human operator monitors, intervenes in, or overrides the multi-agent system. When an agent misroutes, misinterprets, or fails, the operator has no defined recovery path.

### Critical Findings

- **No human override or intervention mechanism:** The routing table dispatches work to agents automatically based on source labels. But the spec defines no mechanism for the human operator to: (a) override a routing decision after dispatch, (b) halt an agent mid-task, (c) reassign work from one agent to another, or (d) view the current state of all agent activities. The operator is blind to the system's behavior except by manually checking Linear. -> Define a dashboard or status command that shows: all active agent tasks, their current state, and the ability to cancel/reassign. Even a CLI command like `sdd agents status` would suffice.

- **No feedback loop when agent routing is wrong:** When `source:voice` is routed to Claude but the voice input was actually a collaborative session (should be `source:cowork`), the spec provides no mechanism for: detecting the misroute, correcting the label, re-routing to the correct handler. The operator discovers the error only when the output is wrong. -> Add a routing confidence signal. If the intake classifier is uncertain about the source label, flag it for human review rather than auto-dispatching.

### Important Findings

- **Cognitive load of the routing table on the operator:** The routing table has 5 source labels with different default agents and rationales. The operator must mentally model which agent is handling which input type, remember the rationale for each assignment, and know which agents are available for override. This is a 5-item decision matrix that will grow as new sources are added. -> Provide the routing table as a queryable reference, not just a spec table. The operator should be able to ask "where did my voice memo go?" and get an answer.

- **No onboarding path for new agents in the ecosystem:** Phase 2A (Cursor) and Phase 2B (v0) introduce new agents, but the spec provides no "getting started" guide for configuring a new agent. What files need to be edited? What permissions need to be granted? What does a successful test look like? -> Add an agent onboarding checklist to each Phase 2 sub-issue: prerequisites, configuration steps, validation criteria, rollback procedure.

- **@claude mention UX (CIA-382) has no discoverability specification:** Users who want to invoke Claude via Linear mentions need to know: what the valid commands are, what format to use, what to expect in response, and how long to wait. The spec says "MVP" but provides no UX for the feature. -> Define the mention syntax, response format, and expected latency. Provide an auto-reply on first use that explains available commands (e.g., "Hi! I'm Claude. I can help with: /spec, /review, /status. Reply /help for details.").

### Consider

- **Triage history section is operator-hostile:** The spec includes a "Triage History" section with raw issue ID references (CIA-400, CIA-397, CIA-374, CIA-387, etc.) and terse actions (Cancelled, merged, rewritten). This is a changelog, not a navigable history. For operator usability, link each issue ID to its Linear URL and explain the why, not just the what.

- **Session Continuation section assumes context:** "Phase 0 complete. Phase 1A blocked on Cian. Phase 1C complete." This assumes the reader knows what Phase 0, 1A, and 1C contain. For a master plan that may be revisited weeks later, add a one-line summary next to each phase status (e.g., "Phase 0 (label hygiene): DONE").

- **Plugin Capture directive has no user-facing output:** "After each phase, add a Plugin Implications section" is an instruction to the implementer but produces no visible output for the operator. The operator cannot verify this happened without reading each sub-issue. Consider a roll-up summary in the master plan.

### Quality Score (UX Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| User journey | 2 | Operator journey from "input arrives" to "output verified" is undefined. Agent users have no interface spec. |
| Error experience | 1 | No misroute detection, no correction flow, no error recovery for any agent pathway. |
| Cognitive load | 3 | Routing table is manageable at 5 rows but will scale poorly. Triage history adds noise. |
| Discoverability | 2 | @claude mention commands, agent capabilities, and routing behavior are not discoverable by users. |
| Accessibility | N/A | Not applicable to this spec type (workflow orchestration, not UI). |

### What the Spec Gets Right (UX)

- The routing table with explicit rationale columns is a strong UX pattern. Each routing decision has a stated reason, which helps the operator understand and predict system behavior.
- The "Blocked on Cian" annotation in Phase 1A is a good operator-facing signal. It makes clear that progress requires human action, preventing the operator from wondering why nothing is happening.
- The workstream table provides a clear at-a-glance view of overall progress with status indicators (DONE, PARTIAL, NOT STARTED). This is effective dashboard design.
- The Plugin Capture directive, while under-specified in terms of user-facing output, correctly identifies that operational learnings must be systematically captured rather than lost.

---

## Combined Panel Summary

### Where All Four Reviewers Agree

1. **No agent contracts or interfaces.** Security calls it an auth boundary gap, Performance calls it a cost attribution gap, Architecture calls it a coupling risk, UX calls it a discoverability gap. All four agree: the spec routes work to agents without defining what agents are, what they accept, or what they produce.

2. **Vercel comments routing is dangerously under-specified.** Security flags it as an unauthenticated-input-to-code-change pipeline. Architecture flags "TBD" as an incomplete state machine. UX flags the lack of a defined user experience. Performance notes the missing rate limiting. The panel unanimously recommends either fully specifying or removing this row from the routing table.

3. **No error handling or recovery for any pathway.** No reviewer found a defined recovery mechanism for misroutes, agent failures, or unexpected inputs. This is the single most consistent gap across all four lenses.

4. **Phased rollout is the correct approach.** All four reviewers acknowledge that the WS-0 through WS-3 sequencing with explicit blocking relationships is a strength that limits blast radius, enables incremental cost measurement, allows security to be layered in, and reduces cognitive load on the operator.

### Where Reviewers Disagree

| Topic | Security Skeptic | Performance Pragmatist | Architectural Purist | UX Advocate |
|-------|-----------------|----------------------|---------------------|-------------|
| **Linear as central hub** | Concerned about token/credential convergence in one system | Concerned about API rate limits under multi-agent load | Concerned about "database as integration layer" anti-pattern | Sees it as a pragmatic choice that works for single-operator scale |
| **Agent roster openness** | Wants a closed, vetted agent set with security onboarding | Wants cost caps per agent to prevent runaway spending | Wants a formal plugin contract so agents are interchangeable | Wants an agent onboarding UX so the operator can configure new agents confidently |
| **Voice pipeline (CIA-381)** | Primary concern: prompt injection via transcription | Primary concern: context window costs of long transcripts | Primary concern: no event schema for voice-to-spec data flow | Primary concern: no operator feedback when transcription is wrong |
| **Spec maturity assessment** | Not ready for implementation — security model must come first | Acceptable for personal-scale prototype, but cost guardrails needed before Phase 2 | Structurally sound at the project level but architecturally hollow at the component level | Operator experience is an afterthought; needs a monitoring/intervention layer before it is usable |

### Aggregate Quality Scores

| Dimension | Security | Performance | Architecture | UX | Average |
|-----------|----------|-------------|--------------|-----|---------|
| Domain Score 1 | Auth: 1 | Scalability: 2 | Coupling: 2 | User journey: 2 | 1.75 |
| Domain Score 2 | Data: 2 | Resources: 2 | Cohesion: 3 | Error experience: 1 | 2.00 |
| Domain Score 3 | Input: 1 | Latency: 1 | Contracts: 1 | Cognitive load: 3 | 1.50 |
| Domain Score 4 | Attack surface: 2 | Cost: 1 | Extensibility: 2 | Discoverability: 2 | 1.75 |
| Domain Score 5 | Compliance: 1 | Resilience: 2 | Naming: 2 | Accessibility: N/A | 1.67 |
| **Overall** | **1.4** | **1.6** | **2.0** | **2.0** | **1.75** |

### Panel Recommendation

**Verdict: REVISE BEFORE IMPLEMENTATION**

The spec is a competent project coordination document but is not yet an implementable technical specification. It answers "what work items exist and in what order" but does not answer "how do agents interact, what do they accept, what guardrails exist, and what happens when things go wrong."

**Minimum viable revisions before proceeding beyond Phase 1B:**

1. Define an agent contract interface (Architecture + Security)
2. Add a cost/rate-limiting model for agent invocations (Performance)
3. Specify error detection and recovery flows for misrouted inputs (UX + Security)
4. Resolve or remove the `source:vercel-comments` TBD (all four)
5. Add operator monitoring/override mechanisms (UX)
6. Address voice input sanitization and prompt injection (Security)

**Acceptable as-is for:**
- Phase 0 (labels) — already done
- Phase 1A (Whispr Flow) — blocked on human action, low blast radius
- Phase 1C (PR triad codification) — already done, documentation-only
