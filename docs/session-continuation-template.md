# Session Continuation Template

Copy this template when resuming CCC plugin work in a new Claude Code session. Fill in the fields and paste as your opening message.

---

```
Continue CCC Plugin work from session plan: ~/.claude/plans/<plan-file>.md

Session context:
- <last version> shipped (commit <hash>, tagged). <summary of what shipped>.
- Phases <completed list> COMPLETE. <key evidence>.
- Git tags: <list>. <working tree state>.

Remaining work (not yet started — need own planning):
- CIA-XXX: <title> (<estimate>, <size>)
- CIA-XXX: <title> (<estimate>, <size>)

Phase <N> incomplete items (if any):
- CIA-XXX: <what's left>

Task options:
1. <option A>
2. <option B>
3. <option C>

Push to remote when ready: git push origin main --tags
```

---

## Field Reference

| Field | Where to find it |
|-------|-----------------|
| Plan file | `ls ~/.claude/plans/` — use the most recent one for this project |
| Last version | `git tag -l` in the repo |
| Commit hash | `git log --oneline -1` |
| Working tree | `git status --short` |
| Remaining issues | Linear: filter by project + milestone + status:Backlog |
| Estimates | Linear issue detail (points field) |

## Tips

- Include enough context that the new session doesn't need to re-explore the codebase
- List specific issue IDs — don't make the agent search for them
- State what's done with evidence (commit hashes, tag names, closed issue counts)
- Offer 2-3 task options so the session can start with a planning decision, not open-ended exploration
