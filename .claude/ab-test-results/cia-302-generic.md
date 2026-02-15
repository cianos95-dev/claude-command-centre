# Adversarial Review: CIA-302

**Spec:** SDD Plugin: Stage 7 analytics integration + data plugin compatibility analysis
**Reviewer:** Generic (baseline)
**Date:** 2026-02-15

**Recommendation:** REVISE

---

## Critical Findings

1. **The spec conflates five loosely coupled deliverables into a single issue, making scope ungovernable.**

   The five sections are: (1) document the observability stack in CONNECTORS.md, (2) create an observability patterns skill, (3) define a plugin structural validation layer around cc-plugin-eval, (4) write a compatibility analysis of Anthropic's data plugin, (5) extract OTEL patterns from personal infra. These share a thematic connection ("Stage 7 verification tooling") but have no implementation dependency on each other. An implementer can complete section 4 without touching section 1. They can finish section 3 without any knowledge of section 5. When five independent deliverables live in one issue, acceptance criteria become ambiguous -- which criterion maps to which deliverable? -- and partial completion is difficult to evaluate. The quality-scoring skill (which drives `/sdd:close`) scores coverage as "every acceptance criterion explicitly addressed with evidence," but here the criteria cross five separate concerns, meaning a single incomplete section blocks closure of four complete ones.

   **Why it blocks:** An implementer cannot reason about scope, estimate effort, or track progress for a single issue that contains five independent workstreams. The `exec:pair` mode implies collaborative iteration, but on which of the five sections? If the pair session focuses on the data plugin analysis, the observability documentation sits untouched. The issue will either be partially completed and left open indefinitely, or the implementer will rush through sections to close it, producing shallow output across all five.

   **Suggested resolution:** Split into three issues minimum: (A) CONNECTORS.md observability stack documentation + placeholder guidance finalization (sections 1, 2, 5 -- these are edits to the same file), (B) Plugin structural validation layer (section 3 -- new content with CI integration), (C) Data plugin compatibility analysis (section 4 -- standalone research deliverable). Each gets its own acceptance criteria, its own estimate, and can be closed independently. The current issue becomes a tracking parent.

2. **Section 3 (Plugin Structural Validation Layer) references CIA-413 and CIA-303 without establishing what those issues specify, creating phantom dependencies.**

   The spec states: "cc-plugin-eval (CIA-413)" and "/insights (CIA-303)" and "feeds into the adaptive methodology loop (CIA-303)." An implementer reading this spec cannot determine: what CIA-413 specifies about cc-plugin-eval integration (is it a CI setup issue? a configuration issue? a documentation issue?), what CIA-303 specifies about /insights (is it the same as the insights-pipeline skill that already exists?), or what the "adaptive methodology loop" means concretely. The three-layer monitoring stack table is clear in its categories but vague in its integration contract. "How cc-plugin-eval integrates with existing CI" is the deliverable, but the spec provides no constraints on what that integration should look like -- a single paragraph in CONNECTORS.md? A new skill? A GitHub Actions workflow file?

   **Why it blocks:** Without knowing the scope of CIA-413 and CIA-303, the implementer cannot determine what this spec's section 3 must produce versus what those other issues produce. There is a real risk of either duplicating work across three issues or leaving gaps between them. The acceptance criterion "Plugin structural validation section added (cc-plugin-eval integration, CI gates, metrics)" does not specify the artifact type (documentation section? code? configuration?), the location (CONNECTORS.md? a new file? the skills directory?), or the depth expected.

   **Suggested resolution:** Either (a) inline the relevant constraints from CIA-413 and CIA-303 so this spec is self-contained, or (b) explicitly state what this issue does NOT cover and defer it to those issues, or (c) split section 3 into its own issue that blocks on CIA-413 completion. At minimum, specify: what artifact is produced, where it lives, and what "integration with existing CI" means (a documented pattern, a workflow file, or a configuration guide).

3. **No acceptance criteria are testable in the quality-scoring sense.**

   The five acceptance criteria are:
   - "Observability stack documented in CONNECTORS.md" -- what constitutes "documented"? A table? A narrative? A configuration example? The existing CONNECTORS.md already has a `~~observability~~` row in the Optional connectors table (line 32). Does this criterion mean expanding that row, adding a new section, or replacing the Optional table entry with a Required one?
   - "Stage 7 verification tool guidance created" -- created where? As a skill? In CONNECTORS.md? In a new document? What does "guidance" mean -- decision heuristics? Step-by-step instructions? Configuration templates?
   - "Plugin structural validation section added" -- section of what document? See critical finding #2.
   - "Data plugin compatibility section added to plugin docs" -- which plugin docs? CONNECTORS.md? COMPANIONS.md? A new file?
   - "Placeholder guidance finalized" -- "finalized" is not measurable. Finalized means the strikethrough placeholders (`~~analytics~~`, `~~error-tracking~~`, `~~observability~~`) in CONNECTORS.md are... what? Replaced with concrete defaults? Expanded with selection heuristics? Left as-is but with adjacent guidance text?

   None of these criteria specify: the artifact (file path), the definition of done (measurable state), or how to verify completion (test, review, or evidence).

   **Why it blocks:** The quality-scoring skill's Coverage dimension requires "every acceptance criterion explicitly addressed with evidence." An acceptance criterion like "documented in CONNECTORS.md" has no measurable threshold. Two reviewers could disagree on whether a three-line table entry satisfies "documented." The spec will fail adversarial review at closure time because the criteria are too vague to score.

   **Suggested resolution:** Rewrite each criterion with the pattern: "[Artifact] at [location] contains [specific content] that [verifiable property]." For example: "CONNECTORS.md contains a new 'Observability Stack' section under 'Recommended Connectors' with a table mapping each tool (PostHog, Sentry, Honeycomb, Vercel Analytics) to its SDD funnel stage, purpose, and configuration requirements."

---

## Important Findings

4. **The observability stack table in the scope section is specific to the spec author's personal tooling, but the SDD plugin is portable.**

   The spec specifies PostHog, Sentry, Honeycomb, and Vercel Analytics as the stack. The SDD plugin's CONNECTORS.md explicitly uses `~~placeholder~~` syntax to maintain tool-agnosticism. The existing entries are `~~analytics~~` (examples: PostHog, Amplitude, Mixpanel), `~~error-tracking~~` (examples: Sentry, Bugsnag), and `~~observability~~` (examples: Honeycomb, Datadog). The spec's section 1 reads as if these four tools should be documented as THE stack, not as examples within the placeholder framework. This would break the portability contract that CONNECTORS.md was designed around.

   **Impact:** If the implementer writes "PostHog is the analytics tool for Stage 7" rather than "~~analytics~~ (e.g., PostHog) serves Stage 7 verification," the document becomes personal configuration rather than a portable guide. Users who use Amplitude or Datadog would need to mentally translate, which defeats the purpose of the placeholder system.

   **Suggested resolution:** Frame the four tools as the "reference implementation" or "worked example" within the existing placeholder framework. The portable pattern documentation stays generic; a new "Reference Stack" or "Example Configuration" section shows how one concrete stack maps to the abstract connectors.

5. **The data plugin compatibility analysis (section 4) is well-researched but has no clear output artifact.**

   The spec contains a thorough analysis of Anthropic's `data` plugin: architecture, connectors, overlap assessment, gaps, and integration opportunities. This is excellent research. But the acceptance criterion says "Data plugin compatibility section added to plugin docs." Which docs? COMPANIONS.md evaluates companion plugins with a specific framework (the Tier 3 Overlap Evaluation table). If the data plugin is a companion, it belongs there. If it is a connector, it belongs in CONNECTORS.md. If it is a potential future integration, it might belong in `docs/competitive-analysis.md` (which already exists). The spec does not specify which classification the data plugin falls into, so the implementer must decide where to put it, which is a design decision the spec should make.

   **Impact:** The data plugin straddles the companion/connector boundary. Its `/validate` command could extend SDD's adversarial review (companion behavior). Its data connectors (Snowflake, BigQuery) are data sources (connector behavior). Placing it in the wrong document creates a precedent that confuses the companion vs connector distinction.

   **Suggested resolution:** Explicitly classify the data plugin: is it a companion (methodology extension) or a connector (data source)? If companion, add it to COMPANIONS.md's Tier 3 Overlap Evaluation table with a formal decision (Companion, Extend, or Absorb). If connector, add relevant entries to CONNECTORS.md. If both, document the companion aspects in COMPANIONS.md and the connector aspects in CONNECTORS.md with cross-references.

6. **Section 2 (Observability Patterns Skill) is described as "guidance" but labeled as a skill in the scope.**

   The spec says "Create guidance for ~~analytics~~, ~~error-tracking~~, and ~~observability~~ connector selection at Stage 7." The SDD plugin already has 20 skills in `skills/`. A new skill requires a `skills/<name>/SKILL.md` file with frontmatter (name, description, trigger phrases) and structured content. The spec does not specify whether this is a new skill (which file? what trigger phrases?) or guidance added to an existing location (CONNECTORS.md? the quality-scoring skill?). The strikethrough on the connector names (`~~analytics~~`, `~~error-tracking~~`, `~~observability~~`) is ambiguous -- does it mean the guidance IS the placeholder expansion, or that those placeholders are being superseded?

   **Impact:** Without clarity on artifact type, the implementer may produce a section in CONNECTORS.md when a skill was intended, or vice versa. If it is a skill, it needs integration with the funnel mapping in COMPANIONS.md's "How Companions Fit the Funnel" section and the Tool-to-Funnel Reference table in CONNECTORS.md.

   **Suggested resolution:** Specify whether this is (a) a new skill at `skills/observability-selection/SKILL.md`, (b) a new section in CONNECTORS.md, or (c) an expansion of the existing placeholder entries. If a skill, provide the skill name and at least 3 trigger phrases.

7. **The spec has no pre-mortem or failure mode analysis.**

   Per the SDD methodology, specs should include failure mode analysis. This spec has none. Relevant failure modes include:
   - (a) The observability documentation becomes stale as tool ecosystems evolve (Honeycomb pricing changes, PostHog adds new features, Sentry changes their SDK).
   - (b) The cc-plugin-eval CI integration creates a release gate that produces false negatives, blocking releases for structural changes that are intentionally breaking.
   - (c) The data plugin compatibility analysis becomes outdated immediately if Anthropic ships a v2 of the data plugin.
   - (d) The three-layer monitoring stack creates confusion about which layer to check when something goes wrong -- users debug in Honeycomb when the issue is in cc-plugin-eval, or vice versa.
   - (e) The OTEL patterns extracted from personal infra are too specific to the spec author's environment and cannot be generalized.

   **Impact:** Without pre-mortem analysis, the implementation will not include mitigations for these realistic failure scenarios.

   **Suggested resolution:** Add a pre-mortem section covering at least 3 failure modes with mitigations. Focus especially on staleness (how will documentation stay current?) and false negatives in CI gates (how will cc-plugin-eval handle intentional structural changes?).

8. **The estimate is missing, and `exec:pair` may be the wrong execution mode.**

   The spec has `exec:pair` but no effort estimate. Given five independent deliverables, the total scope is likely 2-4 hours if sections 1/2/5 are documentation edits and sections 3/4 are research + documentation. But `exec:pair` implies human-in-the-loop collaboration, which is appropriate for uncertain scope -- yet sections 1 and 5 (documenting a decided stack and extracting OTEL patterns) are not uncertain. Section 4 (data plugin analysis) is already substantially written in the spec itself. The only genuinely uncertain section is 3 (cc-plugin-eval integration), which depends on external issues. This suggests `exec:pair` is being applied too broadly -- some sections should be `exec:quick` and section 3 should be `exec:checkpoint` (pause at milestones to confirm integration approach).

   **Impact:** Without an estimate, the quality-scoring skill cannot assess whether the implementation effort matches expectations. Without the right execution mode per deliverable, the implementer will either over-ceremony simple documentation tasks or under-ceremony the CI integration work.

   **Suggested resolution:** Add estimates per section (or per sub-issue if split per critical finding #1). Consider `exec:quick` for documentation sections and `exec:checkpoint` for the cc-plugin-eval integration.

9. **Section 5 (OTEL Patterns) conflates personal infrastructure with plugin documentation.**

   The spec says: "Honeycomb OTEL config is personal infra (CIA-286 scope). Extract reusable OTEL setup patterns into CONNECTORS.md if generalizable to other SDD users." The conditional "if generalizable" is not an acceptance criterion -- it is an implementation judgment call. The spec should decide: are there generalizable patterns or not? If yes, specify what they are (trace naming conventions? span structure for funnel stages? sampling strategies?). If unknown, this is a spike that should be estimated as discovery work, not documentation work.

   **Impact:** An implementer may spend time analyzing personal OTEL config, conclude nothing is generalizable, and produce zero output for this section. That is a valid outcome for a spike but would fail a documentation acceptance criterion. Alternatively, they may force-fit personal patterns into the portable framework, producing documentation that only works for one configuration.

   **Suggested resolution:** Either (a) pre-identify the specific OTEL patterns to extract (e.g., "trace naming convention: `sdd.stage.<N>.<action>`; span attributes: `sdd.issue_id`, `sdd.exec_mode`") or (b) reclassify this section as a spike with its own acceptance criterion ("Decision documented: OTEL patterns are/are not generalizable, with rationale").

---

## Consider

10. **The three-layer monitoring stack (structural/runtime/app-level) is a valuable conceptual framework that deserves its own documentation artifact.**

    The table in section 3 -- cc-plugin-eval for structural validation, /insights for runtime observability, PostHog/Sentry/Honeycomb for app-level analytics -- is the most architecturally significant content in this spec. It defines how monitoring works across the entire SDD lifecycle. This framework transcends any single section of CONNECTORS.md or any single skill. Consider whether this deserves a dedicated document (e.g., `docs/monitoring-architecture.md`) or a section in the README that explains the monitoring philosophy.

11. **The data plugin's `/validate` command is flagged as a potential extension point for adversarial review, but the adversarial-review skill already has a well-defined methodology.**

    The spec suggests "Data plugin `/validate` -> extend SDD adversarial review with data quality checks." The existing `adversarial-review` skill operates at the spec level (multi-perspective stress testing). Extending it with data quality checks would change its scope from methodology review to data validation. Consider whether this is truly an extension of adversarial review or a separate concern that should be documented as a standalone integration pattern.

12. **The spec references "the adaptive methodology loop (CIA-303)" without defining what that loop is.**

    If CIA-303 defines an adaptive methodology loop, that concept should be at least summarized here so a reader can understand what "feeds into" means. Does cc-plugin-eval's structural validation output trigger methodology adjustments? Does it update skill weights? Does it modify funnel stage gates? Without knowing what the loop does, the implementer cannot document how structural validation feeds into it.

13. **CONNECTORS.md already has a Tool-to-Funnel Reference table (lines 44-55) that maps connectors to stages.**

    The spec's observability stack table maps tools to stages, but it does not reference the existing Tool-to-Funnel Reference table. The implementer should update that table rather than creating a parallel mapping. Consider specifying that the existing table should be updated to reflect the decided stack rather than documented in a new section.

14. **The `~~placeholder~~` strikethroughs in the acceptance criteria are ambiguous notation.**

    The acceptance criterion reads: "~~analytics~~, ~~error-tracking~~, ~~observability~~ placeholder guidance finalized." The strikethroughs could mean: (a) these placeholders are being deprecated/removed, (b) these are the placeholder names being referenced (using the established `~~name~~` convention), or (c) these are being crossed out as already done. In the spec body, they appear with strikethroughs in section 2 as well. If these are being superseded by the decided stack, the spec should say so explicitly. If they are being retained as placeholders with added guidance, the strikethrough is misleading.

---

## Quality Score

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Completeness | 2 | Five deliverables in one issue with no clear artifact specifications. Missing pre-mortem, missing estimate, missing file paths for outputs. References two external issues (CIA-413, CIA-303) without inlining their constraints. Section 5 is conditional ("if generalizable") which is not an acceptance criterion. |
| Clarity | 3 | The scope section is well-structured with clear tables and bullet points. The data plugin analysis (section 4) is the strongest section -- thorough, specific, and actionable. But artifact locations are unspecified throughout, the relationship to existing CONNECTORS.md content is ambiguous, and the strikethrough notation is confusing. |
| Testability | 1 | No acceptance criterion specifies an artifact location, a measurable definition of done, or a verification method. "Documented" and "created" and "added" and "finalized" are not testable predicates without specifying what, where, and how much. The quality-scoring skill cannot produce a Coverage score against these criteria. |
| Feasibility | 3 | Each individual section is feasible. The data plugin analysis is already substantially complete in the spec itself. Documentation sections (1, 2, 5) are straightforward edits. Section 3 is feasible but depends on external issues (CIA-413, CIA-303) whose status is unknown. The concern is not whether the work can be done, but whether it can be done coherently as a single issue. |
| Safety | 4 | No risk of production breakage. Documentation changes only. The cc-plugin-eval CI gate (section 3) has a theoretical false-negative risk that could block releases, but this is downstream of this spec. The data plugin analysis is read-only research. The OTEL patterns extraction is scoped as conditional. |

**Overall: 2.6 / 5**

---

## What Works Well

- **The data plugin compatibility analysis (section 4) is thorough and well-structured.** It identifies the architecture, connectors, overlap, gaps, and integration opportunities with specificity. The observation that the data plugin assumes warehouse/SQL access while PostHog and Sentry use APIs is a genuine architectural insight that would be lost in a less careful analysis.

- **The three-layer monitoring stack concept (structural / runtime / app-level) is a genuinely useful framework.** It clearly delineates what each layer monitors, when it runs, and what tools serve each purpose. This is the kind of architectural thinking that makes the SDD plugin's verification story coherent rather than ad hoc.

- **The spec correctly identifies the gap that cc-plugin-eval fills.** The observation that v1.3.0 progressive disclosure extraction created a monitoring gap for structural validation is a specific, traceable justification for new tooling. This is the kind of "what could go wrong" reasoning that should drive tooling decisions.

- **The merger of CIA-272 and CIA-286 into a single spec is appropriate at the thematic level.** Both deal with observability tooling for Stage 7. The consolidation avoids redundant context-setting across two specs. The problem is that the merged scope is too large for a single issue, not that the topics should not be discussed together.

- **The spec includes concrete tool names and versions** (sjnims/cc-plugin-eval, anthropics/knowledge-work-plugins/data) rather than vague references, making the research traceable and verifiable.

---

## Summary

CIA-302's primary problem is structural: it packs five independent deliverables into one issue without specifying where each deliverable lands, what "done" looks like for each, or how they relate to the existing CONNECTORS.md content. The data plugin analysis is strong standalone research. The three-layer monitoring framework is architecturally valuable. But the acceptance criteria are untestable, the artifact locations are unspecified, and the scope is too broad for a single issue with `exec:pair` mode.

To pass review, the spec needs to:

1. Split into at least three issues with independent acceptance criteria (or explicitly justify why a single issue is appropriate and provide per-section criteria)
2. Specify artifact locations for every deliverable (file path, section within file)
3. Rewrite acceptance criteria to be measurable: what artifact, where, containing what, verifiable how
4. Resolve the relationship between the decided stack (PostHog/Sentry/Honeycomb/Vercel Analytics) and the existing `~~placeholder~~` framework in CONNECTORS.md
5. Inline or summarize the relevant constraints from CIA-413 and CIA-303 so section 3 is self-contained
6. Add pre-mortem failure modes (staleness, CI false negatives, data plugin versioning)
7. Add effort estimates, and reconsider `exec:pair` for sections that are straightforward documentation
8. Decide whether section 5 is a documentation task or a spike, and set the acceptance criterion accordingly
