# Variant Validation Test Scenarios

Test cases for project-scoped template variants. Written before implementation (TDD red phase).

## Schema Validation Tests

### T1: Valid variant passes schema validation
**Input:** Base template with `variants` array containing one valid variant
```json
{
  "name": "Feature",
  "type": "issue",
  "templateData": { "labels": ["type:feature"], "team": "Claudian" },
  "variants": [
    {
      "name": "Feature (CCC)",
      "project": "Claude Command Centre (CCC)",
      "overrides": { "labels": ["+exec:tdd"] }
    }
  ]
}
```
**Expected:** PASS — variant has required `name` and `project`, `overrides` is valid

### T2: Variant missing `name` fails validation
**Input:** Variant without `name` field
```json
{
  "variants": [{ "project": "CCC", "overrides": {} }]
}
```
**Expected:** FAIL — `name` is required on variants

### T3: Variant missing `project` fails validation
**Input:** Variant without `project` field
```json
{
  "variants": [{ "name": "Feature (CCC)", "overrides": {} }]
}
```
**Expected:** FAIL — `project` is required on variants

### T4: Empty variants array is valid
**Input:** `"variants": []`
**Expected:** PASS — empty array means no project variants defined

### T5: Variant with no overrides is valid
**Input:** Variant with `name` and `project` only, no `overrides`
**Expected:** PASS — variant that only sets project assignment, inheriting all base fields

## Override Semantics Tests

### T6: Label additive override (`+` prefix)
**Input:** Base `labels: ["type:feature", "spec:draft"]`, variant override `labels: ["+exec:tdd"]`
**Expected resolved:** `["type:feature", "spec:draft", "exec:tdd"]` — additive labels are merged

### T7: Label replacement override (no prefix)
**Input:** Base `labels: ["type:feature", "spec:draft"]`, variant override `labels: ["type:feature", "spec:draft", "exec:tdd"]`
**Expected resolved:** `["type:feature", "spec:draft", "exec:tdd"]` — full replacement

### T8: Label removal override (`-` prefix)
**Input:** Base `labels: ["type:feature", "spec:draft"]`, variant override `labels: ["-spec:draft"]`
**Expected resolved:** `["type:feature"]` — removal by prefix

### T9: Scalar override replaces base
**Input:** Base `estimate: 3`, variant override `estimate: 5`
**Expected resolved:** `estimate: 5`

### T10: Variant inherits unoverridden fields
**Input:** Base has `priority: 0, estimate: 3, state: "Backlog"`, variant overrides only `estimate: 5`
**Expected resolved:** `priority: 0, estimate: 5, state: "Backlog"` — non-overridden fields inherited

### T11: Variant adds new fields not in base
**Input:** Base has no `assignee`, variant overrides `assignee: "Claude"`
**Expected resolved:** `assignee: "Claude"` added to resolved templateData

### T12: descriptionData is NOT inherited when overridden
**Input:** Base has `descriptionData: {...}`, variant overrides `descriptionData: {...different...}`
**Expected resolved:** Variant's `descriptionData` fully replaces base's (no deep merge)

## Project Resolution Tests

### T13: Project name resolves to valid project
**Input:** Variant `project: "Claude Command Centre (CCC)"`
**Expected:** Resolves to `projectId` UUID at sync time

### T14: Unknown project name fails resolution
**Input:** Variant `project: "Nonexistent Project"`
**Expected:** FAIL — project name does not match any workspace project

### T15: delegateId resolves symbolic agent name
**Input:** Variant override `delegateId: "Claude"`
**Expected:** Resolves to agent user ID at sync time

## Variant Selection Tests

### T16: Select variant by project name
**Input:** Base "Feature" template, user requests project "CCC"
**Algorithm:** Find variant where `project` matches. Return merged templateData.
**Expected:** Returns "Feature (CCC)" variant's resolved data

### T17: No matching variant falls back to base
**Input:** Base "Feature" template, user requests project "Cognito SoilWorx"
**Algorithm:** No variant matches. Return base templateData + projectId.
**Expected:** Base template with project assigned but no other overrides

### T18: Multiple variants for same base, correct one selected
**Input:** "Feature" has variants for CCC and Alteri. User requests "Alteri".
**Expected:** Returns "Feature (Alteri)" variant, not "Feature (CCC)"

## Template-Validate Integration Tests

### T19: Validate detects variant with stale project reference
**Input:** Variant `project: "Deleted Project"` — project no longer exists
**Expected:** FAIL finding: "Variant 'Feature (CCC)' references unknown project 'Deleted Project'"

### T20: Validate detects variant with stale label in overrides
**Input:** Variant override `labels: ["+nonexistent:label"]`
**Expected:** FAIL finding: label not found in workspace

### T21: Validate passes clean variant
**Input:** Variant with valid project, valid label overrides
**Expected:** PASS — no findings for this variant

### T22: CI mode includes variant findings in JSON output
**Input:** Run validate --ci on templates with variants
**Expected:** `findings[]` array includes variant-specific findings with `variant` field identifying which variant
