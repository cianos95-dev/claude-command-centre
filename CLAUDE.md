# Claude Command Centre (CCC)

## Agent Dispatch

When working on this repo, use these conventions:

| Task Type | Agent | Trigger |
|-----------|-------|---------|
| Feature implementation | Claude Code (local) | `/ccc:go CIA-XXX` |
| Background implementation | Tembo (Claude Code) | Assign to Tembo in Linear |
| PR code review | GitHub Copilot | Auto on PR |
| Spec drafting | Claude Code (local) | `/ccc:start` |

## Repo Structure

- `agents/` — Agent definitions (8 agents: reviewer personas, spec-author, implementer, debate-synthesizer)
- `commands/` — Slash commands (17 commands: go, start, close, review, decompose, etc.)
- `hooks/` — Session and tool hooks (session-start, stop, pre/post-tool-use)
- `skills/` — Skill definitions (33 skills: execution modes, issue lifecycle, adversarial review, etc.)
- `styles/` — Output style definitions (explanatory, educational)
- `scripts/` — Repo setup and maintenance scripts
- `tests/` — Static quality checks and outcome validation tests
- `docs/` — ADRs, Linear setup guide, style guide, upstream monitoring
- `examples/` — Sample outputs (anchor, closure, index, PR/FAQ, review findings)
- `.claude-plugin/` — Plugin manifest (`plugin.json`, `marketplace.json`)

## Testing

Run the static quality checks before submitting changes:

```bash
bash tests/test-static-quality.sh
```
