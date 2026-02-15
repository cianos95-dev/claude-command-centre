# CIA-396: Prototype tool capture hooks for spec conformance

## Context

PostToolUse hook verifies file changes align with active spec acceptance criteria. Catches drift at write-time vs. re-anchoring at task boundaries.

**Source:** CC Plugin Eval (sjnims) -- deterministic tool capture hooks

## Validation Criteria

- <10% false positives
- Catches 2+ drift instances per 10-issue sample

## Risk

May over-constrain agent creativity. Gate on false positive rate.

## Acceptance Criteria

- [ ] PostToolUse hook captures file changes
- [ ] Changes compared against active spec acceptance criteria
- [ ] 10-issue sample tested for drift detection
- [ ] False positive rate measured (<10% target)
- [ ] Decision: adopt, modify, or reject
