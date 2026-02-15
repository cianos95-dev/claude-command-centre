# CIA-303: SDD Plugin v2: /insights-powered adaptive methodology

## Objective

Use Claude Code's `/insights` data (tool usage patterns, friction points, session metrics) to make the SDD methodology self-improving. Instead of static rules, the plugin adapts based on observed patterns.

**Merges:** CIA-202 (plugin evaluation) + CIA-293 (drift prevention) + CIA-294 (hook enforcement) + CIA-295 (codebase indexing) + CIA-296 (quality scoring)

**This is a v2 meta-feature.** Individual capabilities can still be implemented incrementally, but `/insights` provides the unifying data layer.

## Three-Layer Monitoring Stack

| Layer | Tool | What it measures | When |
|-------|------|-----------------|------|
| **Structural** | cc-plugin-eval (CIA-413) | Do components trigger correctly? Conflicts? | Pre-release, CI |
| **Runtime** | /insights (this issue) | What actually happened in sessions? | Post-session |
| **Adaptive** | This issue's adaptive loop | Should rules change based on patterns? | Periodic |

**Key distinction:** cc-plugin-eval validates the plugin *structurally*. This issue validates the plugin *behaviorally*. Neither replaces the other.

**Gap to address:** Neither cc-plugin-eval nor /insights currently tracks "did Claude read a references/ file when the SKILL.md pointer indicated it was needed?"

## Claude Code `/insights` Capability

- Reads past 30 days of message history
- Generates interactive HTML report
- Surfaces: projects worked on, tool usage patterns, friction points (repeated errors, stuck sessions, high context usage), personalized workflow suggestions
- **No official API yet** -- HTML parsing or CLI wrapper needed for structured data extraction

## Subsumed Capabilities

### 1. Drift Prevention (CIA-293)

**Static approach:** Re-anchor before every task by re-reading spec.
**Insights-powered:** `/insights` friction data shows *when* sessions actually drift from spec. Re-anchoring triggers based on observed drift patterns, not arbitrary intervals.

### 2. Hook Enforcement (CIA-294)

**Static approach:** Claude Code hooks with fixed rules.
**Insights-powered:** Hooks calibrated by `/insights` data. Spec-before-code enforcement calibrated by observed violation frequency. Hook thresholds that adapt.

### 3. Codebase Indexing (CIA-295)

**Static approach:** Scan entire repo, build searchable index.
**Insights-powered:** `/insights` tool usage patterns reveal which files/modules are touched most. Hot paths get indexed first.

### 4. Quality Scoring (CIA-296)

**Static approach:** 0-100 score based on test coverage, review status, deployment health.
**Insights-powered:** Integrate `/insights` metrics into closure score. Quality becomes a function of *process health*, not just test outcomes.

### 5. Plugin Evaluation (CIA-202)

**Static approach:** Manual audit of which plugins/skills are used.
**Insights-powered:** Use insights data to identify which skills/plugins are actually used vs. dormant.

## Implementation Approach (v2)

1. **Parse** `/insights` output: HTML parsing or CLI wrapper
2. **Create** `insights-integration` skill
3. **Add** `/sdd:insights` command
4. **Adaptive hooks:** Hooks consume insights data for dynamic thresholds
5. **Retrospective automation:** Correlate friction points with Linear issue outcomes
6. **References/ read-through metric:** Track whether Read tool calls to `references/*.md` correlate with session quality

## Dependencies

- Claude Code `/insights` must be stable
- Ideally: structured output API (not yet available)
- CIA-413 (cc-plugin-eval) for structural baseline
- CIA-323 (insights archival pipeline)

## Acceptance Criteria

- [ ] `/insights` data extraction method validated
- [ ] `insights-integration` skill specification drafted
- [ ] `/sdd:insights` command specification drafted
- [ ] Adaptive threshold design for hooks documented
- [ ] Quality scoring rubric incorporating process metrics defined
- [ ] Drift detection triggers mapped to insights friction data
- [ ] References/ read-through metric designed and documented
