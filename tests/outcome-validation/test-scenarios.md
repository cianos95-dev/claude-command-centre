# Outcome Validation — Test Scenarios

> CIA-517: TDD test scenarios for the outcome-validation skill.
> These scenarios define expected behavior BEFORE the skill is implemented.
> Each scenario specifies inputs, expected behavior, and expected output.

## Test Matrix

| # | Scenario | Issue Type | Exec Mode | Estimate | --quick | Expected Result |
|---|----------|-----------|-----------|----------|---------|-----------------|
| T1 | Feature triggers validation | type:feature | exec:tdd | 3pt | no | RUNS validation (4 persona passes) |
| T2 | Chore skips validation | type:chore | exec:quick | 2pt | no | SKIPS (type:chore) |
| T3 | Spike skips validation | type:spike | — | 2pt | no | SKIPS (type:spike) |
| T4 | Bug triggers validation | type:bug | exec:tdd | 3pt | no | RUNS validation |
| T5 | Quick flag skips validation | type:feature | exec:quick | 3pt | yes | SKIPS (--quick flag) |
| T6 | Quick <=2pt skips validation | type:feature | exec:quick | 2pt | no | SKIPS (exec:quick <=2pt) |
| T7 | Quick 3pt+ runs validation | type:feature | exec:quick | 3pt | no | RUNS validation |
| T8 | No estimate defaults to skip for exec:quick | type:feature | exec:quick | none | no | SKIPS (exec:quick, unestimated counts as 1pt) |

---

## T1: Feature Issue Triggers Full Validation

**Given:** An issue with labels `type:feature`, `exec:tdd`, estimate 3pt, no `--quick` flag, spec has clear press release and acceptance criteria.

**When:** `/ccc:close` is invoked.

**Then:** Quality scoring runs first. Outcome validation runs AFTER quality scoring, BEFORE closure action. Four persona passes execute sequentially (Customer Advocate, CFO Lens, Product Strategist, Skeptic). Each produces a sub-verdict with evidence. Final consolidated verdict is produced and included in closing comment.

---

## T2: Chore Issue Skips Validation

**Given:** An issue with labels `type:chore`, `exec:quick`, estimate 2pt.

**When:** `/ccc:close` is invoked.

**Then:** Outcome validation is SKIPPED. Skip reason: "Skipped: type:chore issues do not require outcome validation." Output: `Outcome validation: Skipped (type:chore)`.

---

## T3: Spike Issue Skips Validation

**Given:** An issue with label `type:spike`, estimate 2pt.

**When:** `/ccc:close` is invoked.

**Then:** Outcome validation is SKIPPED. Skip reason: "Skipped: type:spike issues produce knowledge, not outcomes to validate." Output: `Outcome validation: Skipped (type:spike)`.

---

## T4: Bug Issue Triggers Validation

**Given:** An issue with labels `type:bug`, `exec:tdd`, estimate 3pt.

**When:** `/ccc:close` is invoked.

**Then:** Outcome validation RUNS. Customer Advocate evaluates whether the bug fix resolves the user-facing problem. All 4 persona passes execute.

---

## T5: --quick Flag Skips Validation

**Given:** An issue with labels `type:feature`, `exec:quick`, estimate 3pt, `--quick` flag was used.

**When:** `/ccc:close` is invoked.

**Then:** Outcome validation is SKIPPED. Output: `Outcome validation: Skipped (--quick mode)`.

---

## T6: exec:quick with <=2pt Skips Validation

**Given:** An issue with labels `type:feature`, `exec:quick`, estimate 2pt, no `--quick` flag.

**When:** `/ccc:close` is invoked.

**Then:** Outcome validation is SKIPPED. Output: `Outcome validation: Skipped (exec:quick, estimate <=2pt)`.

---

## T7: exec:quick with 3pt+ Runs Validation

**Given:** An issue with labels `type:feature`, `exec:quick`, estimate 3pt, no `--quick` flag.

**When:** `/ccc:close` is invoked.

**Then:** Outcome validation RUNS. All 4 persona passes execute.

---

## T8: Unestimated exec:quick Defaults to Skip

**Given:** An issue with labels `type:feature`, `exec:quick`, no estimate set, no `--quick` flag.

**When:** `/ccc:close` is invoked.

**Then:** Outcome validation is SKIPPED. Output: `Outcome validation: Skipped (exec:quick, unestimated)`.

---

## Integration Tests

### I1: Verdict Feeds Into Quality Score

ACHIEVED → +0 adjustment. PARTIALLY_ACHIEVED → -5. NOT_ACHIEVED → -15. UNDETERMINABLE → -10.

### I2: Verdict Appears in Closing Comment

Between "Verification Evidence" and "What Was Delivered" sections.

### I3: Skill Registered in Marketplace

`./skills/outcome-validation` in `skills[]` array. Valid frontmatter with `name` and `description`.

### I4: Close Command References Skill

Step 2.5 in close.md references outcome-validation skill with skip condition logic.
