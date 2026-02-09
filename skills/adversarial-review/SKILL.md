---
name: adversarial-review
description: Adversarial spec review methodology with multiple reviewer perspectives and architecture options for automated review pipelines.
---

# Adversarial Spec Review

Every spec that passes through this funnel receives structured adversarial review before implementation begins. The review is not editorial -- it stress-tests the spec for gaps that would become bugs, security incidents, or wasted effort.

## Reviewer Perspectives

All review architectures use the same three reviewer perspectives plus a synthesizer. These are not optional -- every review must include all three.

### 1. Challenger

Find gaps, ambiguities, contradictions, and unstated assumptions. Be adversarial.

- What requirements are vague enough to be implemented two different ways?
- What edge cases are not addressed?
- Where does the spec contradict itself?
- What assumptions are made but never stated?
- What happens when inputs are empty, null, extremely large, or malformed?
- Are success criteria measurable and unambiguous?

### 2. Security Reviewer

Identify attack vectors, data handling risks, privacy concerns, and compliance gaps.

- What data flows through this feature and who can access it?
- Where could injection, escalation, or exfiltration occur?
- Are authentication and authorization boundaries clearly defined?
- What PII or sensitive data is involved and how is it stored/transmitted?
- Does this introduce new attack surface area?
- Are there regulatory or compliance implications (GDPR, SOC2, HIPAA)?

### 3. Devil's Advocate

Challenge the fundamental approach. Propose completely different alternatives. Question core assumptions.

- Why this solution and not a fundamentally different one?
- What if the core premise is wrong?
- Could this be solved with zero new code?
- What would a competitor do differently?
- Is this solving the right problem, or a symptom of a deeper issue?
- What would make this entire approach obsolete in 6 months?

### Synthesizer

After all three perspectives have been applied, the synthesizer consolidates findings into a prioritized action list.

**Critical** -- Must address before implementation. These are blockers: security vulnerabilities, contradictory requirements, missing error handling for likely scenarios.

**Important** -- Should address before implementation. These improve quality significantly: ambiguous acceptance criteria, missing edge cases, questionable architectural choices.

**Consider** -- Nice to have. These are improvements worth discussing: alternative approaches, performance optimizations, future extensibility concerns.

The synthesizer also flags any disagreements between reviewers and notes where the Challenger and Devil's Advocate reached opposing conclusions.

## Architecture Options

Four options for running adversarial reviews, ordered by automation level. All trigger on spec file merge to `docs/specs/` on the main branch of your ~~version-control~~ repository.

### Option A: CI Agent (Free)

GitHub Actions detects spec merge and assigns a review issue to a CI-tier coding agent (e.g., `@copilot`).

| Dimension | Rating |
|-----------|--------|
| Monthly cost | $0 additional |
| Automation level | Full |
| Review model quality | Good (Sonnet-tier) |
| Multi-model capability | No (single model) |
| Setup effort | Low (Actions workflow + issue template) |
| Hands-off score | 8/10 |

The agent receives the spec content, the three reviewer perspective prompts, and outputs a structured review as a ~~version-control~~ issue or PR comment. Quality is solid for catching gaps and ambiguities but may miss subtle architectural concerns.

### Option B: Premium Agents

GitHub Actions assigns review to premium coding agents (e.g., `@claude`, `@codex`) that have access to stronger models.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | ~$40/mo (agent subscription) |
| Automation level | Full |
| Review model quality | Very Good |
| Multi-model capability | Limited (single premium model) |
| Setup effort | Low (Actions workflow + agent config) |
| Hands-off score | 9/10 |

Same trigger mechanism as Option A but routes to a premium agent. Better at catching architectural issues and generating meaningful Devil's Advocate alternatives. The subscription cost covers unlimited or high-volume reviews.

### Option C: API + Actions

GitHub Actions triggers an API-based review pipeline with configurable model selection.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | Variable (API costs, typically $2-10/review) |
| Automation level | Full |
| Review model quality | Best (Opus-tier configurable) |
| Multi-model capability | Yes (different model per perspective) |
| Setup effort | Medium (Actions workflow + API integration + secret management) |
| Hands-off score | 9/10 |

This is the most flexible option. Each reviewer perspective can use a different model -- for example, Opus for Devil's Advocate (requires creative reasoning), Sonnet for Challenger (pattern matching against requirements), and a security-specialized model for Security Reviewer. Results are aggregated by a synthesizer call.

### Option D: In-Session Subagents

Manual trigger during a coding session. The developer runs the review command, which spawns subagent-based reviewers.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | $0 additional |
| Automation level | Manual (developer-triggered) |
| Review model quality | Very Good (session model) |
| Multi-model capability | Yes (subagent model mixing) |
| Setup effort | None (works in any coding session) |
| Hands-off score | 6/10 |

Best for reviewing specs before they are even committed. The developer runs the review in their coding tool, gets immediate feedback, and iterates on the spec before pushing. This is the fastest feedback loop but requires the developer to remember to trigger it.

### Comparison Summary

| Dimension | A: CI Agent | B: Premium | C: API | D: In-Session |
|-----------|-------------|------------|--------|---------------|
| Monthly cost | $0 | ~$40 | Variable | $0 |
| Automation | Full | Full | Full | Manual |
| Model quality | Good | Very Good | Best | Very Good |
| Multi-model | No | Limited | Yes | Yes |
| Setup effort | Low | Low | Medium | None |
| Hands-off | 8/10 | 9/10 | 9/10 | 6/10 |

## Hybrid Combinations

Options are not mutually exclusive. Effective combinations include:

**Option A + D (Zero-cost full coverage):** Use Option D during spec drafting for immediate feedback, then Option A on merge for a second automated pass. Two review rounds at zero additional cost.

**Option A + C (Tiered quality):** Option A for routine specs (bug fixes, small features). Option C for high-impact specs (new systems, security-sensitive features). Route based on spec template type or labels.

**Option A for review + ~~remote-dispatch~~ for implementation:** Use free CI agents for the review stage, then dispatch implementation to a remote coding agent. This separates the review cost (free) from the implementation cost (agent session).

**Option D as pre-commit gate + Option B on merge:** Developer reviews locally before pushing, premium agent reviews after merge. Catches different classes of issues at different stages.

## Review Output Format

Regardless of architecture option, the review output follows this structure:

```
## Adversarial Review: [Spec Title]

### Challenger Findings
- [Finding with severity: Critical/Important/Consider]

### Security Review
- [Finding with severity: Critical/Important/Consider]

### Devil's Advocate
- [Alternative approach or fundamental challenge]

### Synthesis
**Critical (must address):**
1. ...

**Important (should address):**
1. ...

**Consider (nice to have):**
1. ...

### Recommendation
[APPROVE / REVISE / RETHINK]
```

The recommendation is one of:
- **APPROVE** -- Spec is ready for implementation with minor adjustments
- **REVISE** -- Spec needs significant changes to address Critical findings
- **RETHINK** -- Fundamental approach is questioned; consider alternative solutions

## Implementation References

GitHub Actions workflow files and issue templates for Options A, B, and C are located in the `references/` subdirectory. Adapt these to your ~~ci-cd~~ platform if not using GitHub Actions.
