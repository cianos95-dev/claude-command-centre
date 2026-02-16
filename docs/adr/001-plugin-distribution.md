# ADR-001: Plugin Distribution Architecture

**Status:** Accepted
**Date:** 2026-02-16
**Linear:** CIA-442, CIA-443

## Context

CCC was originally two separate plugins (Academic Research Plugin + AI PM Plugin) distributed as a multi-plugin marketplace bundle. The repo was named `spec-driven-development` and used a two-level structure: `plugins/<name>/` subdirectories under a marketplace root.

After consolidating both plugins into a single CCC plugin, the two-level structure became unnecessary indirection. Two failed installation attempts (CIA-442) revealed that the extra nesting, combined with stale state from a repo rename and a `directory`/`github` source conflict, caused persistent cache resolution failures.

## Decisions

### 1. Single-plugin marketplace pattern

**Decision:** Flatten to `source: "./"` — plugin content (`agents/`, `commands/`, `hooks/`, `skills/`) at the repo root alongside `.claude-plugin/marketplace.json`.

**Rationale:** Matches the proven `adversarial-spec` pattern. Eliminates two-level indirection. All single-plugin marketplaces in the ecosystem use this pattern. The bundle structure is only needed for repos hosting multiple plugins.

**Alternatives considered:**
- Keep bundle structure with `source: "./plugins/claude-command-centre"` — rejected because it caused path resolution failures and adds unnecessary complexity for a single plugin.

### 2. GitHub source (not directory)

**Decision:** Use `github` source in `extraKnownMarketplaces`, not `directory`.

**Rationale:**
- **Cowork compatibility:** `directory` source references local filesystem paths. Cowork runs in a sandboxed VM without access to `~/Repositories/`. Only `github` and `url` sources work across both Claude Code and Cowork.
- **Consistency:** All 13 other installed marketplaces use `github` source.
- **Auto-updates:** `github` source supports background auto-updates via `GITHUB_TOKEN`.

**Alternatives considered:**
- `directory` source for development — works in Claude Code but not Cowork. Acceptable for temporary local iteration but not as the default.
- `url` source — functionally equivalent to `github` but less ergonomic.

### 3. No `.mcp.json` in repo

**Decision:** The plugin does not ship an active `.mcp.json`. The file is gitignored.

**Rationale:**
- Claude Code treats any `.mcp.json` at the repo root as an active project-level MCP config
- The CCC repo's `.mcp.json` defined a GitHub MCP at `https://api.githubcopilot.com/mcp/` (HTTP/OAuth) which conflicts with the user's global GitHub MCP (`@modelcontextprotocol/server-github` via stdio)
- Plugins expose skills, commands, and agents — not MCP servers
- MCP configuration is the user's responsibility (global `~/.mcp.json` or Claude Desktop Settings)
- CONNECTORS.md documents reference MCP fragments for users to merge into their own config

### 4. Private repo with GITHUB_TOKEN

**Decision:** Keep the repo private. Require `GITHUB_TOKEN` with `repo` scope for auto-updates.

**Rationale:** Per Anthropic docs: "If `git clone` works for a private repository in your terminal, it works in Claude Code too." The token is loaded from macOS Keychain via `~/.zshrc` on shell startup.

## Consequences

### Positive
- Plugin installs reliably across Claude Code and Cowork
- Single `source: "./"` pattern is simpler to maintain and debug
- No MCP auth errors from conflicting project-level configs
- Clear separation: plugins provide methodology, users provide tool configs

### Negative
- Must push to GitHub before testing changes (no local directory shortcut)
- After repo renames, `known_marketplaces.json` must be manually cleaned (Claude Code does not auto-detect renames)

### Risks
- Anthropic may change the plugin system in ways that require restructuring
- `GITHUB_TOKEN` rotation must be managed (Keychain entry: `claude/github/main`)

## Stale State Cleanup Protocol

After repo renames or structural changes:

1. Remove stale entry from `~/.claude/plugins/known_marketplaces.json`
2. Remove stale entry from `~/.claude/plugins/installed_plugins.json`
3. Delete stale marketplace clone: `rm -rf ~/.claude/plugins/marketplaces/<marketplace-name>/`
4. Delete stale cache: `rm -rf ~/.claude/plugins/cache/<marketplace-name>/`
5. Re-add marketplace: `/plugin marketplace add <owner>/<new-repo-name>`
6. Reinstall plugin: `/plugin install <plugin-name>@<marketplace-name>`
