# CIA-308: SDD Plugin: PM/Dev extension command and skill specification

## Objective

Unified specification for new commands and skills being added to the existing SDD plugin to support PM/Dev AI collaboration workflows (marketing, analytics, enterprise search, adaptive methodology).

## Context

Incorporates findings from:
- Anthropic pattern research issue -- command vs skill vs CONNECTORS.md classification
- CIA-299 -- Tool-to-funnel connector mapping
- CIA-302 -- Analytics + data plugin integration patterns
- CIA-303 -- v2 adaptive methodology

## Proposed New Commands (TBD)

Candidates: `/sdd:analytics-review`, `/sdd:verify`, `/sdd:research-ground`, `/sdd:digest`

For each: name, trigger description, inputs/outputs, MCP tools used, funnel stage, complement to existing commands.

## Proposed New Skills (TBD)

Candidates: `analytics-integration`, `enterprise-search-patterns`, `developer-marketing`, `data-informed-closure`, `adaptive-methodology`

For each: name, trigger conditions, knowledge content scope, cross-references.

## Extended CONNECTORS.md

Replace placeholder connectors with concrete integrations:
- `~~analytics~~` -> PostHog, Sentry, Amplitude
- `~~web-research~~` -> Firecrawl
- `~~communication~~` -> Slack
- Add: Notion (for enterprise search patterns)

## README Reconciliation

**CRITICAL:** Current README claims 10 skills and 8 commands but only 6/6 actually exist. Must either:
- Define the 4 missing v2 skills and 2 missing commands
- OR correct the README to match reality

## Anthropic Canonical Spec Alignment (PR #42)

### Agents Component Type -- Evaluate for PM/Dev Persona

Agents formalized with YAML frontmatter: `name`, `description`, `model`, `color`, optional `tools`. Decision needed: Should PM persona (Stages 0-5) and Dev persona (Stages 6-7.5) be formalized as agents?

### Decision needed before implementation

This is a research spike -- evaluate and recommend approach.

## Acceptance Criteria

- [ ] Each new command fully specified
- [ ] Each new skill fully specified
- [ ] CONNECTORS.md extended with concrete integrations
- [ ] README accuracy gap resolved
- [ ] Total command/skill count justified
