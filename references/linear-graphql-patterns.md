# Linear GraphQL Patterns (MCP Gaps)

> **Created:** 26 Feb 2026
> **Updated:** 26 Feb 2026 — consolidated from 3 files
> **Issue:** CIA-745
> **Sources:** CIA-537 (project updates), CIA-539 (dependency management), CIA-571 (velocity), CIA-705 (dispatch server)

The Linear MCP covers most operations. This reference documents patterns that **require direct GraphQL** because the MCP has no equivalent tool.

## Auth Rule

**GraphQL mutations require `$LINEAR_API_KEY` (`lin_api_*`), NOT OAuth tokens.**

The MCP uses OAuth (agent token `dd0797a4`). Direct GraphQL calls use the personal API key from Keychain:

```bash
LINEAR_KEY=$(security find-generic-password -s "claude/linear-api-key" -w)
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { ... }"}'
```

OAuth tokens work for reads but mutations on some endpoints require the API key.

## Input Validation

Before constructing any GraphQL query, validate inputs to prevent injection:

```javascript
function validateUuid(input) {
  if (/^[a-f0-9-]{36}$/.test(input)) return true;
  throw new Error(`Invalid UUID: "${input}". Must be UUID format.`);
}

function validateIssueId(input) {
  if (/^[A-Z]+-\d+$/.test(input)) return { valid: true, format: 'identifier' };
  if (/^[a-f0-9-]+$/.test(input)) return { valid: true, format: 'uuid' };
  throw new Error(`Invalid issue ID: "${input}". Must be "ABC-123" or UUID format.`);
}
```

**Always validate before string interpolation in queries.**

## Identifier-to-UUID Resolution

GraphQL mutations require UUIDs, not identifiers like `CIA-539`. Prefer MCP `get_issue` (accepts identifiers, returns UUID in `id` field). Fallback GraphQL:

```graphql
query ResolveIdentifier($filter: IssueFilter!) {
  issues(filter: $filter) {
    nodes { id identifier }
  }
}
```

With variables: `{ "filter": { "team": { "key": { "eq": "CIA" } }, "number": { "eq": 539 } } }`

For projects, use MCP `get_project(name: "Claude Command Centre (CCC)")` or:

```graphql
query ResolveProject($name: String!) {
  projects(filter: { name: { containsIgnoreCase: $name } }, first: 1) {
    nodes { id name }
  }
}
```

---

## 1. Document Delete

**MCP gap:** No `delete_document` tool. MCP only has `create_document`, `update_document`, `get_document`, `list_documents`.

```graphql
mutation {
  documentDelete(id: "document-uuid") {
    success
  }
}
```

**Use case:** Cleaning up archived/stale documents. Batch deletion:
```bash
LINEAR_KEY=$(security find-generic-password -s "claude/linear-api-key" -w)
for id in "uuid1" "uuid2" "uuid3"; do
  curl -s -X POST https://api.linear.app/graphql \
    -H "Authorization: $LINEAR_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"mutation { documentDelete(id: \\\"$id\\\") { success } }\"}"
done
```

**Discovered:** 26 Feb 2026. Used to delete 34 archived CCC documents.

---

## 2. Project Status Updates

**MCP gap:** MCP `save_status_update` only supports `type: "initiative"`. Project-level updates require GraphQL.

### Create

```graphql
mutation ProjectUpdateCreate($input: ProjectUpdateCreateInput!) {
  projectUpdateCreate(input: $input) {
    success
    projectUpdate { id body health createdAt url project { id name } }
  }
}
```

Variables: `{ "input": { "projectId": "<uuid>", "body": "## Progress\n...", "health": "onTrack" } }`

Health enum: `onTrack` | `atRisk` | `offTrack`

### Update (same-day dedup)

```graphql
mutation ProjectUpdateUpdate($id: String!, $input: ProjectUpdateUpdateInput!) {
  projectUpdateUpdate(id: $id, input: $input) {
    success
    projectUpdate { id body health updatedAt }
  }
}
```

### Delete

```graphql
mutation ProjectUpdateDelete($id: String!) {
  projectUpdateDelete(id: $id) { success }
}
```

### Fetch existing (dedup check)

```graphql
query ProjectUpdates($projectId: ID!, $since: DateTime!) {
  projectUpdates(
    filter: { project: { id: { eq: $projectId } }, createdAt: { gte: $since } }
    first: 1
    orderBy: createdAt
  ) {
    nodes { id body health createdAt url }
  }
}
```

**Shell invocation:** Use `node --input-type=module` with `process.env.LINEAR_API_KEY` for auth. See `status-update` skill for the full posting protocol.

**Best-effort:** When called during session-exit, surface errors as warnings only. Never block session exit on update failures.

**Source:** CIA-537

---

## 3. Issue Relations

**MCP gap:** MCP `save_issue` with relation params REPLACES the entire array. For surgical add/remove/update of individual relations, use GraphQL.

### Relation types

| Type | Meaning | Inverse |
|------|---------|---------|
| `blocks` | Source blocks target | Target is `blockedBy` source |
| `duplicate` | Source duplicates target | Target is `duplicateOf` source |
| `related` | Bidirectional | Same |

Note: `blockedBy` is not a separate GraphQL type — to create "A blockedBy B", create "B blocks A".

### Create relation

```graphql
mutation IssueRelationCreate($input: IssueRelationCreateInput!) {
  issueRelationCreate(input: $input) {
    success
    issueRelation { id type issue { identifier } relatedIssue { identifier } }
  }
}
```

Variables: `{ "input": { "issueId": "<source-uuid>", "relatedIssueId": "<target-uuid>", "type": "blocks" } }`

### Update relation

```graphql
mutation IssueRelationUpdate($id: String!, $input: IssueRelationUpdateInput!) {
  issueRelationUpdate(id: $id, input: $input) {
    success
    issueRelation { id type issue { identifier } relatedIssue { identifier } }
  }
}
```

Requires the **relation UUID** (not issue UUID). Obtain from create response or query below.

### Delete relation

```graphql
mutation IssueRelationDelete($id: String!) {
  issueRelationDelete(id: $id) { success }
}
```

### Query relations (find relation UUID)

```graphql
query IssueRelations($id: String!) {
  issue(id: $id) {
    relations { nodes { id type relatedIssue { id identifier title } } }
    inverseRelations { nodes { id type issue { id identifier title } } }
  }
}
```

**Source:** CIA-539. See `issue-lifecycle` skill → `references/dependency-protocol.md` for the `safeUpdateRelations` wrapper.

---

## 4. Velocity Queries

**MCP gap:** No cycle scope/velocity data available through MCP tools.

```graphql
query {
  cycles(filter: { team: { key: { eq: "CIA" } } }, first: 5) {
    nodes {
      id name number
      startsAt endsAt
      scopeHistory
      completedScopeHistory
      issues { nodes { identifier estimate { value } completedAt } }
    }
  }
}
```

`scopeHistory` and `completedScopeHistory` are arrays of daily snapshots — useful for burn-down charts and velocity estimation.

**Source:** CIA-571

---

## 5. Issue History (Audit Trail)

**MCP gap:** No issue history/changelog available through MCP.

```graphql
query {
  issueHistory(issueId: "issue-uuid", first: 20) {
    nodes {
      id createdAt
      fromState { name } toState { name }
      fromAssignee { name } toAssignee { name }
      actor { name }
    }
  }
}
```

Useful for: tracking status transition times, identifying bottlenecks, audit trails.

**Source:** CIA-571

---

## 6. Hook-Driven Writes via Dispatch Server

**MCP gap:** Claude Code hooks can't make HTTP calls to Linear directly. The dispatch server (CIA-705) provides a `/linear-update` route for hook-driven writes.

```
Hook script → HTTP POST to localhost:PORT/linear-update → GraphQL mutation → Linear API
```

Currently deferred — dispatch server deleted (Feb 2026). Hooks that need Linear writes use MCP tools within session context.

**Source:** CIA-705

---

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `Entity not found` | UUID does not exist | Verify via MCP `get_issue`/`get_project` first |
| `Relation already exists` | Duplicate relation | Skip silently |
| `Unauthorized` (401) | Using OAuth token instead of API key | Switch to `$LINEAR_API_KEY` |
| `Rate limited` | Too many requests | Wait and retry with exponential backoff |
| `Invalid input` | Malformed body or invalid enum | Validate inputs before sending |

**Unified interface:** Surface GraphQL errors only in verbose/debug mode. In normal mode: "Operation failed. Use `--verbose` for details."

---

## Cross-References

| Skill | Uses GraphQL For |
|-------|-----------------|
| `status-update` | `projectUpdateCreate`, `projectUpdateUpdate`, `projectUpdateDelete` |
| `issue-lifecycle` → Dependencies | `issueRelationCreate`, `issueRelationUpdate`, `issueRelationDelete` |
| `template-sync` | Template CRUD via GraphQL (MCP has no template tools) |
| `template-validate` | Template queries (read-only) |
| `milestone-forecast` | Cycle velocity queries |
| `document-lifecycle` | `documentDelete` (cleanup) |
