# Communication Style Guide

Rules for all SDD plugin content: skills, commands, hooks, README, Linear issues, and session output.

## Writing Rules

1. **Plain English first.** No jargon without a definition on first use. If a term only makes sense to someone who already knows it, define it or replace it.
2. **Active voice.** "The skill validates the spec" not "The spec is validated by the skill."
3. **Short sentences.** One idea per sentence. If a sentence has more than 25 words, split it.
4. **Verb-first titles.** Issue titles start with a verb: "Build", "Implement", "Survey", "Evaluate", "Fix". Never bracket prefixes like `[Feature]` or `[Bug]`.
5. **No acronyms in titles.** Spell out on first use. Acronyms are fine in body text after the first definition.
6. **Concrete over abstract.** "Create a STYLE.md file" not "Establish communication standards." Show what, not just why.
7. **No filler.** Cut "in order to" (use "to"), "it should be noted that" (delete), "as a matter of fact" (delete).

## Linear Issues

- Title: verb-first, no brackets, no acronyms, under 80 characters
- Description: problem statement first, then proposed approach, then acceptance criteria
- Comments: status updates and @mentions only — no evidence dumps, spec content, or audit tables (use Linear Documents for those)

## Plugin Content

- Skills: start with a one-sentence purpose statement, then rules as numbered items
- Commands: start with what the command does, then usage, then output format
- Hooks: start with when the hook fires, then what it checks, then what it blocks

## Session Output

- Summaries: 3-5 sentences maximum, 200 words cap
- Tables over paragraphs for structured data
- Link to sources rather than inlining content
