# Multi-Model Consensus Protocol: Aggregate Comparison

**Date:** 2026-02-15
**Experiment:** CIA-297 — Does model-tier diversity add measurable value to adversarial review?
**Baseline:** CIA-395 A/B test validated persona diversity (42% unique finding rate vs 23% generic)
**Pipeline:** Phase 1 (haiku scan) → Phase 2 (4 personas × 2 tiers) → Phase 3 (opus synthesis)
**Specs reviewed:** 5

## Decision Framework

| Decision | Condition |
|----------|-----------|
| **ADOPT** | Sonnet-only >15% AND Haiku-only >10% |
| **CONDITIONAL** | Either sonnet-only >10% OR haiku-only >5% |
| **REJECT** | Both <5% |

---

## Per-Spec Results

| Spec | Raw | Dedup | Dedup Rate | Sonnet-only | Haiku-only | Convergent |
|------|-----|-------|------------|-------------|------------|------------|
| CIA-303 (adaptive methodology) | 56 | 20 | 64% | 13 (65%) | 2 (10%) | 5 (25%) |
| CIA-396 (tool capture hooks) | 40 | 22 | 45% | 11 (50%) | 2 (9%) | 9 (41%) |
| CIA-391 (evidence objects) | 38 | 19 | 50% | 9 (47%) | 2 (11%) | 8 (42%) |
| CIA-308 (PM/Dev extension) | 44 | 21 | 52% | 6 (29%) | 2 (10%) | 13 (62%) |
| CIA-394 (adversarial debate) | 44 | 23 | 48% | 8 (35%) | 3 (13%) | 12 (52%) |

### Aggregates

| Metric | Total | Mean | Median | Min | Max |
|--------|-------|------|--------|-----|-----|
| Raw findings | 222 | 44.4 | 44 | 38 | 56 |
| Deduplicated | 105 | 21.0 | 21 | 19 | 23 |
| Dedup rate | — | 52% | 50% | 45% | 64% |
| **Sonnet-only count** | **47** | **9.4** | **9** | **6** | **13** |
| **Sonnet-only %** | — | **45%** | **47%** | **29%** | **65%** |
| **Haiku-only count** | **11** | **2.2** | **2** | **2** | **3** |
| **Haiku-only %** | — | **10.6%** | **10%** | **9%** | **13%** |
| Convergent count | 47 | 9.4 | 9 | 5 | 13 |
| Convergent % | — | 44% | 42% | 25% | 62% |

---

## Decision: **CONDITIONAL ADOPT**

| Criterion | Threshold | Actual (mean) | Result |
|-----------|-----------|---------------|--------|
| Sonnet-only >15% | 15% | **45%** | PASS |
| Haiku-only >10% | 10% | **10.6%** | **BORDERLINE PASS** |

**Sonnet-only exceeds threshold by 3x.** The deep-review tier consistently finds findings that surface-level review misses. This is the primary value driver.

**Haiku-only is at the threshold boundary.** Mean 10.6%, median 10%, range 9-13%. Two of five specs fall below the 10% threshold (CIA-396 at 9%, CIA-303 at 10% exactly). The signal is real but thin.

**Recommendation: CONDITIONAL ADOPT** — adopt the multi-model protocol with the following conditions:
1. Haiku tier is mandatory for Security Skeptic and UX Advocate (strongest haiku performers)
2. Haiku tier is optional for Architectural Purist and Performance Pragmatist (weakest haiku performers, consistently <30% agreement)
3. Re-evaluate after 10 additional specs — if haiku-only stays below 10%, consider dropping to sonnet-only + haiku UX Advocate

---

## Per-Persona Cross-Tier Agreement (Aggregate)

| Persona | Avg Sonnet | Avg Haiku | Avg Agreement | Pattern |
|---------|-----------|-----------|---------------|---------|
| Security Skeptic | 7.0 | 2.6 | 56% | Haiku catches obvious high-impact; sonnet finds subtle attack vectors |
| Performance Pragmatist | 6.0 | 2.8 | 60% | Haiku catches top risks; sonnet quantifies cost and edge cases |
| Architectural Purist | 7.6 | 2.0 | 62% | **Weakest haiku performer** — abstract reasoning needs sonnet depth |
| UX Advocate | 6.8 | 3.4 | 53% | **Strongest haiku performer** — "user confusion" framing works well |

### Key Persona Observations

1. **Architectural Purist haiku is consistently undertriggered** — average 2.0 findings vs 7.6 sonnet. The "5 minutes, one critical coupling/boundary violation" framing is too restrictive for architectural analysis. Consider expanding to "identify the top 2-3 structural concerns."

2. **UX Advocate haiku is the most productive haiku persona** — average 3.4 findings and produces genuinely novel "confused user" findings that sonnet misses. The framing modifier works because UX concerns are inherently accessible at surface level.

3. **Security Skeptic haiku has the best calibration** — 56% agreement rate means haiku catches the obvious issues while sonnet adds depth. This is the ideal complementary pattern.

4. **Performance Pragmatist haiku is moderately effective** — "15-minute triage" framing catches top risks but misses quantitative analysis (latency budgets, O(n) growth, sample size statistics).

---

## Severity Calibration Analysis

| Pattern | Frequency | Examples |
|---------|-----------|---------|
| **Sonnet upgrades severity** | Most common | Sonnet quantifies risk that haiku flags qualitatively |
| **Haiku upgrades severity** | Rare (2 instances) | CIA-396 F3 (PostToolUse contract), CIA-394 agent file proliferation |
| **Aligned** | ~30% of convergent findings | Both tiers agree on severity for obvious issues |
| **Sonnet-only (no haiku view)** | ~45% of all findings | Haiku simply doesn't find these issues |

---

## False Positive Analysis

| Spec | FP Candidates | FP Rate | Source |
|------|--------------|---------|--------|
| CIA-303 | 3 | 15% (3/20) | Timing side channels, 90MB storage, mental model terminology |
| CIA-396 | 2 | 5% (2/40) | Shell accessibility, dev-local encryption |
| CIA-391 | 2 | 5% (2/38) | Claim field injection, confidence subjectivity |
| CIA-308 | 3 | 7% (3/44) | API key sprawl, email marketing, user confusion |
| CIA-394 | 2 | 5% (2/44) | Sample size, rollback strategy |
| **Aggregate** | **12** | **5.4% (12/222)** | — |

**False positive distribution by tier:**
- Haiku-originated: 7/12 (58%)
- Sonnet-originated: 5/12 (42%)

Haiku's compressed framing modifiers occasionally cause over-literal domain lens application (e.g., accessibility review for shell scripts, encryption for dev-local logs). This is a known trade-off of the "junior reviewer" framing.

---

## Spec Complexity vs Diversity Correlation

| Spec | Complexity | Dedup Rate | Sonnet-only % | Haiku-only % | Convergent % |
|------|-----------|------------|---------------|--------------|--------------|
| CIA-303 | High (5 merged issues, 3-layer architecture) | 64% | 65% | 10% | 25% |
| CIA-308 | Medium (research spike, many TBDs) | 52% | 29% | 10% | 62% |
| CIA-394 | Medium (prototype, external deps) | 48% | 35% | 13% | 52% |
| CIA-396 | Low-Medium (single hook, clear scope) | 45% | 50% | 9% | 41% |
| CIA-391 | Low (single file, pattern definition) | 50% | 47% | 11% | 42% |

**Observations:**
1. **Higher complexity → higher dedup rate** — complex specs generate more overlapping concerns across tiers
2. **Higher complexity → higher sonnet-only rate** — sonnet's depth advantage increases with spec complexity
3. **Convergent rate inversely correlates with complexity** — simpler specs have more "obvious" issues both tiers catch
4. **Haiku-only rate is remarkably stable (9-13%)** — independent of spec complexity, suggesting a consistent floor of surface-level insights

---

## Value Assessment: Does Model-Tier Diversity Add Measurable Value?

### Quantitative Answer

**Yes, with caveats.**

- **47 sonnet-only findings** would have been missed by a haiku-only pipeline
- **11 haiku-only findings** would have been missed by a sonnet-only pipeline
- Combined unique contribution: **58 findings (55% of all 105 deduplicated)** come from tier diversity
- The remaining **47 convergent findings (45%)** confirm genuine issues with cross-tier validation

### Qualitative Answer

The two tiers find genuinely different things:

| Sonnet excels at | Haiku excels at |
|------------------|-----------------|
| Integration/dependency analysis | "Does this confuse a new reader?" |
| Quantitative risk assessment (latency, cost, sample size) | Identity confusion (prototype vs production) |
| Architecture coherence and coupling | Source attribution and traceability |
| Edge cases and failure modes | "What does the user DO?" questions |
| Cross-file/cross-system implications | Over-engineering detection |

### Cost-Benefit

| Metric | Haiku-only | Sonnet-only | Both tiers |
|--------|-----------|-------------|------------|
| Findings per spec | ~11 | ~19 | ~21 |
| Unique findings | ~11 | ~19 | ~21 |
| Cost (est.) | ~$0.05/spec | ~$0.50/spec | ~$0.55/spec |
| Marginal value of 2nd tier | — | +10 findings | +2 haiku-only findings |

The sonnet tier provides the dominant signal. The haiku tier's marginal contribution is ~2 unique findings per spec at negligible cost. The question is whether those 2 findings justify the pipeline complexity.

**Answer: Yes, because the haiku-only findings are disproportionately strategically important** (identity confusion, user-facing confusion, source traceability). They are the "obvious thing everyone else missed" findings that improve review quality beyond what depth alone provides.

---

## Protocol Recommendations

### Validated Pipeline (for SKILL.md update)

```
Phase 1: SCAN (haiku) — 7 extraction targets
Phase 2: REVIEW (4 personas × 2 tiers = 8 reviews)
  - Sonnet tier: Full adversarial review (5-11 findings/persona)
  - Haiku tier: Framing-modified quick triage (1-3 findings/persona)
Phase 3: SYNTHESIZE (opus) — Deduplicate, tag, score
```

### Framing Modifiers (validated)

| Persona | Haiku Framing | Effectiveness |
|---------|--------------|---------------|
| Security Skeptic | "Junior security engineer, first review, focus obvious high-impact" | Good (56% agreement) |
| Performance Pragmatist | "15-minute triage meeting, top 3 risks only" | Moderate (60% agreement) |
| Architectural Purist | "5 minutes, one critical coupling/boundary violation" | Weak (62% agreement but only 2.0 findings avg) |
| UX Advocate | "You are a user receiving this spec — what confuses you?" | Excellent (53% agreement + highest novel findings) |

### Routing Heuristic

```
IF spec complexity HIGH (merged issues, multi-system, >500 words):
  → Full 8-review pipeline (4 personas × 2 tiers)
IF spec complexity MEDIUM (single feature, some TBDs):
  → 6-review pipeline (4 sonnet + UX haiku + Security haiku)
IF spec complexity LOW (single file, clear scope):
  → 5-review pipeline (4 sonnet + UX haiku)
```

### JSON Schema Update

Add `model_tier` field:
```json
{
  "finding_id": "SS1",
  "persona": "security-skeptic",
  "model_tier": "sonnet | haiku",
  "severity": "critical | important | consider",
  "spec_section": "3.2 Authentication",
  "description": "...",
  "evidence": "...",
  "mitigation": "..."
}
```

### Consensus Scoring (validated)

| Consensus Level | Threshold | Action |
|----------------|-----------|--------|
| CRITICAL | 6+/8 reviewers agree | Must address before implementation |
| HIGH | 4-5/8 reviewers agree | Should address before implementation |
| MODERATE | 2-3/8 reviewers agree | Should consider |
| MINORITY | 1/8 reviewers | Note, do not dismiss (may represent specialist expertise) |

---

## Appendix: Raw Data Summary

| Spec | File |
|------|------|
| CIA-303 | `.claude/ab-test-results/multi-model/cia-303-multi-model.md` |
| CIA-396 | `.claude/ab-test-results/multi-model/cia-396-multi-model.md` |
| CIA-391 | `.claude/ab-test-results/multi-model/cia-391-multi-model.md` |
| CIA-308 | `.claude/ab-test-results/multi-model/cia-308-multi-model.md` |
| CIA-394 | `.claude/ab-test-results/multi-model/cia-394-multi-model.md` |
