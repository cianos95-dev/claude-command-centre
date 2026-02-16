---
name: ship-state-verification
description: |
  Pre-publish verification protocol that confirms all claimed artifacts actually exist before shipping. Covers file path verification, skill/command/agent registration, issue-to-artifact reconciliation, marketplace manifest validation, and README accuracy checks. Prevents phantom deliverables from reaching production.
  Use when preparing to publish a README, pushing a release, updating marketplace manifests, marking issues as Done, or verifying that documented counts match actual file counts.
  Trigger with phrases like "verify before shipping", "ship-state check", "do files exist", "verify README claims", "pre-publish check", "manifest validation", "are all skills registered", "phantom deliverable check", "ls-verify".
---

# Ship-State Verification

Ship-state verification is the practice of confirming that every artifact claimed to exist actually exists before publishing, pushing, or releasing. It closes the gap between what documentation says and what the filesystem contains. This gap is invisible during authoring (the author knows what they intended to create) but immediately visible to users who follow the documentation and find missing files.

## Origin

This practice was formalized after the Alteri cleanup (Feb 10 2026) discovered that a published README claimed 11 skills and 8 commands when only 7 and 6 existed. Four Linear issues (CIA-293/294/295/296) were marked Done but their corresponding files had never been created. The root cause was that issue status and documentation were updated before the artifacts were committed. Ship-state verification prevents this class of error.

## Core Principle

**Never trust intent. Verify existence.** A file exists when `ls` confirms it on disk, not when a commit message says it was created, not when an issue is marked Done, and not when a README lists it. The filesystem is the source of truth.

## Verification Checklist

Run this checklist before any publishing action (README push, release tag, marketplace submission, "Done" status on implementation issues). The checklist is ordered by blast radius -- catch the highest-impact discrepancies first.

### 1. File Path Verification

For every file path claimed in documentation, README, or issue closing comments:

```bash
# Verify each claimed path exists
ls -la path/to/claimed/file
```

If the file does not exist, the claim must be removed or the file must be created before publishing. There is no "planned" exception for published documentation -- either the file exists or the claim is removed.

**Common sources of phantom paths:**
- Copy-pasted paths from planning documents that were never implemented
- Paths from a different branch that was not merged
- Paths that existed before a refactor renamed or moved them
- Template paths from skill/command generators that were customized but the originals referenced

### 2. Count Reconciliation

Compare documented counts against actual file counts:

```bash
# Skills
echo "Documented: N skills"
ls skills/*/SKILL.md | wc -l

# Commands
echo "Documented: N commands"
ls commands/*.md | wc -l

# Agents
echo "Documented: N agents"
ls agents/*/agent.md | wc -l
```

Documented counts must exactly match filesystem counts. "Off by one" is not acceptable -- it means either an artifact is missing or the count is inflated.

### 3. Marketplace Manifest Validation

For plugins with `strict: true` in their marketplace manifest, every skill, command, and agent referenced in the manifest must resolve to an existing file.

```bash
# Extract skill paths from marketplace.json and verify each
cat .claude-plugin/marketplace.json | grep -oE '"./skills/[^"]*"' | while read -r path; do
  clean=$(echo "$path" | tr -d '"')
  if [ ! -d "$clean" ] || [ ! -f "$clean/SKILL.md" ]; then
    echo "MISSING: $clean"
  fi
done
```

A manifest entry pointing to a nonexistent skill causes the plugin loader to either fail silently (skill not discovered) or error loudly (strict mode rejection). Both are worse than catching the discrepancy before publishing.

### 4. Issue-to-Artifact Reconciliation

For every issue being marked Done that claims to have produced a file-based deliverable:

1. Read the issue's closing comment or description for claimed deliverables
2. Verify each claimed file exists on the target branch
3. Verify the file has non-trivial content (not an empty placeholder)

**Reconciliation table format:**

```markdown
| Issue | Claimed Artifact | Exists | Non-Empty | Status |
|-------|-----------------|--------|-----------|--------|
| CIA-XXX | skills/foo/SKILL.md | Y | Y | OK |
| CIA-YYY | commands/bar.md | N | — | MISSING |
```

Any row with Status = MISSING blocks the issue from being marked Done. Either create the missing artifact or update the issue scope to reflect what was actually delivered.

### 5. Cross-Reference Validation

Skills, commands, and documentation often reference each other. Verify that cross-references resolve:

- **Cross-Skill References** sections in SKILL.md files reference skills that exist
- **See also** links in commands point to valid skill or reference paths
- **Import paths** in hook files reference existing skill directories
- **README section links** resolve to actual headings

Broken cross-references degrade the user experience -- the reader follows a link to a skill that does not exist and loses trust in the documentation.

## When to Run

Ship-state verification is not continuous. It is a gate check at specific moments:

| Trigger | Scope | Rationale |
|---------|-------|-----------|
| Before pushing README changes | All claims in the changed README | READMEs are the most visible documentation; errors here are seen by every user |
| Before tagging a release | All manifests, all READMEs, all counts | Releases are immutable snapshots; errors cannot be patched without a new release |
| Before marking implementation issues Done | Claimed artifacts for that issue | Done means delivered, not planned |
| After batch skill/command creation | All new entries vs manifest | Batch operations are error-prone; verification catches missed registrations |
| After refactors that move or rename files | All references to moved files | Refactors create stale references at scale |

## Integration with Marketplace Publishing

For CCC plugins distributed via marketplace, ship-state verification is mandatory before version bumps:

1. Run the full checklist above
2. Verify `metadata.version` in `marketplace.json` matches the intended release
3. Confirm all new skills/commands added since the last version are registered in the `skills[]` and `commands[]` arrays
4. Verify the `keywords` array reflects the current skill set (new skills may introduce new keywords)

## Automation Opportunities

Ship-state verification can be partially automated via pre-commit hooks or CI checks:

**Pre-commit hook** (lightweight, catches most issues):
```bash
# Verify marketplace.json skill entries resolve
jq -r '.plugins[0].skills[]' .claude-plugin/marketplace.json | while read -r path; do
  if [ ! -f "$path/SKILL.md" ]; then
    echo "ERROR: Skill path $path/SKILL.md does not exist"
    exit 1
  fi
done
```

**CI check** (comprehensive, runs on PR):
- Parse README for count claims using regex
- Compare against filesystem counts
- Parse marketplace manifest and verify all entries
- Report discrepancies as PR review comments

The manual checklist above remains the source of truth. Automation supplements it but does not replace the full protocol for release-gate verification.

## Relationship to DO NOT #9

This skill expands on DO NOT rule #9 from `project-cleanup/references/do-not-rules.md`. DO NOT #9 captures the anti-pattern ("don't publish README without verification") in 3 lines. This skill provides the complete methodology: what to verify, how to verify it, when to run verification, and how to automate parts of it. The two are complementary -- DO NOT #9 is the rule, this skill is the practice.

## Anti-Patterns

**Post-hoc verification.** Running verification after publishing and treating it as a "fix what we find" exercise. By the time you verify, users have already encountered the missing artifacts. Verify before publishing.

**Count-only checks.** Verifying that the number of skills matches the README count without checking that each specific skill referenced actually exists. A count can match while individual entries are wrong (one extra, one missing).

**Branch confusion.** Verifying artifacts on a feature branch but publishing documentation from main. The verification must run against the same branch that will be published.

**Placeholder acceptance.** Counting empty directories or stub files as "existing." A skill directory with an empty SKILL.md is not a delivered skill. Verify non-trivial content, not just file existence.

**Selective verification.** Only checking the artifacts you just created, not the full manifest. Other artifacts may have been moved, renamed, or deleted by concurrent work. Always verify the complete set.

## Anthropic Ecosystem Alignment

These checks verify CCC aligns with patterns established in the Anthropic knowledge-work-plugins repository (specifically the product-management plugin and PR #55 expanding it). Run these alongside the standard ship-state checklist when preparing releases.

### 6. README Consistency

Command, skill, and agent counts in the README header and tables must match the filesystem exactly.

```bash
# Header count verification
readme_skills_claimed=$(grep -oE '[0-9]+ skills' README.md | head -1 | grep -oE '[0-9]+')
actual_skills=$(find skills -name "SKILL.md" -maxdepth 2 | wc -l | tr -d ' ')
echo "README claims: $readme_skills_claimed skills | Filesystem: $actual_skills skills"

readme_commands_claimed=$(grep -oE '[0-9]+ commands' README.md | head -1 | grep -oE '[0-9]+')
actual_commands=$(ls commands/*.md | wc -l | tr -d ' ')
echo "README claims: $readme_commands_claimed commands | Filesystem: $actual_commands commands"

readme_agents_claimed=$(grep -oE '[0-9]+ agents' README.md | head -1 | grep -oE '[0-9]+')
actual_agents=$(ls agents/*.md | wc -l | tr -d ' ')
echo "README claims: $readme_agents_claimed agents | Filesystem: $actual_agents agents"
```

Additionally, verify that every skill/command/agent on disk appears in the corresponding README table. A file that exists on disk but is absent from the README is undiscoverable to users reading the documentation. The Anthropic pattern in PR #55 requires README tables to be a complete enumeration of filesystem contents, not a curated subset.

**Check for phantom directories** -- skill directories that exist but contain no SKILL.md:

```bash
for d in skills/*/; do
  if [ ! -f "$d/SKILL.md" ]; then
    echo "PHANTOM: $d (directory exists but no SKILL.md)"
  fi
done
```

Phantom directories inflate apparent plugin breadth without delivering content. Delete them or populate them before release.

### 7. Frontmatter Validation

All commands must have `description` and `argument-hint` fields in their YAML frontmatter. All skills must have `name` and `description` fields. This matches the Anthropic pattern where every command carries sufficient metadata for Claude to match it to user intent without reading the full file.

```bash
# Command frontmatter check
for f in commands/*.md; do
  name=$(basename "$f" .md)
  has_desc=$(head -20 "$f" | grep -c "^description:")
  has_hint=$(head -20 "$f" | grep -c "^argument-hint:")
  if [ "$has_desc" -eq 0 ] || [ "$has_hint" -eq 0 ]; then
    echo "FAIL: $name (desc=$has_desc, hint=$has_hint)"
  fi
done

# Skill frontmatter check
for f in skills/*/SKILL.md; do
  name=$(basename $(dirname "$f"))
  has_name=$(head -20 "$f" | grep -c "^name:")
  has_desc=$(head -20 "$f" | grep -c "^description:")
  if [ "$has_name" -eq 0 ] || [ "$has_desc" -eq 0 ]; then
    echo "FAIL: $name (name=$has_name, desc=$has_desc)"
  fi
done
```

CCC also uses a `platforms` field in command frontmatter (`[cli]`, `[cowork]`, `[cli, cowork]`) which the Anthropic pattern does not. This is a CCC extension and is acceptable as long as the base fields are present.

### 8. Skill Depth Threshold

The Anthropic ecosystem targets 8K+ characters per SKILL.md. Skills below this threshold are thin and may not provide enough methodology for Claude to apply them consistently. Measure all skills and flag those below threshold:

```bash
for f in skills/*/SKILL.md; do
  name=$(basename $(dirname "$f"))
  chars=$(wc -c < "$f")
  if [ "$chars" -lt 8000 ]; then
    echo "BELOW 8K: $name ($chars chars)"
  fi
done
```

Skills below 8K should either be expanded with additional methodology, examples, anti-patterns, and checklists, or merged into a related skill if they lack enough standalone substance to justify 8K of content.

**Severity tiers:**
- Below 4K: Critical -- skill is a stub, unlikely to trigger reliably or provide useful guidance
- 4K-6K: Important -- skill covers the topic but lacks depth for consistent application
- 6K-8K: Consider -- skill is functional but would benefit from expansion

## Cross-Skill References

- **project-cleanup** -- DO NOT #9 is the anti-pattern rule; this skill is the full practice
- **session-exit-protocol** -- Session exit closing comments claim deliverables; ship-state verifies them
- **issue-lifecycle** -- Done status requires evidence; ship-state provides the verification methodology
- **execution-engine** -- Task completion claims trigger ship-state checks before status transitions
