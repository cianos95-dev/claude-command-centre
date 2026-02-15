## Adversarial Review: CIA-426

**Build native SDD skills to replace superpowers dependency (Tier 3 reversal)**

**Recommendation:** REVISE

---

### Critical Findings

1. **No definition of "absorb/rewrite, not copy" -- risk of accidental license violation or thin rebrand.**
   The spec says to "absorb/rewrite, not copy" but provides zero guidance on what substantive rewriting means. The superpowers plugin is Apache-2.0 licensed, so legal copying is permitted, but the real risk is that an implementer produces a cosmetic rename (swap `superpowers:` references for `sdd:`, adjust a few headings) and calls it done. That would create maintenance burden without genuine SDD integration. The spec needs a concrete definition: what makes a rewritten skill "SDD-native" versus a reskinned copy? Suggested test: each new skill must reference at least one SDD stage, one SDD state file (`.sdd-state.json` or `.sdd-progress.md`), and one existing SDD command or skill by name. If the skill would read identically with all SDD references removed, it has not been absorbed.
   -> **Resolution:** Add a "Definition of Done per skill" section that specifies the minimum SDD integration markers required for each rewrite.

2. **Systematic-debugging has 1,030 lines of supporting material across 7 files (root-cause-tracing, defense-in-depth, condition-based-waiting, test-pressure scenarios, find-polluter.sh). The spec accounts for none of this.**
   The acceptance criteria mention "4 new skill files in `skills/`" but systematic-debugging is not one file -- it is a skill directory with a main SKILL.md (296 lines) plus 6 reference files and a shell script. The requesting-code-review skill similarly ships a `code-reviewer.md` agent template. The spec treats each skill as a single file, which means either (a) the supporting materials get silently dropped, losing the most valuable parts of systematic-debugging, or (b) the implementer includes them without the spec having scoped that work, blowing the estimate.
   -> **Resolution:** Audit each source skill's full directory contents and explicitly list which supporting artifacts to absorb, rewrite, or drop. Update the acceptance criteria to say "4 new skill directories" not "4 new skill files."

---

### Important Findings

3. **Requesting-code-review ships an agent template (`code-reviewer.md`) that dispatches a subagent. SDD already has an `adversarial-review` skill with a different subagent dispatch model (multi-perspective reviewer). These will conflict in skill-matching.**
   When a user says "review this code" or "review this PR," which skill fires -- `adversarial-review` (spec-level, Stage 4) or the new `pr-dispatch` (code-level, Stage 6)? The trigger phrase collision is real. The existing adversarial-review description already includes phrases like "review my spec" and "is this spec ready," but a naive user asking for "review" will get unpredictable routing.
   -> **Resolution:** Spec must define explicit trigger-phrase boundaries for the new skills and update the existing adversarial-review description to sharpen the delineation. Consider naming the new skill `pr-review-dispatch` rather than just `pr-dispatch` to reduce ambiguity.

4. **The "superpowers can be disabled" acceptance criterion is untestable as written.**
   "superpowers plugin can be disabled without losing any SDD workflow capability" is the most important criterion but has no test procedure. How does an implementer verify this? There are cross-references inside superpowers skills to other superpowers skills (e.g., systematic-debugging references `superpowers:test-driven-development` and `superpowers:verification-before-completion` at lines 179 and 288). If those internal references are not rewritten or mapped to SDD equivalents, the absorbed skills will contain broken references.
   -> **Resolution:** Add a concrete test: "grep the entire `skills/` directory for `superpowers:` -- zero results. Then run `/sdd:self-test` and confirm no skill resolution failures." Also audit all internal cross-references in the 4 source skills and list the ones that must be remapped.

5. **Brainstorming skill (54 lines) is extremely thin compared to prfaq-methodology (217 lines). The value-add of absorbing it is unclear.**
   The superpowers brainstorming skill is essentially "ask one question at a time, propose 2-3 approaches, present design in sections." This is generic facilitation advice with no SDD-specific content. The spec positions it at "Stage 0 (pre-spec)" but prfaq-methodology already covers ideation-to-spec conversion with much more depth (inversion analysis, pre-mortem, structured questioning). Absorbing brainstorming risks creating a near-duplicate skill that fires instead of prfaq-methodology when users say "help me brainstorm."
   -> **Resolution:** Clarify the handoff boundary: does `ideation` replace brainstorming entirely, or does it become a lightweight "divergent exploration" precursor that explicitly hands off to `/sdd:write-prfaq`? The spec should state what ideation does that prfaq-methodology does NOT, or acknowledge this is a thin wrapper and adjust the estimate downward.

6. **Estimate of 8 points with `exec:quick` mode is internally inconsistent.**
   8 points suggests meaningful complexity. `exec:quick` suggests well-defined and simple. The systematic-debugging skill alone has 1,030 lines of source material to absorb and rewrite. There are cross-reference audits, trigger-phrase deconfliction, marketplace.json updates, COMPANIONS.md restructuring, and 4 separate skill directories to create. This is closer to `exec:tdd` or `exec:checkpoint` territory. Quick mode assumes a single-sitting implementation with no verification pauses, but the cross-cutting nature of this change (modifying COMPANIONS.md, marketplace.json, and creating 4 new skills that must not conflict with 20 existing ones) warrants at least checkpoint-level gating.
   -> **Resolution:** Either reduce scope (e.g., do only the two High-priority skills in this issue and defer Medium-priority ones) or upgrade the execution mode to `exec:checkpoint` with a gate after the first two skills are implemented.

7. **No versioning or migration strategy for existing users.**
   Users who currently have superpowers installed and rely on `superpowers:systematic-debugging` etc. will suddenly have two competing skill providers for the same capabilities. The spec does not address: (a) whether the COMPANIONS.md "superseded" section should tell users to uninstall superpowers, (b) whether there is a version bump (currently 1.3.0 in marketplace.json), or (c) what happens if both plugins remain installed and skill names collide.
   -> **Resolution:** Add a migration note to the spec: version bump to 1.4.0 (or 2.0.0 given the scope claim of "full funnel ownership"), COMPANIONS.md superseded section must include explicit "uninstall superpowers if you have SDD" guidance, and skill names must not collide with superpowers names (e.g., do not name the new skill `systematic-debugging` -- name it `debugging-methodology` as the table suggests).

---

### Consider

8. **The rationale overrides a reasoned technical evaluation (CIA-425) with a philosophical argument ("practically wrong for a methodology plugin"). This is legitimate -- product owners can override -- but the spec should acknowledge the tradeoff being accepted.**
   CIA-425 concluded that these skills operate at "different abstraction layers" and "complement rather than conflict." The reversal is a judgment call, not a correction of an error. Acknowledging the tradeoff (increased maintenance surface, potential for SDD-specific skills to drift behind superpowers updates) makes the decision more defensible and helps future maintainers understand why both versions exist in the ecosystem.

9. **developer-essentials:`code-review-excellence` is deferred but receives no tracking issue.**
   The spec says "deferred" but creates no follow-up mechanism. If this is truly intended for later, it should get its own backlog issue or be explicitly marked as "won't do" with a rationale.

10. **The code-reviewer agent template in requesting-code-review is a subagent prompt, not a skill. SDD's agent directory (`agents/`) already exists but is not mentioned in the spec.**
    If `pr-dispatch` absorbs the code-reviewer agent template, it should be placed in `agents/` and registered in marketplace.json's agent section (if one exists), not embedded in the skill file. The spec does not address this structural question.

11. **Receiving-code-review's tone-policing content ("NEVER say 'You're absolutely right!'", "NEVER use gratitude expressions") is user-preference material, not methodology.**
    When rewriting this for SDD, consider whether tone rules belong in a methodology plugin or should remain in the user's CLAUDE.md. The SDD version should focus on the verify-before-implement discipline and YAGNI pushback methodology, stripping the personality directives that are better handled at the user configuration level.

---

### Quality Score

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Completeness | 2 | Missing: supporting file audit, trigger-phrase plan, migration strategy, test procedure for "disabled" criterion, cross-reference remapping |
| Clarity | 4 | Rationale is well-articulated. Scope table is clear. Stage mapping is explicit. |
| Testability | 2 | Key acceptance criterion ("superpowers can be disabled") has no test procedure. No mention of self-test, grep validation, or skill-resolution checks. |
| Feasibility | 3 | Feasible but underestimated. Systematic-debugging alone is a significant rewrite. 8 points at quick mode is aggressive for 4 skills with supporting materials. |
| Safety | 3 | No breaking changes to existing skills, but skill-matching collisions (finding 3) and dual-plugin scenarios (finding 7) are unaddressed. |

---

### What Works Well

- **Stage mapping is explicit and correct.** Each skill is positioned at a specific SDD stage, making the "why absorb" argument concrete rather than abstract.
- **The reversal rationale is honest.** It directly states "intellectually clean but practically wrong" rather than pretending CIA-425 was technically flawed. This is good decision hygiene.
- **Scope is bounded.** Deferring code-review-excellence and limiting to 4 skills prevents the issue from becoming a full superpowers fork.
- **The priority split (High/Medium) is sensible.** Debugging and ideation are higher-value absorptions than PR dispatch mechanics, and the spec reflects this.
- **The relationship section is well-structured.** Tracing to CIA-425 (reverses), CIA-423 (parent), and the downstream impact (enables superpowers removal) gives clear lineage.
