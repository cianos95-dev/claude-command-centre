# CIA-394: Prototype structured adversarial debate (2-round multi-model)

## Context

2-round debate: Claude forms position -> Codex challenges -> structured resolution -> Perplexity tiebreaker for persistent disagreements. Extends Option C/D review.

**Source:** agent-peer-review (jcputney) -- only true adversarial review plugin in ecosystem

## Validation Criteria

- 30%+ reviews have substantive disagreements
- Tiebreaker uncovers 2+ Critical findings missed by single-model
- Cost <$5/review

## Acceptance Criteria

- [ ] 2-round debate flow implemented (position -> challenge -> resolution)
- [ ] Perplexity tiebreaker for persistent disagreements
- [ ] 10+ test reviews executed
- [ ] Validation criteria measured and documented
- [ ] Cost tracking per review session

## Plugin-dev Alignment (v1.3.0)

Multi-model debate = multiple agent files in `agents/` per plugin-dev's agent-development standard. Each debater is a separate .md file with YAML frontmatter. Orchestration logic lives in a skill or command, not in agent files.
