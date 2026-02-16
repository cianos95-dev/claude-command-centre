#!/usr/bin/env bash
# Circuit Breaker Hook Tests — CIA-389
#
# Tests for hooks/scripts/circuit-breaker-post.sh and circuit-breaker-pre.sh
#
# Run: bash tests/test-circuit-breaker.sh
# Requires: jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
POST_HOOK="$PLUGIN_ROOT/hooks/scripts/circuit-breaker-post.sh"
PRE_HOOK="$PLUGIN_ROOT/hooks/scripts/circuit-breaker-pre.sh"

# Test workspace — isolated from real project
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Initialize a git repo so hooks can find project root
git init "$TEST_DIR" --quiet
export SDD_PROJECT_ROOT="$TEST_DIR"

PASS=0
FAIL=0
TOTAL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

reset_state() {
    rm -f "$TEST_DIR/.ccc-circuit-breaker.json"
    rm -f "$TEST_DIR/.ccc-state.json"
    rm -f "$TEST_DIR/.ccc-preferences.yaml"
}

run_post_hook() {
    local input="$1"
    local exit_code=0
    echo "$input" | bash "$POST_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || exit_code=$?
    echo "$exit_code"
}

run_pre_hook() {
    local input="$1"
    local exit_code=0
    echo "$input" | bash "$PRE_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || exit_code=$?
    echo "$exit_code"
}

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

# JSON helpers for hook input
make_error_input() {
    local tool_name="$1"
    local error_msg="$2"
    jq -n --arg tool "$tool_name" --arg msg "$error_msg" \
        '{tool_name: $tool, tool_result: {is_error: true, content: $msg}}'
}

make_success_input() {
    local tool_name="$1"
    jq -n --arg tool "$tool_name" \
        '{tool_name: $tool, tool_result: {is_error: false, content: "ok"}}'
}

make_pre_input() {
    local tool_name="$1"
    jq -n --arg tool "$tool_name" '{tool_name: $tool}'
}

CB_FILE="$TEST_DIR/.ccc-circuit-breaker.json"

# ===================================================================
echo ""
echo "=== Test Suite: Circuit Breaker Post Hook (Error Detection) ==="
echo ""
# ===================================================================

# --- Test 1: First error creates state file ---
echo "Test 1: First error creates circuit breaker state"
reset_state
EXIT_CODE=$(run_post_hook "$(make_error_input "Write" "Permission denied")")
assert_eq "Exit code 0 (below threshold)" "0" "$EXIT_CODE"
assert_file_exists "State file created" "$CB_FILE"
COUNT=$(jq -r '.consecutiveErrors' "$CB_FILE")
assert_eq "Consecutive errors = 1" "1" "$COUNT"
OPEN=$(jq -r '.open' "$CB_FILE")
assert_eq "Circuit still closed" "false" "$OPEN"

# --- Test 2: Same error increments counter ---
echo ""
echo "Test 2: Same error increments counter"
EXIT_CODE=$(run_post_hook "$(make_error_input "Write" "Permission denied")")
assert_eq "Exit code 0 (still below threshold)" "0" "$EXIT_CODE"
COUNT=$(jq -r '.consecutiveErrors' "$CB_FILE")
assert_eq "Consecutive errors = 2" "2" "$COUNT"

# --- Test 3: Third identical error opens circuit (flat-3 threshold) ---
echo ""
echo "Test 3: Third identical error opens circuit"
EXIT_CODE=$(run_post_hook "$(make_error_input "Write" "Permission denied")")
assert_eq "Exit code 2 (circuit opened)" "2" "$EXIT_CODE"
OPEN=$(jq -r '.open' "$CB_FILE")
assert_eq "Circuit is open" "true" "$OPEN"
COUNT=$(jq -r '.consecutiveErrors' "$CB_FILE")
assert_eq "Consecutive errors = 3" "3" "$COUNT"
STDERR=$(cat "$TEST_DIR/stderr.tmp")
assert_contains "Stderr contains /rewind warning" "/rewind" "$STDERR"
assert_contains "Stderr mentions tool name" "Write" "$STDERR"

# --- Test 4: Different error resets counter ---
echo ""
echo "Test 4: Different error resets counter"
reset_state
run_post_hook "$(make_error_input "Bash" "command not found")" >/dev/null 2>&1
run_post_hook "$(make_error_input "Bash" "syntax error")" >/dev/null 2>&1
COUNT=$(jq -r '.consecutiveErrors' "$CB_FILE")
assert_eq "Counter reset on different error" "1" "$COUNT"

# --- Test 5: Successful tool use resets state (circuit closed) ---
echo ""
echo "Test 5: Success resets state when circuit is closed"
reset_state
run_post_hook "$(make_error_input "Write" "error")" >/dev/null 2>&1
assert_file_exists "State exists after error" "$CB_FILE"
run_post_hook "$(make_success_input "Write")" >/dev/null 2>&1
assert_file_not_exists "State file removed after success" "$CB_FILE"

# --- Test 6: Success does NOT reset open circuit ---
echo ""
echo "Test 6: Success does not reset open circuit"
reset_state
# Manually create an open circuit
jq -n '{open: true, consecutiveErrors: 3, threshold: 3, lastErrorSignature: "test", lastToolName: "Write"}' > "$CB_FILE"
run_post_hook "$(make_success_input "Read")" >/dev/null 2>&1
OPEN=$(jq -r '.open' "$CB_FILE")
assert_eq "Circuit remains open after success" "true" "$OPEN"

# --- Test 7: Exec mode escalation quick→pair ---
echo ""
echo "Test 7: Exec mode auto-escalates quick to pair"
reset_state
# Create a CCC state file with quick mode
jq -n '{executionMode: "quick", phase: "execution"}' > "$TEST_DIR/.ccc-state.json"
run_post_hook "$(make_error_input "Edit" "file not found")" >/dev/null 2>&1
run_post_hook "$(make_error_input "Edit" "file not found")" >/dev/null 2>&1
run_post_hook "$(make_error_input "Edit" "file not found")" >/dev/null 2>&1
ESC_MODE=$(jq -r '.escalatedTo' "$CB_FILE")
assert_eq "Escalated to pair" "pair" "$ESC_MODE"
STATE_MODE=$(jq -r '.executionMode' "$TEST_DIR/.ccc-state.json")
assert_eq "State file updated to pair" "pair" "$STATE_MODE"
STDERR=$(cat "$TEST_DIR/stderr.tmp")
assert_contains "Stderr mentions escalation" "escalated" "$STDERR"

# --- Test 8: Non-quick mode does NOT escalate ---
echo ""
echo "Test 8: Non-quick mode does not escalate"
reset_state
jq -n '{executionMode: "tdd", phase: "execution"}' > "$TEST_DIR/.ccc-state.json"
run_post_hook "$(make_error_input "Bash" "fail")" >/dev/null 2>&1
run_post_hook "$(make_error_input "Bash" "fail")" >/dev/null 2>&1
run_post_hook "$(make_error_input "Bash" "fail")" >/dev/null 2>&1
ESC_MODE=$(jq -r '.escalatedTo' "$CB_FILE")
assert_eq "No escalation for tdd mode" "null" "$ESC_MODE"
STATE_MODE=$(jq -r '.executionMode' "$TEST_DIR/.ccc-state.json")
assert_eq "State file stays tdd" "tdd" "$STATE_MODE"

# --- Test 9: Custom threshold from preferences ---
echo ""
echo "Test 9: Custom threshold from preferences"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
circuit_breaker:
  threshold: 5
EOF
run_post_hook "$(make_error_input "Write" "err")" >/dev/null 2>&1
run_post_hook "$(make_error_input "Write" "err")" >/dev/null 2>&1
run_post_hook "$(make_error_input "Write" "err")" >/dev/null 2>&1
OPEN=$(jq -r '.open' "$CB_FILE")
assert_eq "Circuit still closed at 3 with threshold 5" "false" "$OPEN"
run_post_hook "$(make_error_input "Write" "err")" >/dev/null 2>&1
run_post_hook "$(make_error_input "Write" "err")" >/dev/null 2>&1
OPEN=$(jq -r '.open' "$CB_FILE")
assert_eq "Circuit opens at 5" "true" "$OPEN"

# ===================================================================
echo ""
echo "=== Test Suite: Circuit Breaker Pre Hook (Blocking) ==="
echo ""
# ===================================================================

# --- Test 10: No state file — all tools allowed ---
echo "Test 10: No state file allows all tools"
reset_state
EXIT_CODE=$(run_pre_hook "$(make_pre_input "Write")")
assert_eq "Write allowed without state file" "0" "$EXIT_CODE"

# --- Test 11: Closed circuit — all tools allowed ---
echo ""
echo "Test 11: Closed circuit allows all tools"
reset_state
jq -n '{open: false, consecutiveErrors: 2}' > "$CB_FILE"
EXIT_CODE=$(run_pre_hook "$(make_pre_input "Write")")
assert_eq "Write allowed with closed circuit" "0" "$EXIT_CODE"

# --- Test 12: Open circuit blocks destructive tools ---
echo ""
echo "Test 12: Open circuit blocks destructive tools"
reset_state
jq -n '{open: true, consecutiveErrors: 3, lastToolName: "Write"}' > "$CB_FILE"

for TOOL in Write Edit MultiEdit NotebookEdit Bash; do
    EXIT_CODE=$(run_pre_hook "$(make_pre_input "$TOOL")")
    assert_eq "Blocks $TOOL" "2" "$EXIT_CODE"
done

# --- Test 13: Open circuit allows read-only tools ---
echo ""
echo "Test 13: Open circuit allows read-only tools"
for TOOL in Read Glob Grep; do
    EXIT_CODE=$(run_pre_hook "$(make_pre_input "$TOOL")")
    assert_eq "Allows $TOOL" "0" "$EXIT_CODE"
done

# --- Test 14: Open circuit blocks MCP write tools ---
echo ""
echo "Test 14: Open circuit blocks MCP write tools"
EXIT_CODE=$(run_pre_hook "$(make_pre_input "mcp__github__create_issue")")
assert_eq "Blocks mcp create" "2" "$EXIT_CODE"
EXIT_CODE=$(run_pre_hook "$(make_pre_input "mcp__linear__update_issue")")
assert_eq "Blocks mcp update" "2" "$EXIT_CODE"

# --- Test 15: Deny message includes /rewind recommendation ---
echo ""
echo "Test 15: Block message includes recovery instructions"
reset_state
jq -n '{open: true, consecutiveErrors: 3, lastToolName: "Bash"}' > "$CB_FILE"
run_pre_hook "$(make_pre_input "Write")" >/dev/null 2>&1 || true
STDERR=$(cat "$TEST_DIR/stderr.tmp")
assert_contains "Message includes /rewind" "/rewind" "$STDERR"
assert_contains "Message includes BLOCKED" "BLOCKED" "$STDERR"

# ===================================================================
echo ""
echo "=== Test Suite: Circuit Breaker Reset ==="
echo ""
# ===================================================================

# --- Test 16: Manual deletion resets circuit ---
echo "Test 16: Deleting state file resets circuit"
reset_state
jq -n '{open: true, consecutiveErrors: 3}' > "$CB_FILE"
rm -f "$CB_FILE"
EXIT_CODE=$(run_pre_hook "$(make_pre_input "Write")")
assert_eq "Write allowed after file deletion" "0" "$EXIT_CODE"

# ===================================================================
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
