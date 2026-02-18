#!/usr/bin/env bash
# CCC Hook: Conformance Log (PostToolUse) — CIA-396
#
# Logs write metadata to .ccc-conformance-queue.jsonl.
# O(1) append, <5ms. Never blocks. Always exits 0.
#
# Trigger: PostToolUse, matcher: Write|Edit|MultiEdit|NotebookEdit
# Input: JSON on stdin (tool_name, tool_input, tool_result)
# Output: Appends to .ccc-conformance-queue.jsonl

set -uo pipefail

PROJECT_ROOT="${CCC_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CACHE_FILE="$PROJECT_ROOT/.ccc-conformance-cache.json"
QUEUE_FILE="$PROJECT_ROOT/.ccc-conformance-queue.jsonl"

# ---------------------------------------------------------------------------
# 1. Fail-open: no cache = no conformance active
# ---------------------------------------------------------------------------

if [[ ! -f "$CACHE_FILE" ]]; then
    exit 0
fi

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. Read stdin and extract write metadata
# ---------------------------------------------------------------------------

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")

# Try to get file_path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Fallback: try to extract from tool_result content
if [[ -z "$FILE_PATH" ]]; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_result.content // empty' 2>/dev/null | head -1 || echo "unknown")
fi

# Extract tool_input keys for keyword matching
TOOL_INPUT_KEYS=$(echo "$INPUT" | jq -r '.tool_input | keys? | join(",")' 2>/dev/null || echo "")

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ---------------------------------------------------------------------------
# 3. Append to queue (O(1))
# ---------------------------------------------------------------------------

jq -nc \
    --arg ts "$TIMESTAMP" \
    --arg tool "$TOOL_NAME" \
    --arg file "$FILE_PATH" \
    --arg keys "$TOOL_INPUT_KEYS" \
    '{timestamp: $ts, tool: $tool, file: $file, tool_input_keys: $keys}' \
    >> "$QUEUE_FILE"

exit 0
