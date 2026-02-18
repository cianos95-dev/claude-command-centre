---
description: |
  Sync template manifest files to the Linear workspace. Reads all templates/*.json manifests,
  resolves symbolic names to workspace UUIDs, compares against live templates, creates missing
  templates, and detects/fixes drift. The canonical one-way sync: manifests are the source of truth.
  Trigger with phrases like "sync templates", "push templates", "template sync", "update workspace templates".
argument-hint: "[--dry-run] [--fix] [--verbose]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
platforms: [cli, cowork]
---

# Template Sync

Sync template manifest files from `templates/*.json` to the Linear workspace. Manifests are the **source of truth** — this command pushes manifest definitions into Linear, creating missing templates and detecting drift in existing ones.

## Relationship to Other Template Commands

| Command | Direction | Purpose |
|---------|-----------|---------|
| `template-bootstrap` | Code → Linear | First-time provisioning (labels + templates + projects). Idempotent. Skips existing. |
| `template-validate` | Linear → Report | Read-only audit. Detects stale references and drift. Reports health score. |
| **`template-sync`** | Code → Linear | Ongoing sync. Creates missing. Detects drift. `--fix` applies corrections. |

`template-sync` is the day-to-day command. Use `template-bootstrap` for fresh workspaces. Use `template-validate` for CI health checks.

## Test Scenarios

Before implementing, verify the command handles these scenarios correctly. After implementation, re-run each scenario to confirm.

### TS-1: All templates in sync (no drift)

**Given:** All manifest files have `linearId` populated and live templates match manifests exactly.
**When:** `template-sync` is run.
**Then:**
- All templates show status `IN_SYNC`
- Summary: 0 created, 0 drifted, N in sync
- No mutations executed

### TS-2: New manifest file without linearId

**Given:** A manifest file with `"linearId": null` and no matching live template by name.
**When:** `template-sync` is run.
**Then:**
- Template reported as `MISSING` in the sync table
- Without `--fix`: "1 template needs creation. Run with `--fix` to apply."
- With `--fix`: Template created via `templateCreate`, manifest updated with returned `linearId`

### TS-3: Drifted template (labels changed in UI)

**Given:** Manifest specifies `labels: ["type:feature", "spec:draft"]` but the live template has an additional label added via the Linear UI.
**When:** `template-sync` is run.
**Then:**
- Template reported as `DRIFTED` with diff showing extra label
- Without `--fix`: Diff displayed, no mutation
- With `--fix`: `templateUpdate` mutation restores manifest state
- With `--verbose`: Full before/after JSON shown

### TS-4: Drifted template (estimate changed in UI)

**Given:** Manifest specifies `estimate: 3` but the live template has `estimate: 5`.
**When:** `template-sync` is run.
**Then:**
- Template reported as `DRIFTED` with diff: `estimate: 3 → 5`
- With `--fix`: Estimate restored to 3

### TS-5: Dry run mode

**Given:** Mix of in-sync, missing, and drifted templates.
**When:** `template-sync --dry-run` is run.
**Then:**
- All actions prefixed with `[DRY RUN]`
- No GraphQL mutations executed
- No manifest files written
- Full report showing what WOULD happen

### TS-6: Stale linearId (template deleted from Linear)

**Given:** Manifest has `linearId` set but no live template exists with that ID.
**When:** `template-sync` is run.
**Then:**
- Template reported as `MISSING (stale ID)`
- With `--fix`: New template created, manifest updated with new `linearId`
- Additional check: search by name+type before creating to avoid duplicates

### TS-7: Document template sync (no labels/state)

**Given:** A document template manifest with only `title` and `descriptionData`.
**When:** `template-sync` processes it.
**Then:**
- No symbolic resolution needed
- Drift detection compares `title` and `descriptionData` only
- Creation/update works correctly without label/state fields

### TS-8: Live template with no manifest (orphan)

**Given:** A template exists in Linear but has no corresponding manifest file.
**When:** `template-sync` is run.
**Then:**
- Reported as `UNMANAGED` in the sync table
- No action taken (manifests are source of truth — unmanaged templates are not deleted)
- Suggested action: "Create a manifest file or delete from Linear if obsolete"

### TS-9: Fix with confirmation

**Given:** Multiple drifted templates.
**When:** `template-sync --fix` is run (interactive mode).
**Then:**
- Each fix presented with a diff preview
- User asked "Apply N fixes? (y/n)" before executing mutations
- Fixes applied only after confirmation

### TS-10: Verbose output

**Given:** A drifted template.
**When:** `template-sync --verbose` is run.
**Then:**
- Full before/after JSON for each drifted field (not just field names)
- For `descriptionData`: note "descriptionData differs" without dumping the full ProseMirror tree (too noisy)

## Prerequisites

Requires a Linear API token. The command reads the token from one of:
1. `LINEAR_API_KEY` environment variable
2. `LINEAR_AGENT_TOKEN` environment variable
3. The Linear OAuth token from `~/.mcp.json` (parse the `linear` MCP server config)

If no token is found, prompt the user to provide one.

### Token Resolution (Bash)

```bash
LINEAR_TOKEN="${LINEAR_API_KEY:-${LINEAR_AGENT_TOKEN:-}}"
if [ -z "$LINEAR_TOKEN" ]; then
  LINEAR_TOKEN=$(cat ~/.mcp.json | jq -r '.mcpServers.linear.env.LINEAR_API_KEY // empty' 2>/dev/null)
fi
if [ -z "$LINEAR_TOKEN" ]; then
  LINEAR_TOKEN=$(cat ~/.mcp.json | jq -r '.mcpServers.linear.headers.Authorization // empty' 2>/dev/null | sed 's/^Bearer //')
fi
```

## Step 0: Parse Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Show what would change without executing mutations or writing files |
| `--fix` | Apply drift corrections and create missing templates |
| `--verbose` | Show full diff for each drifted template (expanded field comparison) |

Default (no flags): detect and report only. Same as `--dry-run` but without the `[DRY RUN]` prefix — it's the natural read-only mode.

**Flag combinations:**
- `--fix --verbose`: Apply fixes with detailed diff output
- `--fix --dry-run`: Contradiction — `--dry-run` takes precedence. Show what `--fix` would do without applying.
- `--verbose` alone: Detailed report, no mutations

## Step 1: Fetch Workspace Reference Data

Query the current workspace state to build lookup maps for symbolic name resolution and drift comparison.

### 1a: Fetch All Labels

Use `list_issue_labels` (limit: 250) to get all workspace and team labels.

Build lookup map: `labelName → labelId`

### 1b: Fetch All Teams

Use `list_teams` to get all teams.

Build lookup map: `teamName → teamId`

### 1c: Fetch Issue Statuses

For each team referenced in manifests, use `list_issue_statuses(team)` to get valid states.

Build lookup map: `teamName:stateName → stateId`

### 1d: Fetch Existing Templates via GraphQL

Execute a GraphQL query to get all live templates:

```graphql
{
  templates {
    nodes {
      id
      name
      type
      templateData
      team {
        id
        name
      }
    }
  }
}
```

Build lookup maps:
- `templateId → { id, name, type, templateData, team }`
- `templateName:type → templateId` (for name-based matching when `linearId` is null)

### 1e: Fetch Users (for assignee resolution)

Use `list_users` to get workspace members.

Build lookup map: `userName → userId`

## Step 2: Read and Parse Manifest Files

```
Glob: templates/*.json
Exclude: schema.json, README.md
```

For each manifest file:
1. Parse JSON
2. Validate required fields: `name`, `type`, `templateData`
3. If invalid, log error and skip: `[ERROR] templates/bad-file.json: missing required field 'name'`

Build manifest list: `[ { filename, manifest } ]`

## Step 3: Resolve Symbolic Names

For each manifest, resolve symbolic references in `templateData` to workspace UUIDs.

### 3a: Issue Templates

1. `labels` → `labelIds`: For each label name, look up UUID from the label map.
   - **If unresolvable:** Log `[ERROR] Cannot resolve label 'X' for template 'Y'`. Mark template as `RESOLUTION_ERROR`. Skip this template.
2. `state` → `stateId`: Look up state UUID from the team-scoped state map.
3. `team` → `teamId`: Look up team UUID from the team map.
4. `assignee` → `assigneeId`: Look up user UUID. Skip if null.
5. Preserve scalar fields: `title`, `priority`, `estimate`, `descriptionData`.
6. Remove symbolic fields from the resolved output.
7. Serialize as JSON string (Linear stores `templateData` as a string).

### 3b: Document Templates

No symbolic resolution needed. Serialize `templateData` as JSON string.

### 3c: Project Templates

1. Resolve `templateData` same as issue templates (if it has labels/state/team).
2. Resolve `projectTemplateData`:
   - `leadId` → user UUID
   - `statusId` → project status name (pass through — project statuses use name, not UUID)
   - `teamIds` → array of team UUIDs
   - `labelIds` → array of label UUIDs
   - `memberIds` → array of user UUIDs
   - `initiativeIds` → skip if empty

## Step 4: Compare Manifest Against Live Templates

For each resolved manifest, determine its sync status:

### 4a: Match Manifest to Live Template

1. **If `linearId` is set:** Look up in the live template map by ID.
   - **Found:** Proceed to drift comparison (Step 4b).
   - **Not found:** `linearId` is stale. Check by name+type (Step 4a-ii).
2. **If `linearId` is null:** Search by name+type in live templates.
   - **Found:** This is a linkable template. Status: `LINKABLE`.
   - **Not found:** Status: `MISSING`.

### 4b: Drift Comparison

Compare the resolved manifest `templateData` against the live template's `templateData` (parsed from JSON string). Check each field:

| Field | Comparison | Drift Severity |
|-------|-----------|----------------|
| `labelIds` | Set comparison (order-independent) | DRIFT |
| `stateId` | Exact match | DRIFT |
| `teamId` | Exact match | DRIFT |
| `estimate` | Exact match | DRIFT |
| `priority` | Exact match | DRIFT |
| `title` | Exact match | DRIFT |
| `descriptionData` | Deep equality | DRIFT (reported but not auto-fixed — too complex) |
| `assigneeId` | Exact match | DRIFT |

For each field that differs, record a drift entry:

```
{ field: "estimate", manifest: 3, live: 5 }
{ field: "labelIds", manifest: ["id-a", "id-b"], live: ["id-a", "id-c"], added: ["id-b"], removed: ["id-c"] }
```

### 4c: Assign Sync Status

| Status | Meaning |
|--------|---------|
| `IN_SYNC` | Live template matches manifest exactly |
| `DRIFTED` | Live template exists but fields differ from manifest |
| `MISSING` | No live template found (needs creation) |
| `LINKABLE` | Live template found by name but manifest has no `linearId` (needs linking) |
| `RESOLUTION_ERROR` | Symbolic names could not be resolved |

### 4d: Detect Unmanaged Templates

After processing all manifests, check for live templates that have no corresponding manifest:
- For each live template, check if any manifest references its ID or matches its name+type.
- If not matched: status `UNMANAGED`.

## Step 5: Output Sync Report

```
## Template Sync Report

**Workspace:** [workspace name]
**Date:** [ISO-8601 timestamp]
**Mode:** [report | dry-run | fix]
**Manifests scanned:** N

### Sync Table

| # | Template | Type | Manifest | Status | Details |
|---|----------|------|----------|--------|---------|
| 1 | Feature | issue | issue-feature.json | IN_SYNC | — |
| 2 | Bug | issue | issue-bug.json | DRIFTED | estimate: 3→5, +1 label |
| 3 | My New Template | issue | issue-new.json | MISSING | Will create |
| 4 | Old Template | issue | — | UNMANAGED | No manifest file |
| 5 | PR/FAQ | document | doc-prfaq.json | IN_SYNC | — |
```

If `--verbose` and a template is `DRIFTED`:

```
### Drift: Bug (issue-bug.json)

  estimate: 3 (manifest) → 5 (live)
  labelIds:
    + spec:draft (in manifest, missing from live)
    - exec:quick (in live, not in manifest)
```

### Summary

```
### Summary

- IN_SYNC: N templates
- DRIFTED: N templates (M fixable fields)
- MISSING: N templates (will create with --fix)
- LINKABLE: N templates (will link with --fix)
- UNMANAGED: N live templates (no manifest)
- ERRORS: N templates (resolution failures)
```

### Actionable Output

If any templates are not `IN_SYNC`:

```
### Actions Required

Run `template-sync --fix` to:
  - Create N missing templates
  - Link N templates by name
  - Fix M drifted fields across N templates

Run `template-sync --fix --verbose` for detailed diff before applying.
```

If all templates are `IN_SYNC`:

```
All N templates are in sync. No action needed.
```

## Step 6: Apply Fixes (--fix)

Only executed when `--fix` is passed and `--dry-run` is NOT passed.

### 6a: Present Fix Plan

Before executing any mutations, present a summary of all changes:

```
## Fix Plan

Will apply the following changes:

1. [CREATE] "My New Template" (issue) — from issue-new.json
2. [LINK] "Feature" — write linearId 9ba890c6 to issue-feature.json
3. [UPDATE] "Bug" — restore estimate: 5→3, add label spec:draft
4. [UPDATE] "Chore" — restore priority: 2→0

Apply 4 changes? (y/n)
```

Wait for user confirmation before proceeding. Never auto-apply in interactive mode.

### 6b: Execute Creates

For each `MISSING` template:

```graphql
mutation($input: TemplateCreateInput!) {
  templateCreate(input: $input) {
    success
    template {
      id
      name
      type
    }
  }
}
```

Variables:
```json
{
  "input": {
    "name": "Template Name",
    "type": "issue",
    "description": "Template description",
    "templateData": "{...resolved JSON string...}",
    "teamId": "ee778ac4-..."
  }
}
```

- `teamId` in `input` is for team-scoped templates. Omit for workspace-level templates.
- `templateData` is a **JSON string**, not an object.
- `type` uses manifest values: `"issue"`, `"document"`, `"project"`.

After successful creation, update the manifest file with the returned `linearId`:
1. Read the manifest file.
2. Set `linearId` to the returned `template.id`.
3. Write back with same formatting (2-space indent, trailing newline).

### 6c: Execute Links

For each `LINKABLE` template:
1. Write the matched live template's `id` as the manifest's `linearId`.
2. No GraphQL mutation needed — just a file write.

### 6d: Execute Updates

For each `DRIFTED` template:

```graphql
mutation($id: String!, $input: TemplateUpdateInput!) {
  templateUpdate(id: $id, input: $input) {
    success
    template {
      id
      name
      templateData
    }
  }
}
```

Variables:
```json
{
  "id": "template-uuid",
  "input": {
    "templateData": "{...resolved JSON string with manifest values...}"
  }
}
```

The `templateData` in the update contains the **full resolved manifest templateData** — not a partial patch. This ensures the live template exactly matches the manifest after update.

**Exception:** `descriptionData` drift is reported but NOT auto-fixed. ProseMirror documents are complex and auto-updating them risks data loss. Log: `[SKIP] descriptionData drift for "Bug" — manual review recommended.`

### 6e: Post-Fix Verification

After all mutations complete:
1. Re-fetch live templates (repeat Step 1d).
2. Re-run comparison (repeat Step 4).
3. Report post-fix status:

```
## Post-Fix Verification

4 changes applied.
- 1 template created
- 1 template linked
- 2 templates updated

Re-validation: N/N templates now IN_SYNC.
Remaining drift: M templates (descriptionData — manual review needed)
```

## Execution via Bash

### GraphQL Calls

```bash
# Fetch all live templates
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: Bearer $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ templates { nodes { id name type templateData team { id name } } } }"}'
```

```bash
# Create a template
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: Bearer $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($input: TemplateCreateInput!) { templateCreate(input: $input) { success template { id name type } } }",
    "variables": {
      "input": {
        "name": "Feature",
        "type": "issue",
        "description": "New functionality or capability",
        "templateData": "{...}",
        "teamId": "ee778ac4-..."
      }
    }
  }'
```

```bash
# Update a template
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: Bearer $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($id: String!, $input: TemplateUpdateInput!) { templateUpdate(id: $id, input: $input) { success template { id name templateData } } }",
    "variables": {
      "id": "template-uuid",
      "input": {
        "templateData": "{...}"
      }
    }
  }'
```

### MCP Calls (for reference data)

```
list_issue_labels(limit: 250)      → label name → ID map
list_teams()                        → team name → ID map
list_issue_statuses(team: "X")      → state name → ID map per team
list_users()                        → user name → ID map
```

## What If

| Situation | Response |
|-----------|----------|
| **No Linear token found** | Error: "No Linear API token found. Set LINEAR_API_KEY, LINEAR_AGENT_TOKEN, or configure Linear MCP in ~/.mcp.json." |
| **GraphQL query fails** | Error with HTTP status and message. Suggest checking token permissions. |
| **No manifest files found** | Error: "No template manifests found in templates/. Run template-bootstrap first or create manifests manually." |
| **Manifest is invalid JSON** | Log error, skip that manifest, continue with others. Include in error count. |
| **Symbolic name unresolvable** | Log error for that template. Other templates continue processing. Summary includes error count. |
| **All templates in sync** | Report "All N templates are in sync. No action needed." |
| **--fix with no changes needed** | Info: "All templates are in sync. Nothing to fix." |
| **--fix with only descriptionData drift** | Info: "N templates have descriptionData drift (manual review). No auto-fixable changes." |
| **--dry-run --fix** | `--dry-run` takes precedence. Show the fix plan without executing. |
| **Template create fails (rate limit)** | Log error, wait 60s, retry once. If still fails, skip and continue. |
| **Template update fails** | Log error with mutation details. Continue with other templates. Include in error count. |
| **Manifest linearId points to template in different workspace** | ID won't be found in live templates. Treated as stale — same as TS-6. |
| **Multiple live templates match same name+type** | WARN: "Multiple live templates match 'Feature' (issue). Using first match. Consider setting linearId manually." |
| **descriptionData is the only drift** | Template status is still `DRIFTED` but marked as `not auto-fixable`. |
| **Variant overrides drift** | Variants are not separate Linear templates — they're manifest-only constructs used by `spec-author`. Variant definitions are not synced to Linear and are not checked for drift by this command. Use `template-validate` for variant validation. |
| **Project template with projectTemplateData** | Resolve `projectTemplateData` symbolic names but do NOT include in drift comparison (Linear's `templateData` response may not include project-specific fields in the same structure). Log INFO if project template has drift in `templateData` fields. |
| **Concurrent modification** | No locking. If someone modifies a template between fetch and update, the update overwrites with manifest state. Manifests are the source of truth — this is intentional. |
