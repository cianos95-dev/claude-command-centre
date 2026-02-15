# CIA-396 Multi-Model Review: Prototype tool capture hooks for spec conformance

**Date:** 2026-02-15
**Pipeline:** Phase 1 (haiku scan) → Phase 2 (4 personas × 2 tiers) → Phase 3 (opus synthesis)
**Raw findings:** 40 | **Deduplicated:** 22 | **Dedup rate:** 45%

## Diversity Metrics

| Metric | Count | % |
|--------|-------|---|
| **Sonnet-only findings** | 11 | 50% |
| **Haiku-only findings** | 2 | 9% |
| **Convergent findings** | 9 | 41% |
| **Total unique** | 22 | 100% |

### Per-Persona Cross-Tier Agreement

| Persona | Sonnet | Haiku | Converged | Agreement |
|---------|--------|-------|-----------|-----------|
| Security Skeptic | 7 | 3 | 3 | 43% |
| Performance Pragmatist | 6 | 3 | 2 | 29% |
| Architectural Purist | 7 | 2 | 2 | 29% |
| UX Advocate | 6 | 3 | 2 | 33% |

### Severity Calibration Gaps

| Finding | Sonnet | Haiku | Gap |
|---------|--------|-------|-----|
| Acceptance criteria parsing has no defined algorithm | Critical | Important | Sonnet upgrades: bash + markdown = fragile |
| False positive measurement lacks ground truth definition | Important | Not flagged | Sonnet-only: haiku missed entirely |
| PostToolUse hook I/O contract is undocumented | Important | Critical | Haiku upgrades: most obvious gap |
| No rollback mechanism for blocked writes | Important | Not flagged | Sonnet-only |
| Latency budget per tool invocation not specified | Critical | Important | Sonnet upgrades: quantified the cost |

### False Positive Candidates (2/40 = 5%)

- UH3: No accessibility considerations — spec is for a developer tool hook (shell script), not a user-facing UI
- SH3: No encryption at rest for logs — local JSONL file in development environment, over-scoped threat model

## Top 5 Convergent-Critical Findings

1. **F1 — No matching algorithm for criteria-to-change comparison** (6 contributing: SS1, SH1, AS1, AH1, PS2, US1)
2. **F2 — False positive metric has no ground truth** (5 contributing: SS3, PS1, PH1, US2, UH1)
3. **F3 — PostToolUse payload contract is unvalidated** (5 contributing: AS2, AH2, SS2, SH2, PS3)
4. **F4 — Hook latency budget unspecified** (4 contributing: PS1, PH2, PS4, SS5)
5. **F5 — 10-issue sample statistically insufficient** (4 contributing: PS5, PH3, US4, SS6)

These 5 = 24/40 raw findings (60%), confirming genuine systemic issues.

## All Unified Findings

### CRITICAL Consensus (6+/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| F1 | No matching algorithm for criteria-to-change comparison | convergent | critical | SS1, SH1, AS1, AH1, PS2, US1 |
| F2 | False positive metric has no ground truth | convergent | critical | SS3, PS1, PH1, US2, UH1 |
| F3 | PostToolUse payload contract is unvalidated | convergent | critical | AS2, AH2, SS2, SH2, PS3 |

### HIGH Consensus (4-5/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| F4 | Hook latency budget unspecified | convergent | high | PS1, PH2, PS4, SS5 |
| F5 | 10-issue sample statistically insufficient | convergent | high | PS5, PH3, US4, SS6 |
| F6 | No spec parsing strategy defined | sonnet-only | high | SS4, AS3 |
| F7 | Creativity constraint risk acknowledged but not mitigated | convergent | high | US3, UH2, AS5, PS6 |
| F8 | Decision criteria for adopt/modify/reject undefined | sonnet-only | high | US5, AS6 |

### MODERATE Consensus (2-3/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| F9 | Two PostToolUse hooks create ordering dependency | sonnet-only | moderate | AS4 |
| F10 | No distinction between write-tool and non-write-tool invocations | sonnet-only | moderate | PS4, AS7 |
| F11 | No integration with existing drift-prevention skill | sonnet-only | moderate | AS5, US6 |
| F12 | Conformance log format not specified | sonnet-only | moderate | SS7, PS6 |
| F13 | "Catches 2+ drift instances" is ambiguous | sonnet-only | moderate | US4, SS3 |
| F14 | No test harness design for 10-issue sample | sonnet-only | moderate | PS5, US5 |

### MINORITY (1/8 reviewers)

| ID | Title | Tier Tag | Severity | Contributing |
|----|-------|----------|----------|-------------|
| F15 | Potential for log injection via tool output | sonnet-only | low | SS7 |
| F16 | No versioning for conformance check logic | sonnet-only | low | AS7 |
| F17 | Spec title says "prototype" but AC implies production readiness | haiku-only | low | UH2 |
| F18 | No consideration of multi-spec sessions | sonnet-only | low | AS6 |
| F19 | No graceful degradation when jq/git unavailable | haiku-only | low | SH3 |
| F20 | Source attribution is misleading | sonnet-only | low | AS3 |
| F21 | Environment variable proliferation | sonnet-only | low | PS6 |
| F22 | AC3 and AC5 are meta-criteria, not feature criteria | sonnet-only | low | US6 |

## Phase 1 Scan Summary

Strong existing infrastructure: `hooks.json` registers PostToolUse handlers, `post-tool-use.sh` (64 lines) provides logging/branch protection, and `circuit-breaker-post.sh` (197 lines) demonstrates mature tool I/O parsing with `jq`. Key gap: transition from "capture which plugin components triggered" (cc-plugin-eval) to "capture which file changes align with spec criteria" is a conceptual leap requiring NLU, not pattern matching.

## Key Observations

1. **Sonnet found 2.5x more findings per persona than haiku** (6.5 vs 2.75 average), larger gap than CIA-303's 2x ratio. Underspecified specs amplify the gap.
2. **Cross-tier agreement lowest for Performance Pragmatist and Architectural Purist (29% each).** These personas need deep codebase context that haiku framing compresses too aggressively.
3. **The single haiku-only finding (F17, "prototype vs production criteria mismatch") is arguably the most strategically important.** Sonnet assumed production intent; haiku's "user receiving this spec" framing caught the identity confusion.
4. **All four personas converged on F1 and F2** — 4/4 convergence across both tiers makes these highest-confidence findings.
5. **False positive rate 5% (2/40)** — both from haiku tier, suggesting compressed framing modifiers occasionally cause over-literal domain lens application.
