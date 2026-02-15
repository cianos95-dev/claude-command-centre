# CIA-308 Multi-Model Review: SDD Plugin PM/Dev extension command and skill specification

**Date:** 2026-02-15
**Pipeline:** Phase 1 (haiku scan) → Phase 2 (4 personas × 2 tiers) → Phase 3 (opus synthesis)
**Raw findings:** 44 | **Deduplicated:** 21 | **Dedup rate:** 52%

## Diversity Metrics

| Metric | Count | % |
|--------|-------|---|
| **Sonnet-only findings** | 6 | 29% |
| **Haiku-only findings** | 2 | 10% |
| **Convergent findings** | 13 | 62% |
| **Total unique** | 21 | 100% |

### Per-Persona Cross-Tier Agreement

| Persona | Sonnet | Haiku | Converged | Agreement |
|---------|--------|-------|-----------|-----------|
| Security Skeptic | 7 | 2 | 2 | 100% |
| Performance Pragmatist | 6 | 3 | 3 | 100% |
| Architectural Purist | 8 | 2 | 2 | 100% |
| UX Advocate | 7 | 3 | 3 | 100% |

### Severity Calibration Gaps

| Finding | Sonnet | Haiku | Gap |
|---------|--------|-------|-----|
| Undefined scope for enterprise-search-patterns | Critical | Critical | None |
| README accuracy gap | High | Moderate | Haiku under-rates |
| Phantom spec references (CIA-299, CIA-302) | High | Not flagged | Sonnet-only |
| Agent persona formalization risk | High | Not flagged | Sonnet-only |
| Notion connector security | Critical | High | Haiku under-rates |

### False Positive Candidates (3/44 = 7%)

- SS7: API key sprawl via CONNECTORS.md materialization — incremental risk on existing pattern, not novel
- PS6: Email marketing connector performance concern — already exists in CONNECTORS.md, not new
- UH3: User confusion about command count — spec is for internal development, not end-user deliverable

## Top 5 Convergent-Critical Findings

1. **U-01 — 5 of 9 proposed components duplicate existing capabilities** (8 contributing: AS1, AS4, PS1, US2, SS5, AH1, PH1, UH1)
2. **U-02 — Spec is a skeleton with "(TBD)" markers, not implementable** (5 contributing: SS3, AS5, PS4, US5, PH2)
3. **U-03 — Enterprise-search-patterns and developer-marketing are undefined** (5 contributing: AS3, US4, PS5, AH1, UH1)
4. **U-04 — README reconciliation framing is factually inverted** (5 contributing: US1, PS2, AS6, SS6, UH2)
5. **U-05 — Notion connector re-addition lacks security analysis (previously disabled)** (5 contributing: SS1, SS2, AS7, SH1, SH2)

These 5 = 28/44 raw findings (64%), confirming genuine systemic issues.

## All Unified Findings

### CRITICAL Consensus (6+/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| U-01 | 5/9 proposed components duplicate existing capabilities | convergent | critical | AS1, AS4, PS1, US2, SS5, AH1, PH1, UH1 |
| U-02 | Spec body is TBD placeholders, not specification content | convergent | critical | SS3, AS5, PS4, US5, PH2 |
| U-03 | Enterprise-search-patterns and developer-marketing undefined | convergent | critical | AS3, US4, PS5, AH1, UH1 |

### HIGH Consensus (4-5/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| U-04 | README reconciliation framing contains factual error | convergent | high | US1, PS2, AS6, SS6, UH2 |
| U-05 | Notion connector addition lacks security analysis | convergent | high | SS1, SS2, AS7, SH1, SH2 |
| U-06 | marketplace.json has pre-existing registration gap | sonnet-only | high | AS8, SS4 |
| U-07 | Spec ignores 4 existing commands and 5 existing skills | convergent | high | PS3, US3, AS4 |
| U-08 | Agent persona formalization question already answered by architecture | sonnet-only | high | AS2, US6 |

### MODERATE Consensus (2-3/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| U-09 | No PR #42 artifact or link for Anthropic alignment evaluation | convergent | moderate | SS3, AS5, US5 |
| U-10 | CONNECTORS.md materialization breaks tool-agnostic design | sonnet-only | moderate | AS7, PS6 |
| U-11 | Acceptance criteria not independently testable | convergent | moderate | PS4, US7, PH3 |
| U-12 | No cost/context-budget analysis for new components | sonnet-only | moderate | PS1, PS3 |
| U-13 | Digest command overlaps with session-exit skill | sonnet-only | moderate | AS4, US2 |

### MINORITY (1/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| U-14 | No migration path for customized CONNECTORS.md | haiku-only | low | UH3 |
| U-15 | Spec combines research spike with implementation plan | convergent | low | SS5, PS5, AS5 |
| U-16 | No versioning strategy for new commands/skills | sonnet-only | low | SS4, AS8 |
| U-17 | No dependency graph between proposed components | haiku-only | low | PH3 |
| U-18 | New commands/skills may need review persona updates | sonnet-only | low | SS7, AS6 |
| U-19 | Email/geolocation connectors already exist in CONNECTORS.md | convergent | low | PS6, US3 |
| U-20 | No citation of which Anthropic patterns were researched | sonnet-only | low | SS3, AS5 |
| U-21 | No evaluation criteria for "decision needed" | convergent | low | US7, PS4 |

## Phase 1 Scan Summary

Fundamental mismatch: CIA-308 was written against an outdated understanding of the plugin. The plugin has 12 commands (not 8), 21 skills (not 10-16), and 8 agents. CONNECTORS.md already extensively materialized. 5 of 9 proposed components duplicate existing capabilities. The README accuracy gap is the inverse of what the spec claims.

## Key Observations

1. **The spec is reviewing itself out of existence** — most proposals either already exist or cannot be defined due to unclear scope. Highest-value action (README reconciliation) requires zero new code.
2. **100% cross-tier agreement across all personas** — haiku findings were strict subsets of sonnet findings. This spec's issues are so obvious that even surface-level review catches them.
3. **Only 2 of 9 proposed additions survive codebase grounding** — `/sdd:digest` and `analytics-integration` are the only non-redundant, definable proposals.
4. **The Notion connector re-proposal conflicts with user's own disabled-MCP list** — "proposal amnesia" anti-pattern that adversarial-review skill itself warns against.
5. **The spec conflates two deliverable types** — research spike vs specification. Should be split into two issues.
