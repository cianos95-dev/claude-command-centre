#!/usr/bin/env bash
# Static Quality Checks — CIA-519
#
# CI-runnable bash script that validates CCC plugin structural integrity.
# No Claude Code dependency. Extracts checks from /ccc:self-test into standalone form.
#
# Tier A of the CCC-native eval pipeline (replaces cc-plugin-eval Stage 1).
#
# Run: bash tests/test-static-quality.sh
# Requires: python3 (for JSON/YAML parsing)
#
# Exit codes: 0 = all checks pass, 1 = one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/marketplace.json"
README="$PLUGIN_ROOT/README.md"

PASS=0
FAIL=0
WARN=0
TOTAL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

pass() {
    local test_name="$1"
    TOTAL=$((TOTAL + 1))
    PASS=$((PASS + 1))
    echo "  PASS: $test_name"
}

fail() {
    local test_name="$1"
    local detail="${2:-}"
    TOTAL=$((TOTAL + 1))
    FAIL=$((FAIL + 1))
    if [[ -n "$detail" ]]; then
        echo "  FAIL: $test_name ($detail)"
    else
        echo "  FAIL: $test_name"
    fi
}

warn() {
    local test_name="$1"
    local detail="${2:-}"
    WARN=$((WARN + 1))
    if [[ -n "$detail" ]]; then
        echo "  WARN: $test_name ($detail)"
    else
        echo "  WARN: $test_name"
    fi
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

if [[ ! -f "$MANIFEST" ]]; then
    echo "ERROR: Manifest not found at $MANIFEST"
    echo "Are you running from the plugin root directory?"
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required for JSON/YAML parsing"
    exit 1
fi

# ===================================================================
echo ""
echo "=== Check 1: Manifest-Filesystem Alignment ==="
echo ""
echo "Every path in marketplace.json must exist on disk."
echo ""
# ===================================================================

# Extract command paths from manifest
MANIFEST_COMMANDS=$(python3 -c "
import json, sys
d = json.load(open('$MANIFEST'))
for c in d['plugins'][0].get('commands', []):
    print(c)
")

MANIFEST_SKILLS=$(python3 -c "
import json, sys
d = json.load(open('$MANIFEST'))
for s in d['plugins'][0].get('skills', []):
    print(s)
")

# Check commands exist
CHECK1_OK=true
while IFS= read -r cmd_path; do
    [[ -z "$cmd_path" ]] && continue
    # Resolve relative path from plugin source root
    # Manifest paths use ./ prefix relative to plugin source (which is ./ = plugin root)
    resolved="$PLUGIN_ROOT/${cmd_path#./}"
    if [[ -f "$resolved" ]]; then
        pass "Command exists: $cmd_path"
    else
        fail "Command missing: $cmd_path" "expected at $resolved"
        CHECK1_OK=false
    fi
done <<< "$MANIFEST_COMMANDS"

# Check skills exist (each skill path should contain SKILL.md)
while IFS= read -r skill_path; do
    [[ -z "$skill_path" ]] && continue
    resolved="$PLUGIN_ROOT/${skill_path#./}/SKILL.md"
    if [[ -f "$resolved" ]]; then
        pass "Skill exists: $skill_path"
    else
        fail "Skill missing: $skill_path" "expected SKILL.md at $resolved"
        CHECK1_OK=false
    fi
done <<< "$MANIFEST_SKILLS"

# Check agents exist (agents are listed in manifest under agents[])
MANIFEST_AGENTS=$(python3 -c "
import json, sys
d = json.load(open('$MANIFEST'))
for a in d['plugins'][0].get('agents', []):
    print(a)
")

while IFS= read -r agent_path; do
    [[ -z "$agent_path" ]] && continue
    resolved="$PLUGIN_ROOT/${agent_path#./}"
    if [[ -f "$resolved" ]]; then
        pass "Agent exists: $agent_path"
    else
        fail "Agent missing: $agent_path" "expected at $resolved"
        CHECK1_OK=false
    fi
done <<< "$MANIFEST_AGENTS"

if $CHECK1_OK; then
    echo ""
    echo "  Check 1 PASSED: All manifest paths exist on disk"
fi

# ===================================================================
echo ""
echo "=== Check 2: Frontmatter Validation ==="
echo ""
echo "All SKILL.md and command .md files must have valid YAML frontmatter."
echo ""
# ===================================================================

CHECK2_OK=true

# Validate frontmatter for a given file
# Returns 0 if valid, 1 if invalid
validate_frontmatter() {
    local file="$1"
    local component_type="$2"

    # Check file starts with ---
    if ! head -1 "$file" | grep -q '^---'; then
        fail "Frontmatter missing: $file" "file does not start with ---"
        return 1
    fi

    # Extract frontmatter and validate as YAML
    local fm_valid
    fm_valid=$(python3 -c "
import sys
try:
    with open('$file') as f:
        content = f.read()
    if not content.startswith('---'):
        print('NO_FRONTMATTER')
        sys.exit(0)
    # Find closing ---
    end = content.index('---', 3)
    yaml_text = content[3:end].strip()
    # Try to parse as YAML
    import importlib
    try:
        yaml = importlib.import_module('yaml')
        data = yaml.safe_load(yaml_text)
        if not isinstance(data, dict):
            print('NOT_DICT')
            sys.exit(0)
        # Check required fields based on component type
        if '$component_type' == 'skill' or '$component_type' == 'agent':
            if not data.get('name'):
                print('MISSING_NAME')
                sys.exit(0)
            if not data.get('description'):
                print('MISSING_DESCRIPTION')
                sys.exit(0)
        elif '$component_type' == 'command':
            if not data.get('description'):
                print('MISSING_DESCRIPTION')
                sys.exit(0)
        print('OK')
    except ImportError:
        # Fallback: basic key-value check without yaml module
        has_name = any(line.strip().startswith('name:') for line in yaml_text.split('\n'))
        has_desc = any(line.strip().startswith('description:') for line in yaml_text.split('\n'))
        if '$component_type' in ('skill', 'agent'):
            if not has_name:
                print('MISSING_NAME')
                sys.exit(0)
            if not has_desc:
                print('MISSING_DESCRIPTION')
                sys.exit(0)
        elif '$component_type' == 'command':
            if not has_desc:
                print('MISSING_DESCRIPTION')
                sys.exit(0)
        print('OK')
except ValueError:
    print('NO_CLOSING_DELIMITER')
except Exception as e:
    print(f'ERROR:{e}')
" 2>&1)

    case "$fm_valid" in
        OK)
            pass "Valid frontmatter: $(basename "$(dirname "$file")")/$(basename "$file")"
            return 0
            ;;
        NO_FRONTMATTER)
            fail "No frontmatter: $file"
            return 1
            ;;
        NO_CLOSING_DELIMITER)
            fail "Frontmatter not closed: $file" "missing closing ---"
            return 1
            ;;
        NOT_DICT)
            fail "Frontmatter not a mapping: $file"
            return 1
            ;;
        MISSING_NAME)
            fail "Frontmatter missing 'name': $file"
            return 1
            ;;
        MISSING_DESCRIPTION)
            fail "Frontmatter missing 'description': $file"
            return 1
            ;;
        *)
            fail "Frontmatter error: $file" "$fm_valid"
            return 1
            ;;
    esac
}

# Validate all command frontmatter
while IFS= read -r cmd_path; do
    [[ -z "$cmd_path" ]] && continue
    resolved="$PLUGIN_ROOT/${cmd_path#./}"
    [[ -f "$resolved" ]] || continue
    if ! validate_frontmatter "$resolved" "command"; then
        CHECK2_OK=false
    fi
done <<< "$MANIFEST_COMMANDS"

# Validate all skill frontmatter
while IFS= read -r skill_path; do
    [[ -z "$skill_path" ]] && continue
    resolved="$PLUGIN_ROOT/${skill_path#./}/SKILL.md"
    [[ -f "$resolved" ]] || continue
    if ! validate_frontmatter "$resolved" "skill"; then
        CHECK2_OK=false
    fi
done <<< "$MANIFEST_SKILLS"

# Validate all agent frontmatter
while IFS= read -r agent_path; do
    [[ -z "$agent_path" ]] && continue
    resolved="$PLUGIN_ROOT/${agent_path#./}"
    [[ -f "$resolved" ]] || continue
    if ! validate_frontmatter "$resolved" "agent"; then
        CHECK2_OK=false
    fi
done <<< "$MANIFEST_AGENTS"

if $CHECK2_OK; then
    echo ""
    echo "  Check 2 PASSED: All frontmatter is valid"
fi

# ===================================================================
echo ""
echo "=== Check 3: Skill Depth Threshold ==="
echo ""
echo "Skills below 8K characters may lack sufficient depth."
echo ""
# ===================================================================

THRESHOLD=8192

while IFS= read -r skill_path; do
    [[ -z "$skill_path" ]] && continue
    resolved="$PLUGIN_ROOT/${skill_path#./}/SKILL.md"
    [[ -f "$resolved" ]] || continue

    char_count=$(wc -c < "$resolved" | tr -d ' ')
    skill_name=$(basename "$skill_path")

    if [[ "$char_count" -ge "$THRESHOLD" ]]; then
        pass "Skill depth OK: $skill_name (${char_count} chars)"
    else
        warn "Skill below threshold: $skill_name" "${char_count} chars < ${THRESHOLD} threshold"
    fi
done <<< "$MANIFEST_SKILLS"

echo ""
echo "  Check 3 PASSED: Depth threshold checked (warnings are advisory, not failures)"

# ===================================================================
echo ""
echo "=== Check 4: Cross-Reference Validation ==="
echo ""
echo "Skills referencing other skills must point to valid names."
echo ""
# ===================================================================

CHECK4_OK=true

# Build list of valid skill names (directory names under skills/)
VALID_SKILLS=()
while IFS= read -r skill_path; do
    [[ -z "$skill_path" ]] && continue
    VALID_SKILLS+=("$(basename "$skill_path")")
done <<< "$MANIFEST_SKILLS"

# Build list of valid command names (filename without .md, prefixed with /ccc:)
VALID_COMMANDS=()
while IFS= read -r cmd_path; do
    [[ -z "$cmd_path" ]] && continue
    cmd_name=$(basename "$cmd_path" .md)
    VALID_COMMANDS+=("$cmd_name")
done <<< "$MANIFEST_COMMANDS"

# Check each skill for references to other skills
# Uses python3 for reliable regex extraction (avoids bash/grep portability issues)
while IFS= read -r skill_path; do
    [[ -z "$skill_path" ]] && continue
    resolved="$PLUGIN_ROOT/${skill_path#./}/SKILL.md"
    [[ -f "$resolved" ]] || continue
    skill_name=$(basename "$skill_path")

    # Extract skill cross-references using python for reliable regex
    # Matches: `skill-name` skill, **skill-name** skill, See the `skill-name`
    refs=$(python3 -c "
import re
with open('$resolved') as f:
    text = f.read()
# Pattern: backtick-quoted name (3+ chars with hyphens) followed by 'skill'
for m in re.finditer(r'\x60([a-z][a-z-]{2,})\x60\s+skill', text):
    print(m.group(1))
# Pattern: bold name followed by 'skill'
for m in re.finditer(r'\*\*([a-z][a-z-]{2,})\*\*\s+skill', text):
    print(m.group(1))
" 2>/dev/null || true)

    # Deduplicate refs for this skill
    seen_refs=""
    while IFS= read -r ref_name; do
        [[ -z "$ref_name" ]] && continue
        # Skip self-references
        [[ "$ref_name" == "$skill_name" ]] && continue
        # Skip if already seen in this skill
        echo "$seen_refs" | grep -qx "$ref_name" && continue
        seen_refs="$seen_refs
$ref_name"

        # Check if it's a valid skill name
        found=false
        for vs in "${VALID_SKILLS[@]}"; do
            if [[ "$vs" == "$ref_name" ]]; then
                found=true
                break
            fi
        done

        if $found; then
            pass "Cross-ref valid: $skill_name → $ref_name"
        else
            fail "Cross-ref broken: $skill_name → $ref_name" "no skill named '$ref_name' in manifest"
            CHECK4_OK=false
        fi
    done <<< "$refs"
done <<< "$MANIFEST_SKILLS"

if $CHECK4_OK; then
    echo ""
    echo "  Check 4 PASSED: All cross-references point to valid skills"
fi

# ===================================================================
echo ""
echo "=== Check 5: README Component Count Reconciliation ==="
echo ""
echo "Counts in README must match actual component counts."
echo ""
# ===================================================================

CHECK5_OK=true

# Extract counts from README
# Look for pattern like "N skills, N commands, N agents"
README_COUNTS=$(python3 -c "
import re
with open('$README') as f:
    text = f.read()
# Match pattern: **N skills, N commands, N agents, N hooks**
m = re.search(r'\*\*(\d+)\s+skills?,\s+(\d+)\s+commands?,\s+(\d+)\s+agents?,\s+(\d+)\s+hooks?\*\*', text)
if m:
    print(f'{m.group(1)} {m.group(2)} {m.group(3)} {m.group(4)}')
else:
    # Try without bold
    m = re.search(r'(\d+)\s+skills?,\s+(\d+)\s+commands?,\s+(\d+)\s+agents?,\s+(\d+)\s+hooks?', text)
    if m:
        print(f'{m.group(1)} {m.group(2)} {m.group(3)} {m.group(4)}')
    else:
        print('NOT_FOUND')
" 2>&1)

if [[ "$README_COUNTS" == "NOT_FOUND" ]]; then
    fail "README count pattern not found" "expected 'N skills, N commands, N agents, N hooks'"
    CHECK5_OK=false
else
    read -r README_SKILLS README_COMMANDS README_AGENTS README_HOOKS <<< "$README_COUNTS"

    # Actual counts
    ACTUAL_SKILLS=$(echo "$MANIFEST_SKILLS" | grep -c '.' || echo 0)
    ACTUAL_COMMANDS=$(echo "$MANIFEST_COMMANDS" | grep -c '.' || echo 0)
    ACTUAL_AGENTS=$(echo "$MANIFEST_AGENTS" | grep -c '.' || echo 0)
    ACTUAL_HOOKS=$(find "$PLUGIN_ROOT/hooks/scripts" -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$README_SKILLS" -eq "$ACTUAL_SKILLS" ]]; then
        pass "Skill count matches: README=$README_SKILLS, actual=$ACTUAL_SKILLS"
    else
        fail "Skill count mismatch" "README=$README_SKILLS, manifest=$ACTUAL_SKILLS"
        CHECK5_OK=false
    fi

    if [[ "$README_COMMANDS" -eq "$ACTUAL_COMMANDS" ]]; then
        pass "Command count matches: README=$README_COMMANDS, actual=$ACTUAL_COMMANDS"
    else
        fail "Command count mismatch" "README=$README_COMMANDS, manifest=$ACTUAL_COMMANDS"
        CHECK5_OK=false
    fi

    if [[ "$README_AGENTS" -eq "$ACTUAL_AGENTS" ]]; then
        pass "Agent count matches: README=$README_AGENTS, actual=$ACTUAL_AGENTS"
    else
        fail "Agent count mismatch" "README=$README_AGENTS, manifest=$ACTUAL_AGENTS"
        CHECK5_OK=false
    fi

    if [[ "$README_HOOKS" -eq "$ACTUAL_HOOKS" ]]; then
        pass "Hook count matches: README=$README_HOOKS, actual=$ACTUAL_HOOKS"
    else
        fail "Hook count mismatch" "README=$README_HOOKS, actual=$ACTUAL_HOOKS"
        CHECK5_OK=false
    fi
fi

if $CHECK5_OK; then
    echo ""
    echo "  Check 5 PASSED: README counts match actual counts"
fi

# ===================================================================
echo ""
echo "=== Check 6: Orphan Detection ==="
echo ""
echo "Files on disk but not in manifest."
echo ""
# ===================================================================

CHECK6_OK=true

# Build newline-separated lists of manifest paths (normalized, no ./ prefix)
# Using lists + grep instead of associative arrays for bash 3 compatibility
MANIFEST_CMD_LIST=""
while IFS= read -r cmd_path; do
    [[ -z "$cmd_path" ]] && continue
    MANIFEST_CMD_LIST="$MANIFEST_CMD_LIST
${cmd_path#./}"
done <<< "$MANIFEST_COMMANDS"

MANIFEST_SKILL_LIST=""
while IFS= read -r skill_path; do
    [[ -z "$skill_path" ]] && continue
    MANIFEST_SKILL_LIST="$MANIFEST_SKILL_LIST
${skill_path#./}"
done <<< "$MANIFEST_SKILLS"

MANIFEST_AGENT_LIST=""
while IFS= read -r agent_path; do
    [[ -z "$agent_path" ]] && continue
    MANIFEST_AGENT_LIST="$MANIFEST_AGENT_LIST
${agent_path#./}"
done <<< "$MANIFEST_AGENTS"

# Helper: check if a value is in a newline-separated list
in_list() {
    local needle="$1"
    local haystack="$2"
    echo "$haystack" | grep -qxF "$needle"
}

# Check for orphaned commands (on disk but not in manifest)
for cmd_file in "$PLUGIN_ROOT"/commands/*.md; do
    [[ -f "$cmd_file" ]] || continue
    relative="commands/$(basename "$cmd_file")"
    if ! in_list "$relative" "$MANIFEST_CMD_LIST"; then
        fail "Orphaned command: $relative" "exists on disk but not in manifest"
        CHECK6_OK=false
    fi
done

# Check for orphaned skills (on disk but not in manifest)
for skill_dir in "$PLUGIN_ROOT"/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    skill_name=$(basename "$skill_dir")
    relative="skills/$skill_name"
    if ! in_list "$relative" "$MANIFEST_SKILL_LIST"; then
        fail "Orphaned skill: $relative" "exists on disk but not in manifest"
        CHECK6_OK=false
    fi
done

# Check for orphaned agents (on disk but not in manifest)
for agent_file in "$PLUGIN_ROOT"/agents/*.md; do
    [[ -f "$agent_file" ]] || continue
    relative="agents/$(basename "$agent_file")"
    if ! in_list "$relative" "$MANIFEST_AGENT_LIST"; then
        fail "Orphaned agent: $relative" "exists on disk but not in manifest"
        CHECK6_OK=false
    fi
done

if $CHECK6_OK; then
    echo ""
    echo "  Check 6 PASSED: No orphaned components found"
fi

# ===================================================================
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "FAILED: $FAIL check(s) did not pass."
    exit 1
else
    echo "ALL CHECKS PASSED."
    exit 0
fi
