#!/usr/bin/env bash
# SDD Hook: SessionStart
# Trigger: Session begins
# Purpose: Load active spec, verify context budget, set ownership scope
#
# Install: Copy to your project's .claude/hooks/session-start.sh
# Configure in .claude/settings.json:
#   "hooks": { "SessionStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": ".claude/hooks/session-start.sh" }] }] }
#
# Environment variables:
#   SDD_SPEC_PATH    - Path to active spec file (auto-detected if not set)
#   SDD_CONTEXT_THRESHOLD - Context budget warning threshold (default: 50)
#   SDD_PROJECT_ROOT - Project root directory (default: git root)

set -euo pipefail

PROJECT_ROOT="${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONTEXT_THRESHOLD="${SDD_CONTEXT_THRESHOLD:-50}"

# --- 1. Load active spec ---
# Look for spec reference in frontmatter of active issues
# Customize this section based on your project tracker integration

if [[ -n "${SDD_SPEC_PATH:-}" ]] && [[ -f "$SDD_SPEC_PATH" ]]; then
  echo "[SDD] Active spec loaded: $SDD_SPEC_PATH"
else
  echo "[SDD] No active spec path set. Set SDD_SPEC_PATH or ensure issue has spec link."
fi

# --- 2. Check for stale context ---
# Look for codebase index and check freshness

INDEX_FILE="$PROJECT_ROOT/.claude/codebase-index.md"
if [[ -f "$INDEX_FILE" ]]; then
  INDEX_DATE=$(head -5 "$INDEX_FILE" | grep -oP 'Generated: \K[0-9-]+' || echo "unknown")
  echo "[SDD] Codebase index found (generated: $INDEX_DATE)"
else
  echo "[SDD] No codebase index found. Consider running /sdd:index"
fi

# --- 3. Git state summary ---

BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
echo "[SDD] Branch: $BRANCH | Uncommitted files: $UNCOMMITTED"

# --- 4. Ownership scope ---
# Log which files are expected to be modified in this session
# Customize based on your spec's file scope

echo "[SDD] Session initialized. Context threshold: ${CONTEXT_THRESHOLD}%"
