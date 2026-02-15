# Adversarial Panel Review: CIA-426 — Build native SDD skills to replace superpowers dependency

**Reviewed by:** 4-persona adversarial panel
**Date:** 2026-02-15
**Spec type:** Feature (skill absorption / plugin consolidation)
**Parent:** CIA-423 (SDD Plugin v2.0)
**Reverses:** CIA-425 Tier 3 "Companion" decisions

---

## Security Skeptic Review: CIA-426

**Threat Model Summary:** This spec absorbs 4 skills from an external plugin (`superpowers`) into the SDD plugin. The security surface is narrow -- these are static instructional skill files, not runtime code -- but the absorption creates a single-plugin trust boundary that concentrates all methodology guidance in one artifact, and the spec omits any mention of how the new skills interact with the execution engine's agent dispatch capabilities.

### Critical Findings

None. This is a content migration of static skill markdown files. There are no new data flows, no new API integrations, no credential handling, and no runtime code introduced. The attack surface change is negligible.

### Important Findings

- **No content provenance or attribution model for absorbed skills:** The spec says "absorb/rewrite, not copy" but does not define what "rewrite" entails. If the superpowers plugin is licensed differently from SDD (Apache-2.0), wholesale absorption of its content without attribution could create a licensing violation. An attacker could use this as a DMCA/license takedown vector against the SDD marketplace listing. -> Verify the superpowers plugin license. If it is more restrictive than Apache-2.0, document attribution in each absorbed skill file. If it is MIT/Apache, note provenance in a comment header.

- **`pr-dispatch` skill could encode unsafe review patterns:** The spec says this skill covers "PR-level review dispatch" at Stage 6. If the skill instructs the agent to create PRs, request reviews, or merge code, it implicitly grants the agent write access to the repository. The skill content must not encode patterns that bypass branch protection, force-push, or auto-merge without human approval. -> Acceptance criteria should include: "No skill content instructs or implies bypassing branch protection rules, force-push, or auto-merge."

### Consider

- **Single-plugin failure blast radius increases:** Currently, if the superpowers plugin has a bug or is disabled, SDD still functions for Stages 0-4 and 7. After absorption, disabling SDD disables everything -- including debugging methodology during active implementation (Stage 5-6). This is the inverse of the risk mitigation that the companion model provided. The spec acknowledges this tradeoff ("superpowers plugin can be disabled without losing any SDD workflow capability") but frames it only as a benefit. Acknowledge the reverse: SDD becomes a single point of failure for the entire funnel.

- **`review-response` skill teaches "YAGNI pushback":** This means the skill instructs the agent to push back on reviewer requests. If misapplied, the agent could refuse legitimate security or compliance review feedback by invoking YAGNI. Ensure the skill content has guardrails: YAGNI pushback applies to scope creep, never to security, accessibility, or compliance findings.

### Quality Score (Security Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Auth boundaries | 4 | No new auth flows introduced. Existing execution engine boundaries unchanged. |
| Data protection | 5 | No new data handling. Skills are static instructional content. |
| Input validation | 4 | `pr-dispatch` and `review-response` process PR metadata -- ensure skill content does not instruct the agent to trust raw PR comment content as instructions. |
| Attack surface | 4 | Modest increase: 4 new skill files in the plugin, but all are read-only markdown. Net reduction in external dependencies. |
| Compliance | 3 | License provenance for absorbed content needs verification. |

### What the Spec Gets Right (Security)

- Explicitly stating "absorb/rewrite, not copy" signals intent to rethink the content for the SDD context rather than blindly importing external material.
- Removing a third-party dependency (superpowers) reduces supply-chain risk. One fewer external plugin to trust, audit, and keep updated.
- The deferred `code-review-excellence` decision is correct from a security standpoint -- generic review technique is the most likely to contain patterns that conflict with SDD's own adversarial-review security perspective.

---

## Performance Pragmatist Review: CIA-426

**Scaling Summary:** This spec adds 4 static markdown skill files to a Claude Code plugin. There is no runtime, no database, no API, and no compute involved. Performance concerns are limited to plugin load time, context window consumption, and skill discovery latency -- all of which are bounded and predictable.

### Critical Findings

None. The performance characteristics of this change are negligible in isolation.

### Important Findings

- **Plugin skill count growing without context budget analysis:** SDD currently has 20 skills registered in `marketplace.json`. This spec adds 4 more, bringing the total to 24. Claude Code loads skill metadata (name + description frontmatter) into context when matching user requests. At ~150-200 tokens per skill description, 24 skills consume ~3,600-4,800 tokens of skill-matching context. This is not problematic today, but the spec does not set a cap or define a pruning strategy. At N=40 skills, the matching overhead reaches ~8,000 tokens -- approximately 4% of a 200K context window consumed before any work begins. -> Establish a skill count budget or define a skill grouping/lazy-loading strategy before the plugin crosses 30 skills.

- **No measurement of skill trigger accuracy at 24 skills:** With 20 skills, trigger phrase overlap is already a concern (e.g., "review my spec" could match `adversarial-review`, `spec-workflow`, or the new `review-response`). Adding 4 more skills with overlapping domain language (debugging, ideation, review) increases the probability of mis-triggers. The spec does not define how to measure or test trigger accuracy. -> Add an acceptance criterion: "Skill trigger phrases tested against existing 20 skills to verify no ambiguous matches." The existing `self-test` command could be extended to cover this.

### Consider

- **Incremental context cost of skill content when invoked:** Each skill's full SKILL.md is loaded when triggered. The existing `adversarial-review` skill is ~200 lines. If each new skill is comparable, invoking one consumes ~2,000-3,000 tokens. This is fine individually, but if the execution engine loads multiple skills per task iteration (e.g., `debugging-methodology` + `execution-engine` during Stage 5-6), the combined load could reach 6,000-8,000 tokens per iteration. Over a 5-iteration retry budget, that is 30,000-40,000 tokens of repeated skill loading. -> Size-cap each new skill file (recommended: 300 lines max). Consider whether the execution engine should cache skill content across iterations rather than reloading.

- **Build/install time impact is zero** -- these are static files. No compilation, no dependency resolution, no network fetch at install time. This is a non-issue.

### Quality Score (Performance Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Scalability | 3 | 24 skills is fine; 40+ needs a grouping strategy. No cap defined. |
| Resource efficiency | 3 | Context window consumption per skill is bounded but unmeasured. No size caps specified. |
| Latency design | 5 | Static files. No latency concern. |
| Operational cost | 5 | No runtime cost. Removing superpowers dependency reduces install complexity. |
| Failure resilience | 4 | Single-plugin model means one bad skill file could prevent the entire plugin from loading. But this is inherent to the plugin architecture, not this spec. |

### What the Spec Gets Right (Performance)

- Absorbing skills into the existing plugin rather than creating a new plugin avoids the overhead of a second plugin load cycle.
- "Absorb/rewrite" rather than wholesale copy allows right-sizing each skill for the SDD context, potentially making them smaller and more focused than the originals.
- The deferred `code-review-excellence` avoids adding a fifth skill that would push context overhead further without clear SDD-funnel value.

---

## Architectural Purist Review: CIA-426

**Structural Summary:** This spec reverses a well-reasoned Tier 3 evaluation (CIA-425) based on a strategic override: "users should not need a separate plugin for capabilities within the SDD funnel." The architectural question is whether this consolidation improves or degrades the plugin's cohesion, and whether the reversal is principled or just convenient.

### Critical Findings

- **The reversal rationale contradicts the original separation principle without resolving the contradiction:** CIA-425 concluded these 5 skills operate at "the code/process layer" while SDD operates at "the spec/methodology layer." CIA-426 overrules this with "practically wrong for a methodology plugin" but does not refute the abstraction-layer argument -- it simply asserts that funnel ownership trumps layer separation. This leaves the plugin with a design tension: some skills teach methodology (spec-workflow, prfaq-methodology, adversarial-review), while the 4 new skills teach process/technique (debugging, brainstorming, PR management). The plugin's `description` in marketplace.json says it handles "spec to deployment" -- but debugging methodology and brainstorming are neither specs nor deployments; they are execution-time techniques. -> Update the plugin description and conceptual model to explicitly acknowledge two skill categories: (1) methodology skills (spec/review/funnel) and (2) execution discipline skills (debugging/ideation/PR workflow). Define what unifies them: "everything within the SDD funnel" rather than "everything at the spec layer."

- **No abstraction boundary defined between `debugging-methodology` and `execution-engine`:** The CIA-425 evaluation noted that `execution-engine` handles "task loop orchestration (state machine, retries, context resets)" while `systematic-debugging` handles "root cause investigation (reproduce, pattern, hypothesis, implement)." These are genuinely different concerns. Absorbing debugging into SDD means the plugin now has two skills that activate during Stage 5-6 with overlapping trigger conditions ("I'm stuck", "this isn't working", "how do I debug this"). The spec does not define which skill takes precedence or how they compose. -> Define the boundary explicitly: `execution-engine` owns loop control (retry, escalate, reset context). `debugging-methodology` owns investigation technique within a single task iteration (reproduce, hypothesize, verify). Document this in both skill descriptions and add cross-references.

### Important Findings

- **`ideation` skill creates a dual-coverage gap at Stage 0:** The spec says ideation covers "Stage 0 (pre-spec)" and replaces `superpowers:brainstorming`. But SDD already has `prfaq-methodology` which covers Stage 3 (PR/FAQ drafting) and the COMPANIONS.md funnel diagram shows brainstorming feeding INTO `write-prfaq`. If the new `ideation` skill also feeds into `write-prfaq`, the handoff boundary needs definition: when does the agent switch from ideation mode to spec-drafting mode? What artifact does ideation produce that prfaq-methodology consumes? -> Define the ideation-to-prfaq handoff: ideation produces a "design doc" or "idea brief" (define the artifact); prfaq-methodology consumes it as input to `/sdd:write-prfaq`. Without this, users will not know when to stop brainstorming and start spec-writing.

- **`pr-dispatch` and `review-response` are a tightly coupled pair but the spec treats them as independent skills:** These two skills represent two sides of the same interaction (requesting review and responding to review feedback). Implementing them as two independent skills with independent trigger phrases creates a risk of invoking one without awareness of the other. -> Consider whether these should be a single skill (`pr-review-cycle`) with two sections, or two skills with explicit cross-references. At minimum, each should reference the other in its description.

- **Dependency direction violation: SDD skills should not depend on external tool configuration:** The `pr-dispatch` skill will presumably instruct the agent to create PRs and request reviews on GitHub. This creates an implicit dependency on GitHub configuration (branch protection rules, required reviewers, CI checks). The skill content must be tool-agnostic or explicitly declare its GitHub dependency. -> Frame `pr-dispatch` as platform-neutral review dispatch discipline. If GitHub-specific instructions are needed, isolate them in a "GitHub" subsection that can be swapped for GitLab, Bitbucket, etc.

### Consider

- **Naming: `ideation` is too generic for the SDD context:** Every methodology plugin could have an "ideation" skill. Within SDD, this is specifically "pre-spec divergent exploration" -- the activity that happens before a PR/FAQ is drafted. A more SDD-specific name like `pre-spec-exploration` or `idea-to-brief` would make the skill's funnel position self-documenting and reduce trigger-phrase collisions with generic brainstorming requests.

- **Naming: `debugging-methodology` vs `systematic-debugging`:** The spec renames superpowers' `systematic-debugging` to `debugging-methodology`. This is consistent with SDD's naming convention (`prfaq-methodology`, `execution-engine`) but loses the "systematic" qualifier that distinguished it from ad-hoc debugging. Consider `systematic-debugging-methodology` or keeping `debugging-methodology` with a description that emphasizes the systematic approach.

- **COMPANIONS.md "superseded" section creates a maintenance burden:** The spec requires updating COMPANIONS.md to move superpowers Tier 3 entries to a "superseded" section. This means COMPANIONS.md must track both current companions and historical ones. Over time, this becomes a changelog rather than a recommendation document. Consider whether "superseded" entries belong in COMPANIONS.md or in a separate CHANGELOG.md or release notes.

### Quality Score (Architecture Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Coupling | 2 | `debugging-methodology` vs `execution-engine` boundary undefined. `pr-dispatch`/`review-response` coupling unaddressed. Implicit GitHub dependency in `pr-dispatch`. |
| Cohesion | 3 | The reversal adds execution-discipline skills to a methodology plugin. Cohesion decreases unless the plugin's conceptual model is updated. |
| API contracts | 2 | No handoff artifact defined between `ideation` and `prfaq-methodology`. No composition rules between `debugging-methodology` and `execution-engine`. |
| Extensibility | 4 | Standard skill file structure. Easy to add, modify, or remove individual skills. |
| Naming clarity | 3 | `ideation` is too generic. `debugging-methodology` is adequate. `pr-dispatch` and `review-response` are clear. |

### What the Spec Gets Right (Architecture)

- The strategic principle is sound: a methodology plugin should own its entire funnel. The CIA-425 evaluation optimized for layer purity at the cost of user experience. This reversal prioritizes funnel completeness.
- "Absorb/rewrite, not copy" is the correct approach. Wholesale copying would create maintenance divergence. Rewriting for the SDD context forces each skill to be positioned within the funnel.
- Deferring `code-review-excellence` demonstrates that the reversal is principled, not blanket. Generic technique skills that do not map to a specific SDD stage remain companions.
- The acceptance criterion "superpowers plugin can be disabled without losing any SDD workflow capability" is the right integration test -- it verifies the absorption is complete without requiring superpowers removal.

---

## UX Advocate Review: CIA-426

**User Impact Summary:** This spec eliminates a multi-plugin installation requirement for users who want the full SDD workflow. The UX improvement is real: one plugin instead of two. But the spec does not address the migration experience for existing users who already have superpowers installed, nor does it define how users discover that formerly-external capabilities are now built in.

### Critical Findings

- **No migration path for existing users:** The spec defines what the end state looks like (4 new native skills, superpowers demoted from "Recommended" to "Superseded") but says nothing about the transition. An existing SDD user who has superpowers installed will, after updating SDD, have duplicate skill coverage -- the native SDD skills AND the superpowers skills both responding to the same triggers. This creates confusion: which version fires? Does the user need to manually uninstall superpowers? Is there a deprecation notice? -> Add an acceptance criterion: "Migration guide for existing superpowers users included in release notes or COMPANIONS.md. Guide covers: (1) How to verify native skills are active, (2) Whether to uninstall superpowers, (3) What happens if both are installed simultaneously."

### Important Findings

- **No discoverability mechanism for the new skills:** A user who upgrades SDD will receive 4 new skills silently. There is no changelog, no first-run notification, no `/sdd:help` update that surfaces the new capabilities. The user who previously relied on superpowers' `brainstorming` must discover that SDD now has `ideation` -- but only if they read COMPANIONS.md or stumble upon the right trigger phrase. -> Define how users learn about new skills. Options: (1) Update `/sdd:index` command output to list all skills with stage mappings. (2) Add a "What's new in v2.0" section to the plugin README. (3) If the plugin architecture supports it, surface a one-time notification on first load after upgrade.

- **Cognitive load increase from 20 to 24 skills:** Users who interact with SDD via natural language must mentally model which skill they want. With 20 skills, this is already challenging. Adding 4 more increases the cognitive surface. The funnel diagram in COMPANIONS.md helps, but it is only visible if the user reads that file. -> Add a stage-to-skill mapping table directly in the `spec-workflow` skill (which is the primary "how does the funnel work" entry point). Users should be able to say "what skills apply at Stage 6?" and get a definitive answer.

- **`review-response` skill UX is unclear for the user who is not Cian:** The spec says this skill teaches "verify-before-implement discipline and YAGNI pushback." This assumes a specific workflow: one developer (Cian) working with one AI agent (Claude), receiving reviews from human reviewers. If other users adopt SDD, their review workflows may differ (team reviews, automated CI feedback, pair programming). The skill must be framed generically enough for these contexts. -> Frame `review-response` around universal principles (verify feedback, distinguish scope creep from legitimate concerns, respond with evidence) rather than a specific single-developer workflow.

### Consider

- **Skill trigger phrase UX testing:** With the addition of `ideation`, `debugging-methodology`, `pr-dispatch`, and `review-response`, the natural language surface expands significantly. Users might say "help me brainstorm" (should trigger `ideation`), "I'm stuck on a bug" (should trigger `debugging-methodology`, not `execution-engine`), "request a review" (should trigger `pr-dispatch`), or "how do I respond to this review" (should trigger `review-response`). These must be tested against the existing 20 skills to prevent surprise misfires. A user who says "review this" and gets `adversarial-review` instead of `pr-dispatch` will be confused. -> Include a trigger phrase test matrix in the implementation plan. At minimum, test 5 natural language variations per new skill against the full skill set.

- **The "superseded" framing in COMPANIONS.md may confuse users:** "Superseded" implies the external skill is obsolete. But if a user prefers the superpowers version (different framing, different detail level), the "superseded" label discourages them from using it. Consider "absorbed" or "now built-in" instead of "superseded" to convey that the capability moved rather than that the external version is wrong.

- **Developer integrator UX (plugin authors):** If other plugin authors were building on top of superpowers' skills (referencing them in their own companion docs), this absorption breaks their references. The spec does not consider the plugin ecosystem beyond SDD. This is likely a non-issue today (small ecosystem), but worth noting as the marketplace grows.

### Quality Score (UX Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| User journey | 2 | No migration path. No discoverability for new skills. Silent upgrade with potential duplicate coverage. |
| Error experience | 3 | Duplicate skill triggers (SDD + superpowers both installed) will produce confusing behavior. No guidance on resolution. |
| Cognitive load | 3 | 24 skills is manageable but no stage-to-skill mapping in primary documentation. Users must remember or discover skill names. |
| Discoverability | 2 | New capabilities are invisible unless user reads COMPANIONS.md or stumbles on trigger phrases. |
| Accessibility | 4 | Standard skill file format. No accessibility regression. |

### What the Spec Gets Right (UX)

- The core UX thesis is correct: requiring users to install a separate plugin for capabilities within the SDD funnel is bad UX. One plugin should cover the full workflow.
- Positioning each skill at a specific SDD stage (in the acceptance criteria) gives users a mental model for when each skill is relevant.
- The deferred `code-review-excellence` avoids adding a skill that would confuse users about the difference between spec-level review (adversarial-review) and code-level review (code-review-excellence) -- a distinction that is already subtle.

---

## Combined Panel Assessment

### Unanimous Findings (all 4 personas agree)

1. **The `ideation` to `prfaq-methodology` handoff is undefined.** Security sees a potential for ideation content to bypass spec validation. Performance sees redundant context loading if both skills fire. Architecture sees a missing API contract (what artifact does ideation produce?). UX sees user confusion about when to stop brainstorming and start spec-writing. **All four agree this handoff must be defined as an acceptance criterion.**

2. **`pr-dispatch` and `review-response` need explicit cross-referencing.** These are two halves of one interaction. All personas agree they should at minimum reference each other, and the boundary between them should be documented.

3. **The deferred `code-review-excellence` decision is correct.** All four personas agree this is the right call -- it is the least SDD-specific skill and its inclusion would create confusion with `adversarial-review`.

### Majority Findings (3+ personas agree)

1. **No migration path for existing superpowers users** (Security, Architecture, UX). The transition from external to native skills will create duplicate coverage, confusing trigger behavior, and potential licensing issues for users who have both installed. A migration guide is needed.

2. **`debugging-methodology` vs `execution-engine` boundary is undefined** (Performance, Architecture, UX). Both skills activate during Stage 5-6 with overlapping trigger conditions. The spec must define which owns what: loop control vs. investigation technique within a single iteration.

3. **Skill trigger phrase testing is needed** (Performance, Architecture, UX). At 24 skills, the probability of ambiguous trigger matches increases. The spec should include trigger phrase validation as an acceptance criterion.

4. **Plugin conceptual model needs updating** (Security, Architecture, UX). The plugin description says "spec to deployment" but the new skills teach execution-time technique (debugging, brainstorming). The self-description should acknowledge both methodology and execution-discipline skills.

### Unique Persona Contributions (found by only 1 persona)

| Persona | Finding | Value |
|---------|---------|-------|
| Security | License provenance for absorbed content needs verification | Medium -- real legal risk if superpowers has restrictive license |
| Security | `review-response` YAGNI pushback could override security feedback | Low-Medium -- edge case but worth a guardrail |
| Performance | Skill count budget: at N=40, matching overhead reaches ~8K tokens (~4% of context) | Medium -- forward-looking architectural constraint |
| Performance | Skill content size caps needed (recommended 300 lines max) | Medium -- prevents context bloat |
| Architecture | `ideation` naming is too generic; `pre-spec-exploration` better positions in funnel | Low -- naming preference with cohesion benefit |
| Architecture | COMPANIONS.md "superseded" section creates maintenance burden | Low -- operational cleanliness |
| UX | "Superseded" framing discourages valid preference for external version; use "now built-in" | Low -- tone improvement |
| UX | Existing ecosystem plugin authors may reference superpowers skills in their docs | Low -- small ecosystem today, future concern |

### Consolidated Severity Matrix

| Finding | Security | Performance | Architecture | UX | Overall Severity |
|---------|----------|-------------|--------------|-----|-----------------|
| Ideation-to-prfaq handoff undefined | Medium | Low | **Critical** | Important | **Critical** |
| No migration path for existing users | Important | -- | Important | **Critical** | **Critical** |
| debugging-methodology vs execution-engine boundary | -- | Important | **Critical** | Important | **Critical** |
| Skill trigger phrase testing needed | -- | Important | Important | Important | **Important** |
| Plugin conceptual model outdated | Consider | -- | Important | Important | **Important** |
| pr-dispatch/review-response cross-referencing | Consider | -- | Important | Consider | **Important** |
| License provenance verification | Important | -- | -- | -- | **Important** |
| Skill count budget / size caps | -- | Important | Consider | Consider | **Consider** |
| `ideation` naming too generic | -- | -- | Consider | Consider | **Consider** |
| COMPANIONS.md "superseded" framing | -- | -- | Consider | Consider | **Consider** |
| YAGNI pushback guardrail in review-response | Consider | -- | -- | -- | **Consider** |

### Panel Verdict: REVISE

**Rationale:** The strategic direction is sound -- funnel ownership is the right principle and the CIA-425 reversal is justified. However, the spec has three critical gaps that would cause implementation problems:

1. **The ideation-to-prfaq handoff artifact is undefined.** Without this, the agent will not know when to stop brainstorming and start writing specs, and users will experience a confusing boundary between two overlapping skills.

2. **The debugging-methodology vs execution-engine boundary is undefined.** Both skills activate during Stage 5-6 with no composition rules. The agent will not know which to invoke when a user says "I'm stuck."

3. **No migration path for existing users.** The spec assumes a greenfield install but existing users will have duplicate skill coverage from superpowers, creating confusing behavior.

**Required revisions before implementation:**

- [ ] Define the ideation output artifact and its handoff to prfaq-methodology
- [ ] Define the boundary between debugging-methodology (investigation technique) and execution-engine (loop control)
- [ ] Add migration guidance for existing superpowers users (what to do when both are installed)
- [ ] Add acceptance criterion: skill trigger phrases tested against existing 20 skills for ambiguity
- [ ] Verify superpowers plugin license compatibility with Apache-2.0

**Recommended (not blocking):**

- [ ] Update plugin description to acknowledge both methodology and execution-discipline skill categories
- [ ] Cross-reference pr-dispatch and review-response in each skill's description
- [ ] Establish skill count budget (cap or grouping strategy)
- [ ] Set skill file size cap (recommended 300 lines)
- [ ] Rename `ideation` to something more SDD-specific (e.g., `pre-spec-exploration`)
