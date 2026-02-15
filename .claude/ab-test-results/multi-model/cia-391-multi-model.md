# CIA-391 Multi-Model Review: Add Evidence Object pattern to research grounding skill

**Date:** 2026-02-15
**Pipeline:** Phase 1 (haiku scan) → Phase 2 (4 personas × 2 tiers) → Phase 3 (opus synthesis)
**Raw findings:** 38 | **Deduplicated:** 19 | **Dedup rate:** 50%

## Diversity Metrics

| Metric | Count | % |
|--------|-------|---|
| **Sonnet-only findings** | 9 | 47% |
| **Haiku-only findings** | 2 | 11% |
| **Convergent findings** | 8 | 42% |
| **Total unique** | 19 | 100% |

### Per-Persona Cross-Tier Agreement

| Persona | Sonnet | Haiku | Converged | Agreement |
|---------|--------|-------|-----------|-----------|
| Security Skeptic | 6 | 2 | 2 | 33% |
| Performance Pragmatist | 5 | 3 | 2 | 40% |
| Architectural Purist | 7 | 2 | 2 | 29% |
| UX Advocate | 6 | 3 | 2 | 33% |

### Severity Calibration Gaps

| Finding | Sonnet | Haiku | Gap |
|---------|--------|-------|-----|
| Validation mechanism undefined | Critical | High | 1 level |
| No schema versioning | High | Not raised | Sonnet-only |
| EV-ID collision across specs | High | Not raised | Sonnet-only |
| Confidence level semantics | Moderate | Moderate | Aligned |

### False Positive Candidates (2/38 = 5%)

- PH3: Free-text claim field exploitable — claim authored by developer/researcher, not user-submitted input
- SH2: Confidence levels are subjective — subjectivity is a feature (recording author's assessment), not a bug

## Top 5 Convergent-Critical Findings

1. **F-01 — No validation mechanism specified** (6 contributing: SS1, SH1, PS1, AS1, US1, UH1)
2. **F-02 — Template format conflict with existing Key Sources table** (4 contributing: AS3, AS4, PS3, US3)
3. **F-03 — EV-ID scoping and collision undefined** (3 contributing: SS3, AS2, US4)
4. **F-04 — Confidence level semantics undefined** (4 contributing: SS4, PH2, US2, UH2)
5. **F-05 — PR/FAQ research template not updated** (4 contributing: AS3, AS4, PS3, US3)

These 5 = 21/38 raw findings (55%), confirming genuine systemic issues.

## All Unified Findings

### CRITICAL Consensus (6+/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| F-01 | Validation mechanism unspecified | convergent | critical | SS1, SH1, PS1, AS1, US1, UH1 |
| F-02 | Template format conflict (Evidence Objects vs Key Sources table) | convergent | critical | AS3, AS4, PS3, US3 |
| F-03 | EV-ID scoping and collision undefined | convergent | critical | SS3, AS2, US4 |

### HIGH Consensus (4-5/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| F-04 | Confidence level semantics undefined | convergent | high | SS4, PH2, US2, UH2 |
| F-05 | Word budget consumed without extraction strategy | sonnet-only | high | AS5, PS2 |
| F-06 | Claim field is free-text with no constraints | sonnet-only | high | SS2, AS6 |
| F-07 | Type taxonomy too narrow (3 types) | sonnet-only | high | SS5, PS4 |

### MODERATE Consensus (2-3/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| F-08 | No worked examples in the spec | convergent | moderate | US5, PH1 |
| F-09 | No relationship defined between EV Objects and existing citation format | sonnet-only | moderate | AS7, PS3 |
| F-10 | Source field omits DOI (less rigorous than existing formats) | sonnet-only | moderate | AS4 |
| F-11 | Adversarial review integration gap | sonnet-only | moderate | SS6 |
| F-12 | "Synapti Context Ledger" source is opaque and untraceable | haiku-only | moderate | UH3 |
| F-13 | No migration path for existing specs | sonnet-only | moderate | US6 |

### MINORITY (1/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| F-14 | Competitive claim ("only plugin") ungrounded | sonnet-only | moderate | PS5 |
| F-15 | No machine-readability consideration | sonnet-only | low | AS6 |
| F-16 | Confidence level interacts with research readiness labels | sonnet-only | low | SS4 |
| F-17 | Three types insufficient for non-Alteri projects | haiku-only | low | PH3 |
| F-18 | No guidance on when Evidence Objects are overkill | sonnet-only | low | US6 |
| F-19 | Acceptance criteria not independently testable | sonnet-only | low | PS1 |

## Phase 1 Scan Summary

Spec targets single file (`skills/research-grounding/SKILL.md`) but acceptance criteria require changes to at least three files: SKILL.md, `prfaq-research.md` template, and `write-prfaq.md` command. Existing template already has Key Sources table with incompatible citation format. SKILL.md at ~670 words with ~2000 word budget provides room but extraction strategy needed.

## Key Observations

1. **Scope underestimation is the primary issue** — spec lists 1 file but requires 3+ file changes.
2. **Two citation systems will coexist without reconciliation** — inline citations, Key Sources table, and Evidence Objects each capture different information with no guidance on which to use where.
3. **Validation is the hardest AC and is entirely undefined** — requires markdown parsing, EV marker detection, field validation, error messages.
4. **Haiku consistently identified user-facing confusion; sonnet found structural/integration issues** — validates multi-tier complementarity. 50% dedup rate confirms meaningful signal from both tiers.
5. **The spec's own positioning ("only plugin with academic citation discipline") is itself ungrounded** — ironic for a spec about evidence standards.
