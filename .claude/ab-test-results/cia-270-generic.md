# Adversarial Review: CIA-270

**Spec:** Write portable CONNECTORS.md integration guide for SDD plugin
**Reviewer:** Generic (baseline)
**Date:** 2026-02-15

**Recommendation:** REVISE

---

## Critical Findings

1. **The deliverable already exists and substantially exceeds the spec's scope description.**
   `CONNECTORS.md` already exists at the repo root (207 lines) and covers all three connector categories, credential storage patterns (with anti-patterns and decision framework), bidirectional sync patterns (6 pairs), environment variable matrix, runtime vs agent credential separation, a real-world case study, a platform configuration checklist, and a secrets management migration path. The spec reads as if CONNECTORS.md does not exist yet ("This issue creates CONNECTORS.md"). If this is a rewrite, the spec must explicitly state what is wrong with the current version, what sections are being replaced vs retained, and why a rewrite is justified over incremental improvement. Without this, an implementer will either (a) duplicate existing content, (b) overwrite it and lose material the spec does not mention (e.g., the Distributor Finder case study, credential anti-patterns table, runtime vs agent credentials section), or (c) be confused about whether to start from scratch or edit in place.
   **Why it blocks:** An implementer cannot begin work without knowing whether to greenfield or modify. The risk of destroying existing high-quality content is high.
   **Suggested resolution:** Reframe the spec as a delta: identify specific gaps in the current CONNECTORS.md, list sections to add/modify/remove, and reference the existing document as the baseline.

2. **No mention of MCP configuration, despite the plugin being an MCP-based system.**
   The spec mentions "complete MCP server config example using ${CLAUDE_PLUGIN_ROOT} and ${VAR_NAME}" in the Prioritized Connector Defaults section, but the existing CONNECTORS.md does not contain MCP config blocks and the spec provides zero detail on what these config blocks should contain. The SDD plugin's `.mcp.json` is the actual configuration surface. The spec needs to specify: (a) what a "complete MCP server config example" looks like structurally (command, args, env?), (b) whether these go inside CONNECTORS.md as documentation or are executable config, (c) how `${CLAUDE_PLUGIN_ROOT}` resolves (this is not a standard MCP variable -- is it proposed or existing?), and (d) what happens when a user's MCP setup uses OAuth (Linear, GitHub) vs stdio (Zotero, arXiv) vs HTTP -- these have fundamentally different config shapes.
   **Why it blocks:** The acceptance criterion "complete MCP config examples for 5 tools" is unimplementable without defining what these examples contain. An implementer will invent something that may not match the actual MCP config schema.
   **Suggested resolution:** Add a section specifying the MCP config block structure (with at least one fully worked example showing command, args, and env fields), clarify whether `${CLAUDE_PLUGIN_ROOT}` is a real environment variable or needs to be defined, and acknowledge the OAuth vs stdio vs HTTP transport distinction.

3. **"30 minutes to wire up 5 connectors" is an untestable and likely false claim.**
   The acceptance criterion states: "Quick Start section allows wiring up 5 connectors in under 30 minutes." The 5 connectors are Linear, GitHub, Vercel, PostHog, and Sentry. Wiring up Linear alone requires: creating an OAuth app or obtaining a PAT, configuring MCP, setting up webhook sync with GitHub, and mapping label taxonomies. GitHub requires: SSH key or PAT, repository permissions, branch protection rules. Vercel requires: Git integration, environment variables across preview/production. Each of these is a 10-30 minute task independently. 5 connectors in 30 minutes assumes the user already has accounts, tokens, and familiarity with MCP -- at which point they arguably do not need this guide.
   **Why it blocks:** An acceptance criterion that cannot be met sets up the implementation for failure at review time. Either the guide will be superficial (just listing config snippets without explanation) or it will be thorough but exceed 30 minutes.
   **Suggested resolution:** Either (a) scope the 30-minute claim to "assuming accounts and tokens exist, configure MCP entries for 5 connectors" (which is achievable), or (b) replace the time claim with a structural criterion like "Quick Start section provides copy-paste-ready config blocks for 5 connectors with all variables parameterized."

---

## Important Findings

4. **Spec introduces connector categories that diverge from the existing document without justification.**
   The spec proposes Required (Project Tracker, Version Control), Recommended (CI/CD, Deployment, Error Tracking, Analytics), and Optional (Research Tools, AI Assistants, Automation). The existing CONNECTORS.md has the same three tiers but with different members: it includes `component-gen`, `email-marketing`, `geolocation`, `research-library`, `web-research`, `communication`, `design`, and `observability` as connectors. The spec drops 8 existing connectors and adds 2 new ones (AI Assistants, Automation) without acknowledging the difference. This is either an intentional pruning (which should be justified) or an oversight (which means content will be lost).
   **Impact:** Implementer may silently drop connectors that users of the current guide depend on.
   **Suggested resolution:** Explicitly list which connectors are being removed and why, or state that the spec's list is additive to the existing set.

5. **The "Credential Management Conventions" section duplicates and potentially contradicts existing content.**
   The spec proposes: storage hierarchy (Doppler, 1Password CLI, Vault > System keychain > Environment variables > Repository secrets), naming convention `SDD_<SERVICE>_<CREDENTIAL_TYPE>=<value>`, and 90-day/30-day rotation schedules. The existing CONNECTORS.md already has a Credential Storage Patterns section (with a 3-tier table: OS Keychain, Secrets Manager, Environment files), a Credential Anti-Patterns section (5 anti-patterns), a Runtime vs Agent Credentials section, and a Secrets Management decision framework with migration path. The spec's proposed naming convention (`SDD_<SERVICE>_<CREDENTIAL_TYPE>`) is new and not used anywhere in the existing document or the broader SDD plugin. Introducing a naming convention requires adoption across the plugin -- it is not just documentation.
   **Impact:** The naming convention introduces a standard that nothing in the plugin currently enforces or references, creating dead documentation.
   **Suggested resolution:** Either (a) scope the naming convention to a recommendation only and note that the plugin does not enforce it, or (b) remove it and defer to whatever naming the user's secrets manager imposes.

6. **"Bidirectional Sync Patterns" section is underspecified compared to what already exists.**
   The spec lists 4 sync pairs: GitHub <-> Project Tracker, Deployment <-> GitHub, Error Tracking <-> Project Tracker, Error Tracking <-> Deployment. The existing CONNECTORS.md documents 6 pairs with setup details (including Analytics <-> Project Tracker and Email Marketing <-> Database). The spec's version is less detailed than what already exists.
   **Impact:** If the spec is treated as the complete requirements, the implementer will produce a downgrade.
   **Suggested resolution:** Either reference the existing sync pairs as the baseline and add new ones, or explicitly state that the 4 listed are the minimum and existing pairs should be preserved.

7. **No file path specified for CONNECTORS.md placement.**
   The acceptance criterion says "CONNECTORS.md exists in SDD plugin repo at discoverable path" but does not specify where. The existing CONNECTORS.md is at the repo root (which is already discoverable). If the intent is to move it, the spec should say so. If it stays at root, this criterion is already met.
   **Impact:** Ambiguity about whether the file should move.
   **Suggested resolution:** Specify the path explicitly (e.g., repo root, or `docs/CONNECTORS.md`).

8. **The spec lacks a pre-mortem / failure mode analysis.**
   Per the SDD methodology's own PR/FAQ requirements, specs should include pre-mortem failure scenarios. This spec has none. Relevant failure modes include: (a) the guide becomes outdated as MCP config schemas evolve, (b) users copy config blocks verbatim without understanding the variables, leading to broken setups, (c) the guide becomes a maintenance burden if every new MCP connector requires an update, (d) the `~~placeholder~~` syntax confuses users who expect executable config.
   **Impact:** Without pre-mortem analysis, the implementation may not account for maintainability.
   **Suggested resolution:** Add a pre-mortem section addressing at least 3 failure modes with mitigations.

9. **No execution mode specified.**
   The spec frontmatter does not include `exec:` mode. Given the spec describes a documentation-only deliverable with clear scope, `exec:quick` seems appropriate. Without it, the implementer must guess at ceremony level.
   **Impact:** Minor process gap.
   **Suggested resolution:** Add `exec: quick` to frontmatter.

10. **The `~~placeholder~~` syntax is described inconsistently.**
    The spec says "tool-agnostic at its core (using ~~placeholder~~ syntax from the canonical spec)" and the acceptance criterion says "~~placeholder~~ syntax preserved throughout." But the spec also says to provide "concrete configuration examples for common defaults" and "complete MCP server config example" for 5 specific tools. These are in tension: either the document uses placeholders (portable) or it provides concrete examples (specific). The existing CONNECTORS.md resolves this by using placeholders in the portable pattern tables and concrete tool names in the examples/checklists sections. The spec should acknowledge this dual-mode approach rather than implying placeholders are used "throughout."
    **Impact:** Implementer may over-apply placeholders, making the guide less useful, or under-apply them, making it less portable.
    **Suggested resolution:** Clarify that portable pattern sections use `~~placeholder~~` while Quick Start and configuration checklist sections use concrete tool names.

---

## Consider

11. **The spec proposes no versioning or changelog strategy for CONNECTORS.md.**
    As connectors evolve (new MCP servers, deprecated tools, config schema changes), the guide will drift. Consider adding a "Last updated" header and a brief changelog section, or at minimum noting that the guide should be updated when the plugin's `.mcp.json` changes.

12. **No mention of testing or validation for the guide itself.**
    Documentation specs benefit from a "smoke test" criterion: have a fresh user (or a fresh Claude session) follow the guide and verify it works. Consider adding a testability criterion like "A new user with no prior SDD experience can follow the Quick Start without encountering undocumented steps."

13. **The "email-marketing" and "geolocation" connectors in the existing document are highly specific to one use case (the Distributor Finder case study).**
    The spec's omission of these may be intentional generalization, which is good for portability. But the case study section that uses them would become orphaned if they are removed from the connector table. Consider whether the case study should be preserved, moved, or dropped.

14. **The spec does not address how this guide relates to COMPANIONS.md.**
    CONNECTORS.md covers data source integrations (MCP servers). COMPANIONS.md covers companion plugins. Users may confuse these. A single sentence in each document cross-referencing the other ("For companion plugins, see COMPANIONS.md" / "For data source connectors, see CONNECTORS.md") would help.

15. **The 90-day/30-day rotation schedule is arbitrary without threat model context.**
    Different credentials have different risk profiles. An analytics read-only key does not need the same rotation cadence as a project tracker write token. Consider framing rotation as risk-proportional rather than calendar-fixed.

---

## Quality Score

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Completeness | 2 | Fails to account for the existing CONNECTORS.md (207 lines of content that would be overwritten or duplicated). Missing pre-mortem, execution mode, and file path. Drops 8 existing connectors without acknowledgment. |
| Clarity | 3 | Connector categories and portable patterns are clearly structured. But the relationship to existing content is ambiguous -- is this a rewrite, an extension, or a replacement? The MCP config example requirement is vague. |
| Testability | 2 | The "30 minutes" criterion is untestable as stated. "Discoverable path" is subjective. "Portable patterns" lack measurable criteria. The strongest ACs are the structural ones (categories documented, credential section exists, sync pairs documented). |
| Feasibility | 3 | The deliverable is feasible -- it is documentation, not code. But the risk of overwriting existing content that the spec does not reference is a practical feasibility concern. The MCP config examples require understanding of MCP config schemas that the spec does not provide. |
| Safety | 3 | No risk of production breakage (documentation only). However, credential management advice that is incomplete or incorrect could lead users to insecure configurations. The existing anti-patterns table is more safety-conscious than what the spec proposes. |

**Overall: 2.6 / 5**

---

## What Works Well

- **The three-tier connector taxonomy (Required / Recommended / Optional) is sound** and matches the existing structure. The portable pattern framework (credential storage, sync setup, configuration) for each category is a good organizational principle.

- **The bidirectional sync pattern concept is valuable.** Documenting how services interact with each other (not just with the plugin) is a genuine gap in most integration guides. The existing CONNECTORS.md already does this well, and the spec's recognition of this pattern is correct.

- **The `~~placeholder~~` convention is well-established** in the SDD plugin and the spec correctly identifies it as the portability mechanism. The convention is already used consistently in the existing document.

- **The environment variable matrix template is practical.** Showing where each credential lives across local/preview/production/CI environments is immediately useful for any developer setting up integrations.

- **The acceptance criterion "No references to specific workspace IDs, personal emails, or local paths" is important** for a portable guide and demonstrates awareness of the common pitfall of leaking personal configuration into shared documentation.

---

## Summary

The spec's fundamental problem is that it describes creating a document that already exists in a mature form. The existing CONNECTORS.md at 207 lines already covers all three connector tiers, credential management (with anti-patterns, runtime vs agent separation, and a decision framework), bidirectional sync patterns (6 pairs), environment variable matrices, platform configuration checklists, secrets management migration paths, and a real-world case study. The spec proposes content that in several areas (sync patterns, credential naming) is less detailed than what exists.

To pass review, the spec needs to:

1. Acknowledge the existing CONNECTORS.md as the baseline
2. Frame the work as a delta (what to add, modify, or remove -- and why)
3. Define what an "MCP server config example" looks like concretely
4. Replace or scope the "30 minutes" testability claim
5. Reconcile the connector list with the existing document (justify additions and removals)
6. Add pre-mortem failure modes per SDD methodology
7. Specify execution mode and file path

Without these revisions, implementation will either duplicate existing work or risk destroying content that the spec does not account for.
