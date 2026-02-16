# Upstream Monitoring

How to track changes in Anthropic's plugin ecosystem that might affect the CCC plugin.

## Repositories to Watch

| Repository | What to monitor | Priority |
|-----------|----------------|----------|
| `anthropics/claude-code` | Plugin spec changes, hook API, CLI updates | High |
| `anthropics/knowledge-work-plugins` | New plugins, pattern changes, plugin.json schema | High |
| `anthropics/courses` | SDK patterns, best practices | Low |

## GitHub Setup

1. **Watch** both repos with "Releases only" or "Custom" → Releases + Discussions
2. **Star** to track in your starred repos feed
3. Check GitHub notifications weekly (Monday morning)

## Weekly Check Checklist

Run through this each Monday:

- [ ] Check `anthropics/claude-code` releases since last check
- [ ] Check `anthropics/knowledge-work-plugins` commits on main
- [ ] Search for `plugin.json` changes: `git log --oneline -- '**/plugin.json'`
- [ ] Search for hook API changes: `git log --oneline -- '**/hooks/**'`
- [ ] Check if any new required fields appeared in plugin manifests
- [ ] Check if skill/command file format changed
- [ ] Review any new plugins added — compare their structure to ours

## What Breaking Changes Look Like

**High impact (act immediately):**
- New required fields in plugin.json
- Hook API signature changes (different arguments, new required hooks)
- Skill/command file format changes (new frontmatter fields, different directory structure)

**Medium impact (plan for next cycle):**
- New optional plugin.json fields that improve discoverability
- New hook types we should implement
- Patterns adopted by 3+ official plugins that we don't follow

**Low impact (note and monitor):**
- New plugins in unrelated domains
- Documentation-only changes
- CI/CD infrastructure changes

## Response Protocol

1. **Breaking change detected:** Create urgent Linear issue, tag `type:bug`, fix in current cycle
2. **New best practice:** Create Linear issue, tag `type:chore`, schedule for next cycle
3. **No changes:** No action needed, checklist is sufficient documentation
