#!/usr/bin/env bash
# Spec Conformance Hook Tests — CIA-396
#
# Tests for hooks/scripts/conformance-*.sh
#
# Run: bash tests/test-conformance-hooks.sh
# Requires: jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_HOOK="$PLUGIN_ROOT/hooks/scripts/conformance-cache.sh"
LOG_HOOK="$PLUGIN_ROOT/hooks/scripts/conformance-log.sh"
CHECK_HOOK="$PLUGIN_ROOT/hooks/scripts/conformance-check.sh"

# Test workspace
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0
TOTAL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected '$expected', got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected to contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_exists() {
    local test_name="$1"
    local file="$2"
    TOTAL=$((TOTAL + 1))
    if [[ -f "$file" ]]; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (file '$file' does not exist)"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_not_exists() {
    local test_name="$1"
    local file="$2"
    TOTAL=$((TOTAL + 1))
    if [[ ! -f "$file" ]]; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (file '$file' should not exist)"
        FAIL=$((FAIL + 1))
    fi
}

assert_json_eq() {
    local test_name="$1"
    local jq_query="$2"
    local expected="$3"
    local json_file="$4"
    TOTAL=$((TOTAL + 1))
    local actual
    actual=$(jq -r "$jq_query" "$json_file" 2>/dev/null || echo "JQ_ERROR")
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected '$expected', got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

reset_state() {
    rm -f "$TEST_DIR/.ccc-conformance-cache.json"
    rm -f "$TEST_DIR/.ccc-conformance-queue.jsonl"
    rm -f "$TEST_DIR/.ccc-conformance-report.json"
    rm -f "$TEST_DIR/spec.md"
}

CACHE_FILE="$TEST_DIR/.ccc-conformance-cache.json"
QUEUE_FILE="$TEST_DIR/.ccc-conformance-queue.jsonl"
REPORT_FILE="$TEST_DIR/.ccc-conformance-report.json"

# Create a test spec
create_test_spec() {
    cat > "$TEST_DIR/spec.md" << 'EOF'
## Acceptance Criteria

- [ ] patterns.json schema defined per above (with schema_version: 1)
- [ ] Script performs idempotent full rebuild from all archives
- [ ] Friction types normalized via case-insensitive canonical matching
- [ ] Triage auto-creation fires at count >= 3 with deduplication
- [x] This one is already done and should be skipped
EOF
}

# ===================================================================
echo ""
echo "=== Test Suite: SessionStart Cache Hook ==="
echo ""
# ===================================================================

# --- Test 1: Cache created from valid spec ---
echo "Test 1: Cache created from valid spec"
reset_state
create_test_spec
EXIT_CODE=0
CCC_PROJECT_ROOT="$TEST_DIR" CCC_SPEC_PATH="$TEST_DIR/spec.md" \
    bash "$CACHE_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || EXIT_CODE=$?
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_file_exists "Cache file created" "$CACHE_FILE"
assert_json_eq "spec_path set" ".spec_path" "$TEST_DIR/spec.md" "$CACHE_FILE"
assert_json_eq "4 criteria extracted" ".criteria | length" "4" "$CACHE_FILE"

# --- Test 2: Only unchecked criteria extracted ---
echo ""
echo "Test 2: Only unchecked criteria extracted (checked ones skipped)"
assert_json_eq "No 'already done' criterion" '.criteria | map(select(.raw | test("already done"))) | length' "0" "$CACHE_FILE"

# --- Test 3: Keywords extracted correctly ---
echo ""
echo "Test 3: Keywords extracted with stop word removal"
# AC-1: "patterns.json schema defined per above (with schema_version: 1)"
# After stop word removal (the, a, an, is, are, to, from, with, for, in, on, of, and, or)
# and >= 4 chars: patterns.json, schema, defined, above, schema_version
AC1_KEYWORDS=$(jq -r '.criteria[0].keywords | join(",")' "$CACHE_FILE")
assert_contains "Keywords include 'patterns.json'" "patterns.json" "$AC1_KEYWORDS"
assert_contains "Keywords include 'schema'" "schema" "$AC1_KEYWORDS"
assert_contains "Keywords include 'defined'" "defined" "$AC1_KEYWORDS"

# --- Test 4: Spec hash computed ---
echo ""
echo "Test 4: Spec hash computed"
HASH=$(jq -r '.spec_hash' "$CACHE_FILE")
TOTAL=$((TOTAL + 1))
if [[ "$HASH" =~ ^sha256: ]]; then
    echo "  PASS: spec_hash has sha256 prefix"
    PASS=$((PASS + 1))
else
    echo "  FAIL: spec_hash missing sha256 prefix (got '$HASH')"
    FAIL=$((FAIL + 1))
fi

# --- Test 5: Fail-open when CCC_SPEC_PATH unset ---
echo ""
echo "Test 5: Fail-open when CCC_SPEC_PATH unset"
reset_state
EXIT_CODE=0
CCC_PROJECT_ROOT="$TEST_DIR" \
    bash "$CACHE_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || EXIT_CODE=$?
assert_eq "Exit code 0 (fail-open)" "0" "$EXIT_CODE"
assert_file_not_exists "No cache created" "$CACHE_FILE"

# --- Test 6: Fail-open when spec file missing ---
echo ""
echo "Test 6: Fail-open when spec file does not exist"
reset_state
EXIT_CODE=0
CCC_PROJECT_ROOT="$TEST_DIR" CCC_SPEC_PATH="$TEST_DIR/nonexistent.md" \
    bash "$CACHE_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || EXIT_CODE=$?
assert_eq "Exit code 0 (fail-open)" "0" "$EXIT_CODE"
assert_file_not_exists "No cache created" "$CACHE_FILE"

# ===================================================================
echo ""
echo "=== Test Suite: PostToolUse Log Hook ==="
echo ""
# ===================================================================

# --- Test 7: Write logged to queue ---
echo "Test 7: Write logged to queue when cache exists"
reset_state
create_test_spec
CCC_PROJECT_ROOT="$TEST_DIR" CCC_SPEC_PATH="$TEST_DIR/spec.md" \
    bash "$CACHE_HOOK" >/dev/null 2>&1
# Now simulate a PostToolUse
EXIT_CODE=0
echo '{"tool_name":"Edit","tool_input":{"file_path":"/path/to/file.ts","old_string":"foo","new_string":"bar"},"tool_result":{"content":"ok","is_error":false}}' | \
    CCC_PROJECT_ROOT="$TEST_DIR" bash "$LOG_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || EXIT_CODE=$?
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_file_exists "Queue file created" "$QUEUE_FILE"
LINE_COUNT=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
assert_eq "1 entry in queue" "1" "$LINE_COUNT"

# --- Test 8: Multiple writes append to queue ---
echo ""
echo "Test 8: Multiple writes append to queue"
echo '{"tool_name":"Write","tool_input":{"file_path":"/path/to/other.ts"},"tool_result":{"content":"ok","is_error":false}}' | \
    CCC_PROJECT_ROOT="$TEST_DIR" bash "$LOG_HOOK" >/dev/null 2>&1
LINE_COUNT=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
assert_eq "2 entries in queue" "2" "$LINE_COUNT"

# --- Test 9: File path captured in queue entry ---
echo ""
echo "Test 9: File path captured in queue entry"
FIRST_FILE=$(head -1 "$QUEUE_FILE" | jq -r '.file')
assert_eq "File path captured" "/path/to/file.ts" "$FIRST_FILE"

# --- Test 10: Tool name captured ---
echo ""
echo "Test 10: Tool name captured in queue entry"
FIRST_TOOL=$(head -1 "$QUEUE_FILE" | jq -r '.tool')
assert_eq "Tool name captured" "Edit" "$FIRST_TOOL"

# --- Test 11: Fail-open when no cache ---
echo ""
echo "Test 11: Fail-open when no cache exists"
reset_state
EXIT_CODE=0
echo '{"tool_name":"Write","tool_input":{"file_path":"/test"},"tool_result":{"content":"ok","is_error":false}}' | \
    CCC_PROJECT_ROOT="$TEST_DIR" bash "$LOG_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || EXIT_CODE=$?
assert_eq "Exit code 0 (fail-open)" "0" "$EXIT_CODE"
assert_file_not_exists "No queue created without cache" "$QUEUE_FILE"

# ===================================================================
echo ""
echo "=== Test Suite: Stop Conformance Check Hook ==="
echo ""
# ===================================================================

# --- Test 12: Conformance report produced ---
echo "Test 12: Conformance report produced"
reset_state
create_test_spec
# Setup: cache + queue
CCC_PROJECT_ROOT="$TEST_DIR" CCC_SPEC_PATH="$TEST_DIR/spec.md" \
    bash "$CACHE_HOOK" >/dev/null 2>&1
# Log writes that relate to spec (patterns.json, schema, etc.)
echo '{"tool_name":"Write","tool_input":{"file_path":"/project/patterns.json"},"tool_result":{"content":"ok","is_error":false}}' | \
    CCC_PROJECT_ROOT="$TEST_DIR" bash "$LOG_HOOK" >/dev/null 2>&1
echo '{"tool_name":"Edit","tool_input":{"file_path":"/project/schema/types.ts"},"tool_result":{"content":"ok","is_error":false}}' | \
    CCC_PROJECT_ROOT="$TEST_DIR" bash "$LOG_HOOK" >/dev/null 2>&1
# Log a drifting write (no keyword overlap)
echo '{"tool_name":"Write","tool_input":{"file_path":"/project/readme-unrelated.txt"},"tool_result":{"content":"ok","is_error":false}}' | \
    CCC_PROJECT_ROOT="$TEST_DIR" bash "$LOG_HOOK" >/dev/null 2>&1

EXIT_CODE=0
echo '{}' | CCC_PROJECT_ROOT="$TEST_DIR" bash "$CHECK_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || EXIT_CODE=$?
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_file_exists "Report created" "$REPORT_FILE"
assert_json_eq "total_writes is 3" ".total_writes" "3" "$REPORT_FILE"

# --- Test 13: Drifting writes detected ---
echo ""
echo "Test 13: Drifting writes detected"
DRIFTING=$(jq -r '.potentially_drifting' "$REPORT_FILE")
TOTAL=$((TOTAL + 1))
if [[ "$DRIFTING" -ge 1 ]]; then
    echo "  PASS: At least 1 drifting write detected"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Expected at least 1 drifting write (got $DRIFTING)"
    FAIL=$((FAIL + 1))
fi

# --- Test 14: Coverage tracking ---
echo ""
echo "Test 14: AC coverage tracked"
COVERAGE_KEYS=$(jq '.coverage | keys | length' "$REPORT_FILE")
assert_eq "Coverage has entries for each AC" "4" "$COVERAGE_KEYS"

# --- Test 15: Cleanup after check ---
echo ""
echo "Test 15: Queue and cache cleaned up after check"
assert_file_not_exists "Queue cleaned up" "$QUEUE_FILE"
assert_file_not_exists "Cache cleaned up" "$CACHE_FILE"

# --- Test 16: Fail-open when no queue ---
echo ""
echo "Test 16: Fail-open when no queue exists"
reset_state
EXIT_CODE=0
echo '{}' | CCC_PROJECT_ROOT="$TEST_DIR" bash "$CHECK_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || EXIT_CODE=$?
assert_eq "Exit code 0 (no queue)" "0" "$EXIT_CODE"

# ===================================================================
echo ""
echo "=== Test Suite: Suppression Mechanism ==="
echo ""
# ===================================================================

# --- Test 17: ccc:suppress prevents drift flagging ---
echo "Test 17: ccc:suppress comment prevents drift flagging"
reset_state
create_test_spec
CCC_PROJECT_ROOT="$TEST_DIR" CCC_SPEC_PATH="$TEST_DIR/spec.md" \
    bash "$CACHE_HOOK" >/dev/null 2>&1

# Create a source file with suppression comment
mkdir -p "$TEST_DIR/src"
cat > "$TEST_DIR/src/unrelated.ts" << 'SRCEOF'
// ccc:suppress AC-1
export function helper() { return true; }
SRCEOF

# Log a write to that file
echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TEST_DIR/src/unrelated.ts\"},\"tool_result\":{\"content\":\"ok\",\"is_error\":false}}" | \
    CCC_PROJECT_ROOT="$TEST_DIR" bash "$LOG_HOOK" >/dev/null 2>&1

echo '{}' | CCC_PROJECT_ROOT="$TEST_DIR" bash "$CHECK_HOOK" >/dev/null 2>&1

if [[ -f "$REPORT_FILE" ]]; then
    SUPPRESSED=$(jq -r '.suppressed // 0' "$REPORT_FILE")
    TOTAL=$((TOTAL + 1))
    if [[ "$SUPPRESSED" -ge 1 ]]; then
        echo "  PASS: Suppressed write tracked"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: Expected suppressed >= 1 (got $SUPPRESSED)"
        FAIL=$((FAIL + 1))
    fi
else
    TOTAL=$((TOTAL + 1))
    echo "  FAIL: No report generated for suppression test"
    FAIL=$((FAIL + 1))
fi

# ===================================================================
echo ""
echo "=== Test Suite: Keyword Matching ==="
echo ""
# ===================================================================

# --- Test 18: 50% keyword overlap threshold ---
echo "Test 18: Write matching >= 50% keywords is conforming"
reset_state
# Spec with one AC that has 4 keywords after stop word removal:
# "Build pattern script" → keywords: build, pattern, script (3 keywords, "the" is stop word)
# Actually: "Update the pattern script" → keywords: update, pattern, script
cat > "$TEST_DIR/spec.md" << 'EOF'
## Acceptance Criteria

- [ ] Update the pattern script
EOF
CCC_PROJECT_ROOT="$TEST_DIR" CCC_SPEC_PATH="$TEST_DIR/spec.md" \
    bash "$CACHE_HOOK" >/dev/null 2>&1

# Write to a file whose path contains 2 of 3 keywords (67%): "pattern" and "script"
echo '{"tool_name":"Write","tool_input":{"file_path":"/project/pattern/script.sh"},"tool_result":{"content":"ok","is_error":false}}' | \
    CCC_PROJECT_ROOT="$TEST_DIR" bash "$LOG_HOOK" >/dev/null 2>&1

echo '{}' | CCC_PROJECT_ROOT="$TEST_DIR" bash "$CHECK_HOOK" >/dev/null 2>&1

if [[ -f "$REPORT_FILE" ]]; then
    CONFORMING=$(jq -r '.conforming_writes' "$REPORT_FILE")
    assert_eq "Write is conforming (50% match)" "1" "$CONFORMING"
else
    TOTAL=$((TOTAL + 1))
    echo "  FAIL: No report generated"
    FAIL=$((FAIL + 1))
fi

# --- Test 19: Write below threshold is drifting ---
echo ""
echo "Test 19: Write matching < 50% keywords is drifting"
reset_state
cat > "$TEST_DIR/spec.md" << 'EOF'
## Acceptance Criteria

- [ ] Build the pattern aggregation script with normalization and validation
EOF
CCC_PROJECT_ROOT="$TEST_DIR" CCC_SPEC_PATH="$TEST_DIR/spec.md" \
    bash "$CACHE_HOOK" >/dev/null 2>&1

# Write to a file with only 1 keyword match out of 5+ (pattern)
echo '{"tool_name":"Write","tool_input":{"file_path":"/project/readme.md"},"tool_result":{"content":"ok","is_error":false}}' | \
    CCC_PROJECT_ROOT="$TEST_DIR" bash "$LOG_HOOK" >/dev/null 2>&1

echo '{}' | CCC_PROJECT_ROOT="$TEST_DIR" bash "$CHECK_HOOK" >/dev/null 2>&1

if [[ -f "$REPORT_FILE" ]]; then
    DRIFTING=$(jq -r '.potentially_drifting' "$REPORT_FILE")
    assert_eq "Write is drifting (< 50% match)" "1" "$DRIFTING"
else
    TOTAL=$((TOTAL + 1))
    echo "  FAIL: No report generated"
    FAIL=$((FAIL + 1))
fi

# ===================================================================
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
