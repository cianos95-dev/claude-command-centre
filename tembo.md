# Tembo Agent Instructions — Claude Command Centre

## Repository Overview

CCC is a Claude Code plugin (skills, commands, agents, hooks). It is a **markdown/config-only repo** — no build toolchain, no JS/TS source, no package manager.

## Repository Structure

```
claude-command-centre/
├── .claude-plugin/        # Plugin manifest (plugin.json)
├── agents/                # Agent definitions (*.md)
├── commands/              # Slash commands (*.md)
├── hooks/                 # Hook scripts (*.sh, *.md)
│   └── scripts/           # Shell scripts for hooks
├── skills/                # Skill definitions (*/SKILL.md)
├── docs/                  # ADRs, specs, guides
├── CONNECTORS.md          # Agent connector documentation
├── COMPANIONS.md          # Companion agent documentation
└── CHANGELOG.md           # Version history
```

## Branch & Commit Convention

- Branch: `tembo/<task-slug>` (e.g., `tembo/update-connectors-docs`)
- Commits: Conventional style — `fix:`, `feat:`, `chore:`, `docs:`
- PR body must include `Closes CIA-XXX` referencing the Linear issue

## Key Rules

- **No build chain** — do not create `package.json`, `tsconfig.json`, or install dependencies
- **Version bump**: If adding/removing/renaming a skill, command, agent, or hook, bump the version in `.claude-plugin/plugin.json` and add a CHANGELOG.md entry
- **Skill format**: Each skill lives in `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`)
- **Agent format**: Each agent lives in `agents/<name>.md` with YAML frontmatter
- **Command format**: Each command lives in `commands/<name>.md` with YAML frontmatter
- **File paths**: Use kebab-case for directories and files
- **Markdown**: Use GitHub-flavored markdown

## Linear Project

All issues belong to **Claudian** team, project **Claude Command Centre (CCC)**.
