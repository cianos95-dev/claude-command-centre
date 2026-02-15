# CIA-394 Multi-Model Review: Prototype structured adversarial debate (2-round multi-model)

**Date:** 2026-02-15
**Pipeline:** Phase 1 (haiku scan) → Phase 2 (4 personas × 2 tiers) → Phase 3 (opus synthesis)
**Raw findings:** 44 | **Deduplicated:** 23 | **Dedup rate:** 48%

## Diversity Metrics

| Metric | Count | % |
|--------|-------|---|
| **Sonnet-only findings** | 8 | 35% |
| **Haiku-only findings** | 3 | 13% |
| **Convergent findings** | 12 | 52% |
| **Total unique** | 23 | 100% |

### Per-Persona Cross-Tier Agreement

| Persona | Sonnet | Haiku | Converged | Agreement |
|---------|--------|-------|-----------|-----------|
| Security Skeptic | 7 | 3 | 3 | 43% |
| Performance Pragmatist | 6 | 2 | 2 | 33% |
| Architectural Purist | 8 | 3 | 4 | 50% |
| UX Advocate | 5 | 2 | 3 | 60% |

### Severity Calibration Gaps

| Finding | Sonnet | Haiku | Gap |
|---------|--------|-------|-----|
| Cost ceiling enforcement | Critical | High | Sonnet escalated |
| Tiebreaker model dependency | High | Not flagged | Haiku missed |
| Debate termination criteria | High | Moderate | Sonnet escalated |
| Agent file proliferation | Moderate | Critical | Haiku escalated |
| Validation criteria measurability | High | High | Aligned |

### False Positive Candidates (2/44 = 5%)

- "10+ test reviews insufficient sample size" — spec explicitly frames as prototype, 10 reviews appropriate for feasibility spike
- "Missing rollback strategy" — prototype produces review documents, not system state changes; no rollback needed

## Top 5 Convergent-Critical Findings

1. **UC-1 — No operational definition of "substantive disagreement"** (8 contributing: SS1, SH1, PS1, PH1, AS1, AH1, US1, UH1)
2. **UC-2 — Perplexity tiebreaker is uncontrolled external dependency** (5 contributing: SS2, SH2, PS2, AS2, AH2)
3. **UC-3 — Cost cap stated but unenforced** (4 contributing: SS3, PS3, PH2, AS3)
4. **UC-4 — "Persistent disagreement" branching logic undefined** (4 contributing: AS4, AH3, US2, UH2)
5. **UC-5 — Agent-to-orchestrator interface unspecified** (3 contributing: AS5, PS4, AH2)

These 5 = 24/44 raw findings (55%), confirming genuine systemic issues.

## All Unified Findings

### CRITICAL Consensus (6+/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| UC-1 | No operational definition of "substantive disagreement" | convergent | critical | SS1, SH1, PS1, PH1, AS1, AH1, US1, UH1 |
| UC-2 | Perplexity tiebreaker is uncontrolled external dependency | convergent | critical | SS2, SH2, PS2, AS2, AH2 |
| UC-3 | Cost cap stated but unenforced | convergent | critical | SS3, PS3, PH2, AS3 |

### HIGH Consensus (4-5/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| UC-4 | "Persistent disagreement" branching logic undefined | convergent | high | AS4, AH3, US2, UH2 |
| UC-5 | Agent-to-orchestrator interface unspecified | convergent | high | AS5, PS4, AH2 |
| UC-6 | No structured output schema for debate rounds | sonnet-only | high | SS4, AS6 |
| UC-7 | Validation requires controlled baseline (missed by single-model) | sonnet-only | high | PS5, SS5 |
| UC-8 | No error handling for model API failures mid-debate | convergent | high | SS6, PS6 |
| UC-9 | Codex availability and access model unaddressed | sonnet-only | high | SS7, AS7 |
| UC-10 | Resolution round has no structured format or decision criteria | convergent | high | US3, AS8 |

### MODERATE Consensus (2-3/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| UC-11 | 10 test reviews may not surface 30% disagreement rate reliably | convergent | moderate | PS1, UH1 |
| UC-12 | No spec for tiebreaker output integration | sonnet-only | moderate | US4 |
| UC-13 | Agent .md file YAML frontmatter schema not defined | convergent | moderate | AS4, AH1 |
| UC-14 | Token/context window limits for multi-round debate | sonnet-only | moderate | PS4 |
| UC-15 | No privacy/data leakage analysis for 3 model providers | sonnet-only | moderate | SS4 |
| UC-16 | "Extends Option C/D review" — Options C/D not defined in spec | convergent | moderate | US5, UH2 |
| UC-17 | Validation criteria conflate prototype feasibility with production readiness | sonnet-only | moderate | PS5 |
| UC-18 | No idempotency guarantee for re-running reviews | sonnet-only | moderate | PS6 |

### MINORITY (1/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| UC-19 | agent-peer-review plugin maturity unknown | haiku-only | low | SH3 |
| UC-20 | No accessibility consideration for review output format | haiku-only | low | UH2 |
| UC-21 | Missing threat model for adversarial manipulation by one model | sonnet-only | low | SS7 |
| UC-22 | No model version pinning across debate rounds | sonnet-only | low | AS8 |
| UC-23 | Plugin-dev v1.3.0 dependency not version-locked | haiku-only | low | AH3 |

## Phase 1 Scan Summary

Spec is a prototype/spike but carries production-grade validation criteria (30% disagreement rate, cost ceiling, critical-finding detection) without instrumentation to measure them. Three-model chain (Claude → Codex → Perplexity) introduces compounding failure modes. Plugin-dev alignment constrains architecture but doesn't specify interfaces.

## Key Observations

1. **Validation criteria are the weakest section** — all three bullets contain undefined terms. A prototype should still define how it measures its own success.
2. **Haiku consistently missed dependency/interface risks but caught framing/readability issues sonnet overlooked.** 48% dedup rate suggests ~half of sonnet findings are refinements of haiku-level concerns.
3. **The three-model chain receives only one sentence of specification** — data flow, state management, error handling, output schema all absent.
4. **Cost tracking is structurally difficult** — three API providers with different pricing models make real-time "$5/review" enforcement hard.
5. **Meta-observation: this spec is itself a test case for the system it describes.** Findings UC-1 through UC-5 would likely have been caught by the very pipeline CIA-394 proposes. Both a validation of the concept and evidence the spec needs iteration.
