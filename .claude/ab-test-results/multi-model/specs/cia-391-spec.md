# CIA-391: Add Evidence Object pattern to research grounding skill

## Context

Structured evidence format: `[EV-001]` refs with type (empirical/theoretical/methodological), source citation, claim, and confidence level. PR/FAQ research template requires 3+ Evidence Objects. `/sdd:write-prfaq` validates.

**Source:** Synapti Context Ledger

## Evidence Object Format

```
[EV-001] Type: empirical
Source: Author (Year). Title. Journal.
Claim: "Specific factual claim supported by source"
Confidence: high | medium | low
```

## Why

Only plugin with academic citation discipline. Strengthens Alteri positioning.

## Files

- `skills/research-grounding/SKILL.md` -- Update with Evidence Object pattern

## Acceptance Criteria

- [ ] Evidence Object format defined in research grounding skill
- [ ] PR/FAQ research template requires 3+ Evidence Objects
- [ ] `/sdd:write-prfaq` validates minimum Evidence Object count
- [ ] Each EV object has: ID, type, source, claim, confidence
- [ ] Types supported: empirical, theoretical, methodological

## Plugin-dev Alignment (v1.3.0)

Additions must keep `skills/research-grounding/SKILL.md` under ~2000 words (currently ~670 words, substantial room available). Follow imperative writing style. If evidence object schema is complex, extract to `skills/research-grounding/references/evidence-object-schema.md`.
