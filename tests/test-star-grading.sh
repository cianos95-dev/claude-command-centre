#!/usr/bin/env bash
# Star Grading Tests — CIA-390
#
# Validates that the quality-scoring SKILL.md correctly defines the star grading
# scale, --verbose mode, preference integration, and conversion rules.
#
# Run: bash tests/test-star-grading.sh
# Requires: grep

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$PLUGIN_ROOT/skills/quality-scoring/SKILL.md"
PREFS_FILE="$PLUGIN_ROOT/examples/sample-preferences.yaml"

PASS=0
FAIL=0
TOTAL=0

assert_contains() {
    local test_name="$1"
    local needle="$2"
    local file="$3"
    TOTAL=$((TOTAL + 1))
    if grep -q "$needle" "$file"; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected to find '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local test_name="$1"
    local needle="$2"
    local file="$3"
    TOTAL=$((TOTAL + 1))
    if ! grep -q "$needle" "$file"; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (should NOT contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "=== Test Suite: Star Grading Scale (SKILL.md) ==="
echo ""

# --- Test 1: Star grading scale section exists ---
echo "Test 1: Star grading scale section"
assert_contains "Has Star Grading Scale heading" "## Star Grading Scale" "$SKILL_FILE"

# --- Test 2: All five grade levels defined ---
echo ""
echo "Test 2: All five grade levels"
assert_contains "5-star (Exemplary)" "Exemplary" "$SKILL_FILE"
assert_contains "4-star (Strong)" "Strong" "$SKILL_FILE"
assert_contains "3-star (Acceptable)" "Acceptable" "$SKILL_FILE"
assert_contains "2-star (Needs Work)" "Needs Work" "$SKILL_FILE"
assert_contains "1-star (Inadequate)" "Inadequate" "$SKILL_FILE"

# --- Test 3: Correct range mappings ---
echo ""
echo "Test 3: Range mappings"
assert_contains "90-100 range" "90-100" "$SKILL_FILE"
assert_contains "80-89 range" "80-89" "$SKILL_FILE"
assert_contains "70-79 range" "70-79" "$SKILL_FILE"
assert_contains "60-69 range" "60-69" "$SKILL_FILE"
assert_contains "<60 range" "<60" "$SKILL_FILE"

# --- Test 4: Stars are actual star characters ---
echo ""
echo "Test 4: Star characters present"
assert_contains "Single star" "★" "$SKILL_FILE"
assert_contains "Five stars" "★★★★★" "$SKILL_FILE"

# --- Test 5: --verbose mode documented ---
echo ""
echo "Test 5: Verbose mode"
assert_contains "Verbose flag documented" "\-\-verbose" "$SKILL_FILE"
assert_contains "Verbose shows numeric alongside stars" "85/100" "$SKILL_FILE"
assert_contains "Verbose mode section" "### Verbose mode" "$SKILL_FILE"

# --- Test 6: Default output format uses stars (not numeric) ---
echo ""
echo "Test 6: Default output format"
assert_contains "Default section heading" "### Default (star grading)" "$SKILL_FILE"
assert_contains "Default output has Grade column" "| Grade |" "$SKILL_FILE"

# --- Test 7: Scoring calculation unchanged ---
echo ""
echo "Test 7: Scoring logic preserved"
assert_contains "Formula preserved" "test_score \* 0.40" "$SKILL_FILE"
assert_contains "Coverage weight" "coverage_score \* 0.30" "$SKILL_FILE"
assert_contains "Review weight" "review_score \* 0.30" "$SKILL_FILE"

# --- Test 8: Dimension rubrics unchanged ---
echo ""
echo "Test 8: Dimension rubrics preserved"
assert_contains "Test dimension" "### Test (40%)" "$SKILL_FILE"
assert_contains "Coverage dimension" "### Coverage (30%)" "$SKILL_FILE"
assert_contains "Review dimension" "### Review (30%)" "$SKILL_FILE"

# --- Test 9: Preference config documented ---
echo ""
echo "Test 9: Preference integration"
assert_contains "display_format preference" "display_format" "$SKILL_FILE"
assert_contains "Stars as option" "stars" "$SKILL_FILE"
assert_contains "Letter as option" "letter" "$SKILL_FILE"
assert_contains "Numeric as option" "numeric" "$SKILL_FILE"
assert_contains "Percentage as option" "percentage" "$SKILL_FILE"

# --- Test 10: Conversion rules documented ---
echo ""
echo "Test 10: Conversion rules"
assert_contains "Conversion rules section" "## Star Grading Conversion Rules" "$SKILL_FILE"
assert_contains "Letter grade mapping" "Letter grade mapping" "$SKILL_FILE"

# --- Test 11: Threshold actions use star notation ---
echo ""
echo "Test 11: Threshold actions updated"
assert_contains "Threshold actions include star grades" "★★★★★" "$SKILL_FILE"

# ===================================================================
echo ""
echo "=== Test Suite: Preferences File ==="
echo ""
# ===================================================================

# --- Test 12: scoring.display_format in preferences ---
echo "Test 12: Preferences integration"
assert_contains "scoring section exists" "^scoring:" "$PREFS_FILE"
assert_contains "display_format key" "display_format:" "$PREFS_FILE"
assert_contains "stars as default" "display_format: stars" "$PREFS_FILE"

# --- Test 13: circuit_breaker in preferences ---
echo ""
echo "Test 13: Circuit breaker preferences"
assert_contains "circuit_breaker section" "^circuit_breaker:" "$PREFS_FILE"
assert_contains "threshold key" "threshold:" "$PREFS_FILE"

# ===================================================================
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
