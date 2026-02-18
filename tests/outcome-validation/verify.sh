#!/bin/bash
# Outcome Validation Skill — Verification Script
# Run from repo root: bash tests/outcome-validation/verify.sh

PASS=0
FAIL=0

check() {
  local desc="$1"
  local condition="$2"
  if eval "$condition"; then
    echo "PASS: $desc"
    ((PASS++))
  else
    echo "FAIL: $desc"
    ((FAIL++))
  fi
}

# I3: Skill file exists
check "SKILL.md exists" "[ -f skills/outcome-validation/SKILL.md ]"

# I3: Skill has valid frontmatter
check "SKILL.md has name field" "head -20 skills/outcome-validation/SKILL.md 2>/dev/null | grep -q '^name:'"
check "SKILL.md has description field" "head -20 skills/outcome-validation/SKILL.md 2>/dev/null | grep -q '^description:'"

# I3: Registered in marketplace
check "Registered in marketplace.json" "grep -q 'outcome-validation' .claude-plugin/marketplace.json"

# I4: Close command references outcome validation
check "close.md references outcome-validation" "grep -q 'outcome-validation' commands/close.md"

# Skill content checks — 4 personas
check "Has Customer Advocate persona" "grep -q 'Customer Advocate' skills/outcome-validation/SKILL.md 2>/dev/null"
check "Has CFO Lens persona" "grep -q 'CFO Lens' skills/outcome-validation/SKILL.md 2>/dev/null"
check "Has Product Strategist persona" "grep -q 'Product Strategist' skills/outcome-validation/SKILL.md 2>/dev/null"
check "Has Skeptic persona" "grep -q 'Skeptic' skills/outcome-validation/SKILL.md 2>/dev/null"

# Verdict types
check "Has ACHIEVED verdict" "grep -q 'ACHIEVED' skills/outcome-validation/SKILL.md 2>/dev/null"
check "Has PARTIALLY_ACHIEVED verdict" "grep -q 'PARTIALLY_ACHIEVED' skills/outcome-validation/SKILL.md 2>/dev/null"
check "Has NOT_ACHIEVED verdict" "grep -q 'NOT_ACHIEVED' skills/outcome-validation/SKILL.md 2>/dev/null"
check "Has UNDETERMINABLE verdict" "grep -q 'UNDETERMINABLE' skills/outcome-validation/SKILL.md 2>/dev/null"

# Skip conditions
check "Documents type:chore skip" "grep -q 'type:chore' skills/outcome-validation/SKILL.md 2>/dev/null"
check "Documents type:spike skip" "grep -q 'type:spike' skills/outcome-validation/SKILL.md 2>/dev/null"
check "Documents --quick skip" "grep -q '\-\-quick' skills/outcome-validation/SKILL.md 2>/dev/null"
check "Documents exec:quick <=2pt skip" "grep -q 'exec:quick' skills/outcome-validation/SKILL.md 2>/dev/null"

# Integration with quality scoring
check "References quality-scoring" "grep -q 'quality-scoring' skills/outcome-validation/SKILL.md 2>/dev/null"

# Version bump
check "Version is 1.6.2" "grep -q '\"1.6.2\"' .claude-plugin/marketplace.json"

# Depth threshold (8K+ chars)
if [ -f skills/outcome-validation/SKILL.md ]; then
  CHARS=$(wc -c < skills/outcome-validation/SKILL.md)
  check "SKILL.md >= 8000 chars ($CHARS)" "[ $CHARS -ge 8000 ]"
else
  check "SKILL.md >= 8000 chars (file missing)" "false"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) checks"
[ $FAIL -eq 0 ] && echo "ALL TESTS PASS" || echo "SOME TESTS FAILED"
exit $FAIL
