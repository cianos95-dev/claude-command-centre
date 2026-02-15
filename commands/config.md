---
description: |
  Manage SDD preferences for the current project. Customise gates, execution parameters, prompt enrichments, and Cowork behavior.
  Use to view current config, reset to defaults, or set individual preferences.
  In Cowork: generates an interactive artifact with live YAML preview and preset buttons.
  Trigger with phrases like "configure sdd", "show sdd preferences", "set gate preferences", "sdd config", "customise workflow", "change execution defaults".
argument-hint: "[--show | --reset | key=value]"
platforms: [cli, cowork]
---

# Config -- SDD Preferences Manager

Manage `.sdd-preferences.yaml` for the current project. Preferences customise gates, execution parameters, prompt enrichments, and Cowork behavior.

## Step 1: Detect Platform and Mode

### CLI Mode

When running in Claude Code (file system available):

| Argument | Action |
|----------|--------|
| `--show` | Display current prefs merged with defaults (Step 2) |
| `--reset` | Generate fresh `.sdd-preferences.yaml` with all defaults + comments (Step 3) |
| `key=value` | Set a specific preference (Step 4) |
| (none) | Interactive walkthrough of all categories (Step 5) |

### Cowork Mode

When running in Cowork (no file system access):

Generate an interactive artifact with a live YAML preview. See Step 6 for the artifact specification.

## Step 2: Show Current Config (`--show`)

1. Look for `.sdd-preferences.yaml` in the project root.
2. If found, parse with `yq` and merge with defaults (defaults fill any missing keys).
3. If not found, show all defaults with a note: "No `.sdd-preferences.yaml` found — using all defaults."
4. Display as a formatted table:

```
SDD Preferences (merged with defaults)

Gates
  spec_approval:       true  (default)
  review_acceptance:   true  (default)
  pr_review:           false ← overridden

Execution
  max_task_iterations:    5  (default)
  max_global_iterations: 50  (default)
  default_mode:          tdd ← overridden

Prompts
  subagent_discipline:   true  (default)
  search_before_build:   true  (default)
  agents_file:           true  (default)

Cowork
  default_to_planning:   true  (default)
  warn_on_build:         true  (default)

Replan
  enabled:                    true  (default)
  max_replans_per_session:    2     (default)
```

Mark overridden values with `← overridden` to distinguish from defaults.

## Step 3: Reset to Defaults (`--reset`)

1. Copy `examples/sample-preferences.yaml` (from the plugin installation directory) to `.sdd-preferences.yaml` in the project root.
2. If the file already exists, ask for confirmation: "This will overwrite your current preferences. Continue?"
3. Confirm creation: "`.sdd-preferences.yaml` created with all defaults. Edit as needed."

## Step 4: Set a Single Value (`key=value`)

1. Parse the key using dot notation: `gates.pr_review=false` → `gates.pr_review` = `false`
2. Validate the key exists in the schema. If not, show available keys.
3. Validate the value type:
   - Booleans: `true` / `false`
   - Numbers: integer within documented range
   - Enums: one of the allowed values (e.g., `quick|tdd|pair|checkpoint|swarm|null` for `default_mode`)
4. If `.sdd-preferences.yaml` does not exist, create it with only the specified key (other keys will use defaults).
5. If the file exists, update the specific key using `yq`.
6. Confirm: "Set `gates.pr_review` = `false`."

### Valid Keys

| Key | Type | Values | Default |
|-----|------|--------|---------|
| `gates.spec_approval` | bool | true/false | true |
| `gates.review_acceptance` | bool | true/false | true |
| `gates.pr_review` | bool | true/false | true |
| `execution.max_task_iterations` | int | 1-20 | 5 |
| `execution.max_global_iterations` | int | 1-200 | 50 |
| `execution.default_mode` | enum | null, quick, tdd, pair, checkpoint, swarm | null |
| `prompts.subagent_discipline` | bool | true/false | true |
| `prompts.search_before_build` | bool | true/false | true |
| `prompts.agents_file` | bool | true/false | true |
| `cowork.default_to_planning` | bool | true/false | true |
| `cowork.warn_on_build` | bool | true/false | true |
| `replan.enabled` | bool | true/false | true |
| `replan.max_replans_per_session` | int | 1-10 | 2 |

## Step 5: Interactive Mode (no args, CLI)

Walk through each preference category in order. For each category:

1. Show the current values (from file or defaults).
2. Ask if the user wants to change anything in this category.
3. If yes, present each preference with its description and current value. Accept new values.
4. Move to the next category.

Categories in order: Gates → Execution → Prompts → Cowork → Replan.

Offer preset shortcuts at the start:

```
SDD Preferences Configuration

Quick presets:
  [1] Full Ceremony (default) — All 3 gates, all enrichments
  [2] Solo Developer — Gate 3 only, all enrichments
  [3] Autonomous — No gates, all enrichments
  [4] Research Mode — All gates, TDD default mode
  [C] Custom — Walk through each category

Choose a preset or [C] for custom:
```

### Preset Definitions

| Preset | gates.spec | gates.review | gates.pr | execution.default_mode | Other |
|--------|-----------|-------------|---------|----------------------|-------|
| Full Ceremony | true | true | true | null | All defaults |
| Solo Developer | false | false | true | null | All defaults |
| Autonomous | false | false | false | null | All defaults |
| Research Mode | true | true | true | tdd | All defaults |

After applying a preset, still offer to customise individual values.

## Step 6: Cowork Artifact Mode

When running in Cowork (no file system), generate a React artifact that provides an interactive preferences UI.

### Artifact Requirements

The artifact must include:

1. **Header** with title "SDD Preferences" and brief description.

2. **Preset Buttons** — 4 buttons across the top:
   - Full Ceremony (default) | Solo Developer | Autonomous | Research Mode
   - Clicking a preset updates all form values to match that preset.

3. **Gates Section** — 3 toggle switches:
   - Spec Approval (Gate 1) — with risk note: "Disabling skips human spec review"
   - Review Acceptance (Gate 2) — with risk note: "Disabling skips adversarial review acceptance"
   - PR Review (Gate 3) — with risk note: "Disabling skips PR review before merge"

4. **Execution Section**:
   - Max Task Iterations — number input (1-20, default 5)
   - Max Global Iterations — number input (1-200, default 50)
   - Default Mode — dropdown: Auto (null), Quick, TDD, Pair, Checkpoint, Swarm

5. **Prompt Enrichment Section** — 3 toggles:
   - Subagent Discipline — "Parallel reads, single build/test"
   - Search Before Build — "Search codebase before implementing"
   - Agents File — "Read .sdd-agents.md for project patterns"

6. **Cowork Section** — 2 toggles:
   - Default to Planning — "Route Cowork to planning, not building"
   - Warn on Build — "Show warning when attempting to build"

7. **Replan Section**:
   - Enable Replan — toggle
   - Max Replans — number input (1-10, default 2)

8. **Output Section** — at the bottom:
   - Live YAML preview that updates as form values change
   - "Copy YAML" button that copies the YAML to clipboard
   - Instructions text: "Save as `.sdd-preferences.yaml` in your project root, or run `/sdd:config --reset` in Claude Code and edit."

### Artifact Style

- Clean, minimal UI with clear section headers
- Toggle switches for booleans, number inputs for integers, dropdown for enums
- Preset buttons should visually indicate which preset is active (if any)
- YAML preview in a monospace code block with syntax highlighting
- Responsive layout that works in the Cowork artifact panel

## What If

| Situation | Response |
|-----------|----------|
| `yq` not installed (CLI) | Warn: "`yq` is required for preference parsing. Install with `brew install yq`. The stop handler will use all defaults until yq is available." Still allow `--show` (display defaults), `--reset` (create file), but skip `key=value` (requires yq for safe YAML editing). |
| File exists but has invalid YAML | Show the parse error and suggest `--reset` to regenerate. |
| Unknown key in `key=value` | List all valid keys with their descriptions. |
| Value out of range | Show the valid range and reject the change. |
| Cowork + `--reset` | Explain that Cowork cannot write files. Generate the artifact instead. |
| Cowork + `key=value` | Explain that Cowork cannot write files. Generate the artifact pre-filled with the specified value. |

## Integration Notes

- **Stop handler reads preferences.** The stop hook loads `.sdd-preferences.yaml` at the start of each run and applies the values to gate checks, prompt enrichment, and replan logic.
- **Schema source of truth.** `examples/sample-preferences.yaml` is the canonical schema. This command copies from it for `--reset` and validates against it for `key=value`.
- **No runtime dependency on this command.** Preferences work without ever running `/sdd:config` — the stop handler defaults are baked in. This command is a convenience for discovery and editing.
