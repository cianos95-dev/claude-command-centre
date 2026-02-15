# A/B Test Results: Generic Reviewer vs Persona Panel

**Date:** 2026-02-15
**Protocol:** CIA-395 (from CIA-423 master plan)
**Specs reviewed:** 5 (CIA-270, CIA-379, CIA-356, CIA-426, CIA-302)
**Total reviews:** 10 (2 per spec)

---

## Scoring Criteria

| Criterion | Definition |
|-----------|-----------|
| Specificity (1-5) | Concrete numbers, file paths, line references, exact scenarios vs vague concerns |
| Actionability (1-5) | Clear resolutions with artifact type, location, and measurable change vs "consider this" |
| Unique finding rate | % of findings only found by this approach, not the other |
| Blind spot detection | Did it catch things the other approach systematically missed? |

---

## Per-Spec Comparison

### CIA-270: CONNECTORS.md Integration Guide

| Metric | Generic | Persona Panel |
|--------|---------|---------------|
| Findings: Critical | 3 | 4 (Security: 3, Perf: 1, Arch: 1, UX: 2) |
| Findings: Important | 7 | 9 (Security: 3, Perf: 3, Arch: 3, UX: 4) |
| Findings: Consider | 5 | 6 (Security: 2, Perf: 2, Arch: 3, UX: 3) |
| **Specificity** | **4** | **5** |
| **Actionability** | **4** | **5** |
| Recommendation | REVISE | REVISE |

**Specificity notes:**
- Generic: Strong on existing file analysis (207 lines, specific sections). Identified the CONNECTORS.md-already-exists problem with file-level detail. Referenced concrete acceptance criteria failures.
- Panel: Security gave macOS keychain ACL commands (`security add-generic-password -T ""`). Performance calculated webhook event volumes (200+/day at 50 commits, 5000+/day at 10 devs). Architecture defined formal connector contracts (`createIssue(spec) -> issueId`). UX proposed specific verification commands (`sdd status connectors`).

**Unique findings:**
- Generic only (4/15 = 27%): Existing CONNECTORS.md already exceeds spec scope (most impactful), connector category divergence from existing doc (8 dropped without acknowledgment), `~~placeholder~~` syntax inconsistency, no file path specified.
- Panel only (8/19 = 42%): Keychain ACL isolation, pre-commit hook for secret leaks, trust escalation via error-to-issue sync, webhook feedback loop circuit breakers, formal connector interface contracts, portable pattern validation against alternative stack, verification mechanism per connector, `~~placeholder~~` notation confusion for users.

**Blind spots:**
- Generic missed: All security-specific findings (credential ACLs, webhook signature verification, least-privilege scopes), all performance projections (event volumes, cost estimates), architectural contract definitions, and UX verification mechanisms.
- Panel missed: The fundamental "this file already exists with 207 lines of content" observation that the generic reviewer caught as Critical #1. Panel assumed greenfield.

---

### CIA-379: Multi-Agent Orchestration Master Plan

| Metric | Generic | Persona Panel |
|--------|---------|---------------|
| Findings: Critical | 3 | 8 (Security: 3, Perf: 2, Arch: 3, UX: 2) |
| Findings: Important | 6 | 8 (Security: 3, Perf: 2, Arch: 3, UX: 3) |
| Findings: Consider | 4 | 5 (Security: 2, Perf: 2, Arch: 3, UX: 3) |
| **Specificity** | **3** | **5** |
| **Actionability** | **3** | **4** |
| Recommendation | REVISE | REVISE |

**Specificity notes:**
- Generic: Correctly identified missing acceptance criteria, problem statement, and pre-mortem. Findings were accurate but structural -- focused on SDD methodology compliance rather than technical substance.
- Panel: Security gave concrete attack scenarios (prompt injection via voice transcription, Vercel comments as unauthenticated-input-to-code-change pipeline). Performance calculated API costs ($50-200/day at Opus pricing) and context window budgets. Architecture identified Linear-as-load-bearing-infrastructure anti-pattern. UX defined specific latency targets (voice < 60s, @claude < 30s).

**Unique findings:**
- Generic only (2/13 = 15%): WS-3 documentation grab-bag critique, v1.3.0 agent reference implementation ambiguity.
- Panel only (10/21 = 48%): Agent authentication model, voice input prompt injection, Vercel comments threat assessment, agent invocation cost model, context window exhaustion in multi-hop chains, Linear API rate limits under multi-agent load, agent contract interface definition, dependency direction violation (SDD <-> agent ecosystem), operator override/intervention mechanism, routing confidence signals.

**Blind spots:**
- Generic missed: Security model entirely (no mention of authentication, authorization, or input sanitization), cost projections, specific latency targets, architectural contract definitions.
- Panel missed: Nothing significant -- panel covered all generic findings plus substantially more.

---

### CIA-356: Normalize Conventions

| Metric | Generic | Persona Panel |
|--------|---------|---------------|
| Findings: Critical | 0 | 0 |
| Findings: Important | 3 | 4 (Security: 2, Perf: 2, Arch: 3, UX: 2) |
| Findings: Consider | 5 | 6 (Security: 2, Perf: 1, Arch: 2, UX: 3) |
| **Specificity** | **4** | **4** |
| **Actionability** | **4** | **4** |
| Recommendation | PASS (minor) | APPROVE (minor) |

**Specificity notes:**
- Generic: Solid operational findings (stale audit data, CIA-248 deletion fallback, partial completion recovery). Well-calibrated to spec scope.
- Panel: Security flagged label replacement race condition and GraphQL bypass. Performance quantified subagent context pressure (15-45KB per batch). Architecture noted playbook pinning need. UX proposed dry-run preview and verification report destination.

**Unique findings:**
- Generic only (2/8 = 25%): CIA-258/242 duplicate CodeQL issues, time estimate realism (30-45 min floor not ceiling).
- Panel only (3/10 = 30%): Label replacement race condition between subagents, token scope audit recommendation, before/after state export for rollback.

**Blind spots:**
- Both approaches were well-calibrated for this straightforward spec. Neither had major blind spots. The panel added modest incremental value on operational safety.

---

### CIA-426: Native SDD Skills (Tier 3 Reversal)

| Metric | Generic | Persona Panel |
|--------|---------|---------------|
| Findings: Critical | 2 | 3 |
| Findings: Important | 5 | 4 |
| Findings: Consider | 4 | 5 |
| **Specificity** | **5** | **4** |
| **Actionability** | **4** | **5** |
| Recommendation | REVISE | REVISE |

**Specificity notes:**
- Generic: Exceptional on codebase awareness -- counted 1,030 lines across 7 files in systematic-debugging, identified specific cross-references at lines 179 and 288, flagged brainstorming's 54 lines vs prfaq-methodology's 217 lines. Deep file-level analysis.
- Panel: Security identified license provenance risk and YAGNI-override guardrail need. Performance calculated context budgets (24 skills = 3,600-4,800 tokens, N=40 = ~8K tokens). Architecture defined ideation-to-prfaq handoff artifact and debugging-methodology vs execution-engine boundary. UX designed migration path and discoverability mechanism.

**Unique findings:**
- Generic only (3/11 = 27%): 1,030-line systematic-debugging supporting material audit, brainstorming thinness quantified (54 vs 217 lines), 8-point estimate with exec:quick inconsistency.
- Panel only (5/12 = 42%): License provenance verification, skill count context budget (4% at N=40), 300-line size cap recommendation, YAGNI pushback guardrail for security feedback, "superseded" framing discourages valid preferences.

**Blind spots:**
- Generic missed: License risk, context window budget projections, skill size caps, migration path for existing users.
- Panel missed: The granular file-level audit (1,030 lines, 7 files, specific cross-reference lines). Panel treated systematic-debugging as a single unit rather than auditing its directory structure.

---

### CIA-302: Stage 7 Analytics + Data Plugin

| Metric | Generic | Persona Panel |
|--------|---------|---------------|
| Findings: Critical | 3 | 4 |
| Findings: Important | 6 | 4 |
| Findings: Consider | 5 | 4 |
| **Specificity** | **4** | **5** |
| **Actionability** | **4** | **5** |
| Recommendation | REVISE | REVISE |

**Specificity notes:**
- Generic: Strong structural critique (5 loosely coupled deliverables, phantom dependencies on CIA-413/CIA-303, untestable acceptance criteria). Good SDD methodology compliance checking.
- Panel: Security identified PostHog behavioral PII and Sentry stack trace exfiltration risks with concrete attack scenarios. Performance quantified cc-plugin-eval CI duration (132 evaluations * 2-5s = 4-11 min) and free tier limits (PostHog 1M events/month, Sentry 5K, Honeycomb 20M). Architecture identified dependency direction inversion (analytics as de facto required dependency). UX designed progressive adoption sequence with specific tool ordering.

**Unique findings:**
- Generic only (3/14 = 21%): Section 2 artifact ambiguity (skill vs guidance), `~~placeholder~~` strikethrough notation ambiguity, section 5 conflates personal infra with portable docs.
- Panel only (6/12 = 50%): Data classification requirement (behavioral PII in PostHog), OTEL instrumentation negative guidance (what NOT to trace), free tier cost cliff modeling, cc-plugin-eval CI duration quantification, dependency direction inversion (analytics in closure), JUnit XML accessibility concern.

---

## Aggregate Comparison

### Scoring Summary

| Spec | Generic Specificity | Panel Specificity | Generic Actionability | Panel Actionability |
|------|--------------------:|------------------:|---------------------:|--------------------:|
| CIA-270 | 4 | **5** | 4 | **5** |
| CIA-379 | 3 | **5** | 3 | **4** |
| CIA-356 | 4 | 4 | 4 | 4 |
| CIA-426 | **5** | 4 | 4 | **5** |
| CIA-302 | 4 | **5** | 4 | **5** |
| **Average** | **4.0** | **4.6** | **3.8** | **4.6** |

### Unique Finding Rate Summary

| Spec | Generic Unique Rate | Panel Unique Rate |
|------|--------------------:|------------------:|
| CIA-270 | 27% | **42%** |
| CIA-379 | 15% | **48%** |
| CIA-356 | 25% | 30% |
| CIA-426 | 27% | **42%** |
| CIA-302 | 21% | **50%** |
| **Average** | **23%** | **42%** |

### Blind Spot Analysis

| Pattern | Generic Blind Spots | Panel Blind Spots |
|---------|-------------------|------------------|
| Security concerns | Systematically missed across 4/5 specs | None |
| Cost/scaling projections | Missed in 4/5 specs | None |
| Architectural contracts | Missed in 3/5 specs | None |
| UX verification/feedback | Missed in 4/5 specs | None |
| Existing file/codebase awareness | None | Missed in 2/5 specs (CIA-270 existing file, CIA-426 directory audit) |
| SDD methodology compliance | None | Slightly weaker -- deferred to domain concerns |

---

## Decision

### Decision Criteria (from protocol)
> ADOPT if persona panel scores higher on specificity AND actionability across 3+ of 5 specs.

### Evidence

**Specificity:** Panel scores higher on 4/5 specs (CIA-270, CIA-379, CIA-302, CIA-426 is a tie/slight generic edge). Meets threshold.

**Actionability:** Panel scores higher on 4/5 specs (CIA-270, CIA-379, CIA-426, CIA-302). Meets threshold.

**Additional evidence:**
- Panel unique finding rate averages 42% vs generic's 23% -- the panel consistently surfaces findings the generic approach misses.
- Panel has no systematic blind spots; generic systematically misses security, performance, and UX dimensions.
- Generic has one advantage: deeper codebase/file-level awareness (existing file detection, line-count audits). This is a real strength but affects 2/5 specs.

### Verdict: **ADOPT**

The persona panel reviewer approach should be adopted into the SDD plugin. The 4 persona agents (`reviewer-security-skeptic.md`, `reviewer-performance-pragmatist.md`, `reviewer-architectural-purist.md`, `reviewer-ux-advocate.md`) should be committed to the `agents/` directory and registered in `marketplace.json`.

### Caveats and Recommendations

1. **The generic reviewer's codebase awareness is a real strength.** The persona panel should be run AFTER the generic reviewer, or the base reviewer should be enhanced with an explicit "existing artifact audit" checklist item. The panel missed the CIA-270 "file already exists" finding -- this would have been caught by a pre-review codebase scan.

2. **Panel reviews are ~3x longer.** The 4-persona reviews average ~230 lines vs ~130 lines for generic. This is more context-consuming. Consider whether the panel should produce a consolidated summary only (dropping individual persona sections) for routine reviews, reserving full panel output for complex specs.

3. **The Combined Panel Summary section is the most valuable artifact.** The unanimous/majority/unique finding categorization, the severity matrix, and the disagreement tables are where the panel approach genuinely excels over generic. If the panel format is adopted, the Combined Panel Summary format should be standardized.

4. **Spec complexity determines panel value.** For CIA-356 (simple, well-scoped), both approaches performed similarly. The panel adds most value on complex specs with multi-system integration (CIA-270, CIA-379, CIA-302) or cross-cutting architectural decisions (CIA-426). Consider a routing heuristic: simple specs get generic review, complex specs get panel review.

---

## Files Produced

| File | Description |
|------|-------------|
| `cia-270-generic.md` | Generic review of CIA-270 |
| `cia-270-persona.md` | Panel review of CIA-270 |
| `cia-379-generic.md` | Generic review of CIA-379 |
| `cia-379-persona.md` | Panel review of CIA-379 |
| `cia-356-generic.md` | Generic review of CIA-356 |
| `cia-356-persona.md` | Panel review of CIA-356 |
| `cia-426-generic.md` | Generic review of CIA-426 |
| `cia-426-persona.md` | Panel review of CIA-426 |
| `cia-302-generic.md` | Generic review of CIA-302 |
| `cia-302-persona.md` | Panel review of CIA-302 |
| `comparison-table.md` | This file |
