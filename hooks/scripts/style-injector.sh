#!/usr/bin/env bash
# CCC Hook: SessionStart — Style Injector
# Trigger: Session begins (runs alongside session-start.sh)
# Purpose: Read style.explanatory preference, inject audience-aware context
#
# Reads: .ccc-preferences.yaml → style.explanatory (terse|balanced|detailed|educational)
# Output: JSON hookSpecificOutput with additionalContext (Anthropic pattern)
#
# When style.explanatory is "terse" or unset, this hook outputs nothing (no context cost).
# Otherwise it injects CCC-specific output instructions that supplement the agent prompts.

set -uo pipefail

PROJECT_ROOT="${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PREFS_FILE="$PROJECT_ROOT/.ccc-preferences.yaml"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

# --- Read style.explanatory preference ---
STYLE="terse"  # default: no injection
if command -v yq &>/dev/null && [[ -f "$PREFS_FILE" ]]; then
    _s=$(yq '.style.explanatory // "terse"' "$PREFS_FILE" 2>/dev/null)
    if [[ "$_s" == "balanced" || "$_s" == "detailed" || "$_s" == "educational" ]]; then
        STYLE="$_s"
    fi
fi

# --- If terse, output nothing (zero context cost) ---
if [[ "$STYLE" == "terse" ]]; then
    exit 0
fi

# --- Build context based on style level ---
# Read the appropriate style file from the plugin's styles/ directory
STYLE_FILE=""
case "$STYLE" in
    balanced|detailed)
        STYLE_FILE="$PLUGIN_ROOT/styles/explanatory.md"
        ;;
    educational)
        STYLE_FILE="$PLUGIN_ROOT/styles/educational.md"
        ;;
esac

if [[ -z "$STYLE_FILE" || ! -f "$STYLE_FILE" ]]; then
    # Style file missing — degrade gracefully
    exit 0
fi

# Read style content, stripping YAML frontmatter (--- ... --- block at top of file)
STYLE_CONTENT=$(awk 'BEGIN{n=0} /^---$/{n++; if(n<=2) next} n>=2{print}' "$STYLE_FILE" 2>/dev/null)

if [[ -z "$STYLE_CONTENT" ]]; then
    exit 0
fi

# Escape for JSON: backslashes, quotes, newlines, tabs
ESCAPED_CONTENT=$(printf '%s' "$STYLE_CONTENT" | \
    sed 's/\\/\\\\/g' | \
    sed 's/"/\\"/g' | \
    sed 's/	/\\t/g' | \
    awk '{printf "%s\\n", $0}' | \
    sed 's/\\n$//')

# --- Output JSON in Anthropic's hookSpecificOutput pattern ---
cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "You are in CCC '${STYLE}' explanation mode (set via style.explanatory in .ccc-preferences.yaml).\\n\\nWhen working within the CCC workflow (specs, adversarial reviews, decomposition, execution), follow these audience-aware communication rules:\\n\\n${ESCAPED_CONTENT}"
  }
}
EOF

exit 0
