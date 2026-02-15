# Adversarial Panel Review: CIA-270

**Spec:** Write portable CONNECTORS.md integration guide for SDD plugin
**Review date:** 2026-02-15
**Panel:** Security Skeptic, Performance Pragmatist, Architectural Purist, UX Advocate

---

## Security Skeptic Review: CIA-270

**Threat Model Summary:** This spec defines a credential management and integration guide that, if followed naively, will produce a document containing credential storage patterns, environment variable naming conventions, and sync workflow details. The primary threat vectors are: (1) the guide itself encouraging users toward insecure credential practices through ambiguous hierarchy, and (2) the bidirectional sync patterns creating trust boundary violations between services with different security postures.

### Critical Findings

- **Credential storage hierarchy under-specifies keychain isolation**: The spec lists "System keychain" as tier 2 but does not specify keychain access control. On macOS, any application with the same user context can read keychain items unless ACLs are explicitly set. A user following this guide could store a Linear API token in their default keychain, accessible to every app on their machine. -> Specify keychain ACL requirements: the guide must instruct users to create a dedicated keychain or set per-item ACL restrictions (`security add-generic-password -T ""` on macOS to deny all app access except explicit grants).

- **MCP config examples with `${VAR_NAME}` create a false sense of security**: The acceptance criteria require "zero hardcoded values" using `${VAR_NAME}` interpolation. But MCP config files (`.mcp.json`) are committed to repositories. If a user accidentally resolves variables before committing, or if a tool writes the resolved config, secrets end up in version control. The spec defines no `.gitignore` pattern for resolved configs and no pre-commit hook to catch leaked secrets. -> The guide must include: (a) a `.gitignore` entry for resolved/local MCP configs, (b) a recommended pre-commit hook that scans for token patterns in committed files, and (c) explicit warnings about the difference between template configs (committable) and resolved configs (never committable).

- **OAuth token lifecycle undefined beyond "rotation protocol"**: The spec mentions "90-day/30-day" rotation schedules but does not specify: What happens when a token expires mid-sync? Who triggers rotation -- the user, a cron job, the plugin? What is the fallback if rotation fails? An expired token during a bidirectional sync could leave the system in an inconsistent state (e.g., issue marked "Done" in the tracker but the corresponding PR status not updated). -> Define token lifecycle states (active, expiring-soon, expired, revoked), automated rotation triggers, and graceful degradation behavior when credentials are invalid.

### Important Findings

- **Bidirectional sync patterns create trust escalation paths**: The spec defines "Error Tracking <-> Project Tracker" sync where a new error auto-creates a new issue. If an attacker can trigger arbitrary errors in the application (e.g., by sending crafted requests), they can flood the project tracker with issues. More concerning: if the error-to-issue sync includes error payloads (stack traces, request data), an attacker could inject content into the project tracker that contains XSS payloads or social engineering links. -> The guide must specify input sanitization for any data flowing from one service to another, rate limiting on auto-issue creation, and content validation on synced payloads.

- **Environment variable matrix across environments creates secret sprawl**: The spec proposes an env var matrix template covering dev/staging/production. Users managing 5 connectors across 3 environments have 15+ credential sets. Without explicit guidance on secret lifecycle management, users will copy-paste credentials across environments, reuse tokens, or leave stale credentials active. -> Add a "credential hygiene" section: per-environment isolation, no credential sharing across environments, automated staleness detection, and a decommissioning checklist when removing a connector.

- **No guidance on least-privilege scoping for connector credentials**: The spec lists connectors (Linear, GitHub, Vercel, PostHog, Sentry) but does not specify the minimum permission scopes required for each. Users will default to full-access tokens because it is easier. A compromised Sentry token with org-admin scope is vastly worse than one with project-read scope. -> For each of the 5 prioritized connectors, specify the exact minimum OAuth scopes or PAT permissions required for SDD plugin functionality.

### Consider

- **Webhook endpoints in bidirectional sync are unauthenticated attack surface**: The spec references webhook-based sync (GitHub <-> Project Tracker) but does not mention webhook signature verification. Unsigned webhooks can be spoofed, allowing an attacker to trigger false status transitions.

- **The guide should include a "security self-check" section**: After wiring up connectors, users should verify: no secrets in committed files, all tokens scoped to minimum permissions, webhook signatures enabled, and rotation schedules active. A simple checklist would catch the most common misconfigurations.

### Quality Score (Security Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Auth boundaries | 2 | Credential storage hierarchy exists but lacks ACL specifics, scope minimization, and lifecycle management |
| Data protection | 2 | Bidirectional sync moves data across trust boundaries without sanitization or encryption-in-transit requirements |
| Input validation | 1 | No mention of validating data flowing between connectors; sync payloads are implicitly trusted |
| Attack surface | 3 | Acknowledges webhooks and external integrations but doesn't address attack surface reduction |
| Compliance | 2 | No mention of what PII flows through connectors or data residency implications |

### What the Spec Gets Right (Security)

- The credential storage hierarchy (secrets manager > keychain > env vars > repo secrets) is the correct ordering. Most integration guides skip this entirely and just say "set an environment variable."
- The `SDD_<SERVICE>_<CREDENTIAL_TYPE>` naming convention prevents credential collision and makes audit easier -- you can grep for leaked credentials by pattern.
- Requiring `${VAR_NAME}` syntax with zero hardcoded values is a strong default that prevents the most common secret leak vector (hardcoded tokens in config files).
- The acceptance criterion "No references to specific workspace IDs, personal emails, or local paths" shows awareness of information leakage in documentation.

---

## Performance Pragmatist Review: CIA-270

**Scaling Summary:** This spec produces a static documentation file, not a runtime system, so traditional scaling concerns (throughput, latency, memory) do not apply directly. However, the spec defines patterns that users will implement as runtime systems -- bidirectional sync, webhook orchestration, credential rotation -- and the spec's silence on operational characteristics of these patterns will lead to production failures at scale.

### Critical Findings

- **No rate limiting guidance for bidirectional sync**: The spec defines 4+ bidirectional sync pairs (GitHub <-> Tracker, Deployment <-> GitHub, Error <-> Tracker, Error <-> Deployment). Each sync direction can generate events. In a moderately active project, a merged PR could trigger: PR status update -> Issue status update -> Deployment trigger -> Deployment status update -> Error tracking release -> back to Issue update. This feedback loop has no described circuit breaker. At 10+ PRs/day with 5 connectors, this creates O(n*m) webhook events where n = events and m = connectors. -> The guide must include: (a) idempotency requirements for all sync handlers, (b) deduplication windows to prevent echo loops (event A triggers B triggers A), and (c) rate limiting recommendations per connector API (e.g., Linear API: 1500 req/hr, GitHub API: 5000 req/hr for authenticated users).

### Important Findings

- **"Quick Start in under 30 minutes" is unrealistic for 5 connectors and will create support burden**: Wiring up Linear requires OAuth app creation, webhook setup, team/project mapping, and label alignment. GitHub requires PAT or SSH key, branch protection rules, PR template, and status check configuration. Vercel requires project linking, env var sync, and domain setup. PostHog requires project creation, API key, and event taxonomy. Sentry requires project creation, DSN configuration, release tracking, and source map upload. Each of these is 15-30 minutes individually. Claiming 30 minutes total sets an expectation that will frustrate every user. -> Either (a) redefine "Quick Start" as credential setup only (plausible in 30 min) with full sync configuration as a separate "Full Setup" section, or (b) provide a setup automation script that handles the boilerplate (create OAuth apps, set env vars, configure webhooks) and honestly estimate the time as 60-90 minutes for manual setup.

- **Webhook volume at scale is unaddressed**: A project with 50 daily commits, 10 PRs, and 5 deployments generates roughly 200+ webhook events/day across the connector matrix. The spec's bidirectional sync patterns would amplify this to 500+ cross-service events. For a team of 10 developers, this scales to 5000+ events/day. The guide does not discuss: webhook queue depth, retry backoff, or what happens when a downstream service is temporarily unavailable. -> Include an "Operational Considerations" section with expected event volumes by team size and guidance on webhook queuing (e.g., use a lightweight queue for webhook processing rather than synchronous fan-out).

- **Credential rotation at "90-day/30-day schedules" without automation means it won't happen**: Manual rotation of 5+ credentials every 30-90 days is an operational burden that teams will ignore until a credential expires and breaks their pipeline. The spec should acknowledge this reality. -> Recommend automated rotation tooling (e.g., Doppler auto-rotation, 1Password service account rotation) and define what happens when a credential expires without rotation (graceful degradation, alerts, not silent failure).

### Consider

- **The environment variable matrix could become unwieldy**: 5 connectors x 3 credential types (token, webhook secret, project ID) x 3 environments = 45 environment variables. This is a maintenance burden. Consider recommending a single config file per environment (e.g., `.env.development`, `.env.production`) with a validation script that checks all required variables are set.

- **MCP server config examples should include timeout and retry settings**: The spec mentions "complete MCP server config example" but doesn't mention connection timeouts, retry policies, or health checks. A misconfigured MCP server that hangs on a failed API call will block the entire plugin.

### Quality Score (Performance Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Scalability | 2 | Bidirectional sync patterns have no rate limiting, deduplication, or volume projections |
| Resource efficiency | 3 | Env var matrix is reasonable but could become unwieldy at 45+ variables |
| Latency design | 2 | No discussion of sync latency, webhook processing time, or timeout behavior |
| Operational cost | 2 | No cost estimates for API usage across connectors at team scale |
| Failure resilience | 1 | No circuit breakers, retry policies, or graceful degradation for connector failures |

### What the Spec Gets Right (Performance)

- Categorizing connectors as Required / Recommended / Optional allows users to adopt incrementally rather than configuring everything upfront. This reduces initial setup cost and lets teams add connectors as they scale.
- The prioritized "5 first-class connectors" approach avoids the combinatorial explosion of documenting every possible connector combination. Focus drives adoption.
- Using `${CLAUDE_PLUGIN_ROOT}` as a base path variable avoids the performance anti-pattern of absolute paths that break across environments, reducing "works on my machine" debugging time.

---

## Architectural Purist Review: CIA-270

**Structural Summary:** The spec defines a flat, monolithic document (CONNECTORS.md) that mixes three distinct concerns: connector contracts (what a connector must do), connector implementations (how specific tools fulfill the contract), and operational procedures (how to manage credentials and sync). This conflation means the document will need modification for three independent change vectors: adding a new connector category, swapping a tool within a category, and updating a credential management practice. A well-structured guide would separate these concerns.

### Critical Findings

- **The portable pattern and the concrete implementation are conflated in a single document section**: The spec describes each connector category with both a `~~placeholder~~` portable pattern (credential storage, sync setup, configuration) AND "Common Defaults" (Linear, Jira, Asana). When a user reads the Linear-specific config example, they will treat it as the canonical approach rather than one implementation of the portable pattern. The abstraction leaks because the spec does not enforce a clear boundary between "contract" and "implementation." -> Structure the guide with explicit separation: Part 1 = Connector Contracts (what each category must provide, using only `~~placeholder~~` syntax), Part 2 = Reference Implementations (concrete configs for each default tool), Part 3 = Operational Procedures (credential management, rotation, sync patterns). A user adding a new tool only modifies Part 2. A user changing credential strategy only modifies Part 3.

### Important Findings

- **Bidirectional sync patterns create implicit coupling between connector categories**: The spec defines "Error Tracking <-> Project Tracker" as a sync pair, but this means the Error Tracking connector implicitly depends on the Project Tracker connector's API. If a user swaps their project tracker from Linear to Jira, the error tracking sync breaks unless the sync layer abstracts over tracker-specific APIs. The spec does not define this abstraction layer. -> Define sync patterns in terms of events and payloads, not service-specific APIs. Example: "Error Tracking emits `error.new` event with payload `{title, stackTrace, severity}`. Project Tracker consumes this event and creates an issue." The mapping from event to service-specific API call belongs in each connector's implementation, not in the sync pattern definition.

- **The "Prioritized Connector Defaults" section hardwires a specific stack (Linear + GitHub + Vercel + PostHog + Sentry) into the architecture of the guide**: This creates a gravitational pull toward this specific stack. The guide's portable patterns should be validated against at least two stacks to prove they are actually portable. If the patterns only work with the default stack, they are not portable -- they are specific implementations disguised as abstractions. -> Validate the portable patterns by writing connector configs for at least one alternative stack (e.g., Jira + GitLab + Railway + Mixpanel + Datadog) even if only in an appendix. If the patterns need modification for the alternative stack, they are not truly portable.

- **No connector interface contract defined**: The spec lists what each connector category "does" (e.g., Project Tracker: "Issue lifecycle, spec status tracking, sprint/cycle management") but does not define a formal contract. What methods or events must a Project Tracker connector expose? What data format must it accept? Without a contract, each connector implementation will have a different shape, and the plugin cannot treat connectors polymorphically. -> Define a minimal connector contract per category. For Project Tracker: `createIssue(spec) -> issueId`, `updateStatus(issueId, status)`, `syncLabels(labels[])`, `getIssue(issueId) -> spec`. This contract is what makes connectors swappable.

### Consider

- **The Required / Recommended / Optional taxonomy conflates importance with coupling**: "Required" implies the plugin cannot function without it. But the spec does not define what plugin functionality degrades when a "Required" connector is missing vs. when a "Recommended" one is. Is this a hard dependency (plugin crashes) or soft (feature disabled)? Naming this "Required" without defining failure modes creates an implicit contract that is never made explicit.

- **`${CLAUDE_PLUGIN_ROOT}` as a path variable is a good abstraction, but the spec does not define what the plugin root directory structure looks like**: If connectors need to read or write files (e.g., spec files, config files), the directory structure IS part of the architectural contract. The guide should reference a documented directory layout.

- **The spec mixes documentation (CONNECTORS.md) with configuration (MCP config examples)**: These serve different audiences at different times. A user reads the guide once during setup; they reference the config examples repeatedly. Consider whether config examples should be separate files (e.g., `connectors/linear.json.example`) that the guide references rather than inline code blocks in a single Markdown file.

### Quality Score (Architecture Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Coupling | 2 | Bidirectional sync patterns create implicit coupling between connector categories with no abstraction layer |
| Cohesion | 2 | Single document mixes contracts, implementations, and operational procedures |
| API contracts | 1 | No formal connector interface contract defined; connectors are described by purpose, not by interface |
| Extensibility | 3 | Placeholder syntax enables extensibility in theory, but lack of contracts limits it in practice |
| Naming clarity | 4 | Category names and placeholder syntax are clear and consistently used |

### What the Spec Gets Right (Architecture)

- The `~~placeholder~~` syntax is an elegant abstraction mechanism. It clearly signals "this is a slot you fill" without prescribing a specific tool. This is the correct level of indirection for a portable guide.
- The three-tier categorization (Required / Recommended / Optional) establishes a clear dependency hierarchy. Users know what to set up first.
- Separating credential storage from sync setup from configuration within each connector pattern shows awareness of separation of concerns, even if the document structure does not fully realize it.
- The spec explicitly requires "zero hardcoded values" and "no references to specific workspace IDs" -- these are architectural constraints that enforce portability at the content level.

---

## UX Advocate Review: CIA-270

**User Impact Summary:** The spec designs a comprehensive integration guide but under-specifies the user's experience of actually following it. A new SDD plugin user encountering CONNECTORS.md will face a wall of concepts (3 tiers, 10 connector categories, 4 sync pairs, credential hierarchies, env var matrices) with no clear "start here" path. The spec optimizes for completeness over usability.

### Critical Findings

- **Cognitive overload on first encounter**: The spec defines 10 connector categories across 3 tiers, 4+ bidirectional sync patterns, a 4-level credential hierarchy, naming conventions, rotation protocols, and environment variable matrices. A user opening CONNECTORS.md for the first time must absorb all of this before they can wire up a single connector. This violates progressive disclosure -- the user needs to see immediate value (one connector working) before investing in the full system. -> Restructure the guide with a "Zero to One" section at the top: pick one required connector (e.g., GitHub, since most users already have it), show the complete setup in 10 steps, and confirm it works with a verification command. Only then introduce the full connector taxonomy. The user's first experience should be success, not reading.

- **No verification or feedback mechanism defined**: The spec says "Quick Start section allows wiring up 5 connectors in under 30 minutes" but does not define how a user knows each connector is working. After setting up Linear, what command do they run to verify the connection? After configuring GitHub sync, what do they see that confirms bidirectional sync is active? Without verification steps, users will follow the guide, assume it worked, and discover failures hours later when a sync does not fire. -> Every connector setup section must end with a "Verify" step: a specific command or action that produces visible confirmation. Example: "Run `sdd status connectors` to see a table of connected services and their health."

### Important Findings

- **Error scenarios during setup are unaddressed**: What happens when the user pastes an invalid API token? When the webhook URL is unreachable? When the OAuth callback fails? The spec describes the happy path (credential stored, sync configured, done) but not the error path. Setup is where most users abandon a tool -- the guide must anticipate common failures and provide recovery instructions. -> Add a "Troubleshooting" subsection per connector category with the 3 most common setup failures and their resolutions. Example: "Error: 401 Unauthorized -- Your token may have expired or lack the required scopes. Regenerate at [Service] > Settings > API Keys with scopes: X, Y, Z."

- **The environment variable matrix template is described but not shown**: The spec mentions "Environment variable matrix template per environment" in the credential management section but does not define what this template looks like. Users cannot follow a template they cannot see. -> Include a concrete, fill-in-the-blanks template. Example table with columns: Variable Name | Dev Value | Staging Value | Production Value | Source (Keychain/Secrets Manager/Env) | Rotation Schedule.

- **The spec assumes users understand bidirectional sync**: Terms like "PR -> Issue status," "Issue -> Branch," "Comment sync," and "Label sync" are listed without explanation. A user new to integration patterns may not understand what "bidirectional sync" means in practice, what triggers it, or what happens when both sides update simultaneously (conflict resolution). -> Add a brief conceptual introduction before the sync patterns section: "Bidirectional sync means changes in Service A automatically reflect in Service B, and vice versa. For example, closing a Linear issue automatically closes the linked GitHub PR." Include a simple diagram showing the event flow.

- **No guidance on what to do if a user does not want all 5 default connectors**: The Quick Start focuses on 5 specific tools (Linear, GitHub, Vercel, PostHog, Sentry). What if a user does not use PostHog? Can they skip it? Will the plugin degrade gracefully? The spec does not address partial adoption. -> Add explicit "skip this connector" guidance: which connectors can be skipped without breaking anything, what functionality is lost, and how to add them later.

### Consider

- **The guide would benefit from a visual architecture diagram**: A simple diagram showing how connectors relate to the SDD plugin and to each other would reduce cognitive load significantly. Users could see the full picture at a glance before diving into individual connector setup. A Mermaid diagram showing Plugin <-> Connector Category <-> Service with data flow arrows would serve this purpose.

- **The `~~placeholder~~` syntax, while architecturally clean, may confuse users**: Tilde-delimited placeholders are not a widely recognized convention. Users may mistake them for Markdown strikethrough. Consider adding a "Notation Guide" callout at the top of the document explaining the syntax.

- **Section ordering should follow the user's setup sequence, not the spec's logical taxonomy**: The spec organizes by Required > Recommended > Optional, which is logical. But a user setting up connectors cares about dependency order: GitHub first (because other connectors reference it), then Project Tracker (because sync depends on it), then CI/CD (because it depends on both). Consider a "Setup Order" guide that differs from the taxonomic order.

### Quality Score (UX Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| User journey | 2 | No defined path from "first open" to "first working connector"; spec assumes the user will read everything before starting |
| Error experience | 1 | Zero error scenarios, troubleshooting guidance, or recovery paths defined |
| Cognitive load | 2 | 10 categories, 4 sync pairs, credential hierarchies, env matrices -- too much for first encounter |
| Discoverability | 3 | Tiered categorization helps, but no "start here" marker or progressive disclosure |
| Accessibility | 2 | No mention of alternative formats, screen reader considerations for code blocks, or internationalization |

### What the Spec Gets Right (UX)

- The "Quick Start" concept is the right instinct -- users want to see value quickly. The spec acknowledges this even if the 30-minute timeline is ambitious.
- The `~~placeholder~~` syntax with "Common Defaults" is a good pattern for making the guide usable by teams with different tooling stacks. Users see the generic pattern and the concrete example side by side.
- Separating connectors into Required / Recommended / Optional gives users permission to adopt incrementally. This reduces the "I have to set up everything" anxiety.
- The acceptance criterion "All config examples use `${CLAUDE_PLUGIN_ROOT}` and `${VAR_NAME}`" means users can copy-paste examples and only change the values, not the structure. This is good DX.

---

## Combined Panel Summary

### Points of Agreement (All 4 Reviewers)

1. **The credential management section needs significant expansion.** Security Skeptic wants ACLs and least-privilege scoping. Performance Pragmatist wants automated rotation and staleness detection. Architectural Purist wants credential lifecycle as a separate concern. UX Advocate wants error handling for invalid credentials. All four agree the current "storage hierarchy + naming convention + rotation schedule" is a skeleton, not a guide.

2. **Bidirectional sync patterns are under-specified and dangerous as written.** Security Skeptic flags trust boundary violations. Performance Pragmatist flags feedback loops and rate limiting. Architectural Purist flags implicit coupling without abstraction. UX Advocate flags lack of conflict resolution explanation. The sync section needs the most work of any part of the spec.

3. **The "30 minutes for 5 connectors" claim is unrealistic.** Performance Pragmatist and UX Advocate both flag this independently. The time estimate sets users up for frustration and should be revised or the scope of "Quick Start" should be narrowed.

4. **Verification and feedback are missing.** UX Advocate flags this as critical (no way to confirm connectors work). Performance Pragmatist flags it as an operational gap (no health checks). Security Skeptic frames it as a security self-check. All agree the guide needs a "verify your setup" mechanism.

### Points of Disagreement

1. **Document structure:** Architectural Purist wants the document split into 3 parts (contracts, implementations, procedures) or even separate files. UX Advocate wants the document ordered by setup sequence, not logical taxonomy. Performance Pragmatist is neutral on structure but wants an "Operational Considerations" section. Security Skeptic wants a "Security Self-Check" section. These are not mutually exclusive but reflect different priorities for the document's primary organizing principle.

2. **Scope of the guide:** Architectural Purist argues the spec should define formal connector contracts (interfaces, methods, event schemas) to enable true portability. UX Advocate argues the guide should be leaner and more focused on getting users to a working state quickly. Security Skeptic wants more content (threat models, scope tables, webhook verification). Performance Pragmatist wants operational guidance (rate limits, volume projections, cost estimates). The spec must balance completeness against usability -- currently it leans toward completeness without delivering on either.

3. **Level of abstraction:** Architectural Purist argues the `~~placeholder~~` pattern is insufficient without formal contracts -- it is syntactic portability without semantic portability. UX Advocate argues the `~~placeholder~~` pattern may confuse users who mistake it for strikethrough. Performance Pragmatist is indifferent to the notation. Security Skeptic approves of it as an anti-hardcoding measure.

### Consolidated Severity Matrix

| Finding | Security | Performance | Architecture | UX | Consensus |
|---------|----------|-------------|--------------|-----|-----------|
| Credential lifecycle under-specified | CRITICAL | IMPORTANT | IMPORTANT | IMPORTANT | **CRITICAL** |
| Bidirectional sync lacks safety controls | CRITICAL | CRITICAL | IMPORTANT | IMPORTANT | **CRITICAL** |
| No verification/health check mechanism | CONSIDER | IMPORTANT | CONSIDER | CRITICAL | **IMPORTANT** |
| 30-minute Quick Start unrealistic | -- | IMPORTANT | -- | IMPORTANT | **IMPORTANT** |
| No error/troubleshooting guidance | -- | -- | -- | IMPORTANT | IMPORTANT |
| No formal connector contract/interface | -- | -- | CRITICAL | -- | IMPORTANT |
| Document mixes contracts + implementations | -- | -- | CRITICAL | CONSIDER | IMPORTANT |
| No least-privilege scope guidance | IMPORTANT | -- | -- | -- | IMPORTANT |
| Sync feedback loops / rate limiting | -- | CRITICAL | IMPORTANT | -- | IMPORTANT |
| Cognitive overload on first encounter | -- | -- | -- | CRITICAL | IMPORTANT |
| No pre-commit hook for secret leak prevention | CRITICAL | -- | -- | -- | IMPORTANT |

### Overall Panel Verdict

**The spec describes the right document but does not yet describe a usable, secure, or architecturally sound one.** The connector categorization, placeholder syntax, and credential naming conventions are solid foundations. But the spec skips three layers that separate a "table of contents" from a "guide": (1) security specifics (what scopes, what ACLs, what happens on failure), (2) architectural contracts (what interface must each connector implement), and (3) user journey design (how does a human actually follow this from start to finish).

**Recommendation:** Revise the spec to address the 4 CRITICAL and 7 IMPORTANT findings before implementation. The highest-leverage changes are:

1. Define verification steps for every connector (addresses UX + Security + Performance concerns simultaneously).
2. Add a "Zero to One" section that gets one connector working before introducing the full taxonomy (addresses cognitive overload).
3. Separate connector contracts from connector implementations in the document structure (addresses architectural coupling).
4. Expand credential management with specific scopes, ACLs, and automated rotation guidance (addresses security gaps).
5. Add circuit breakers, deduplication, and rate limiting guidance to the bidirectional sync section (addresses operational risk).
