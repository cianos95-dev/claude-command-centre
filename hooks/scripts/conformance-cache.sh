#!/usr/bin/env bash
# CCC Hook: Conformance Cache (SessionStart extension) — CIA-396
#
# Parses the active spec, extracts acceptance criteria keywords,
# and caches them for the conformance audit pipeline.
#
# Trigger: SessionStart (via hooks.json)
# Input: None (reads CCC_SPEC_PATH env var)
# Output: .ccc-conformance-cache.json in project root
#
# Fail-open: If CCC_SPEC_PATH is unset or spec is missing, exits 0 silently.

set -uo pipefail

PROJECT_ROOT="${CCC_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CACHE_FILE="$PROJECT_ROOT/.ccc-conformance-cache.json"

# ---------------------------------------------------------------------------
# 1. Check for spec path
# ---------------------------------------------------------------------------

if [[ -z "${CCC_SPEC_PATH:-}" ]]; then
    # No spec configured — fail-open
    exit 0
fi

if [[ ! -f "$CCC_SPEC_PATH" ]]; then
    echo "[CCC-CONFORMANCE] WARNING: Spec file not found: $CCC_SPEC_PATH" >&2
    exit 0
fi

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. Compute spec hash
# ---------------------------------------------------------------------------

if command -v shasum &>/dev/null; then
    SPEC_HASH="sha256:$(shasum -a 256 "$CCC_SPEC_PATH" | cut -d' ' -f1)"
elif command -v sha256sum &>/dev/null; then
    SPEC_HASH="sha256:$(sha256sum "$CCC_SPEC_PATH" | cut -d' ' -f1)"
else
    SPEC_HASH="sha256:unknown"
fi

# ---------------------------------------------------------------------------
# 3. Extract unchecked acceptance criteria
# ---------------------------------------------------------------------------

# Stop words to remove from keywords
STOP_WORDS="the a an is are to from with for in on of and or per that this"

CRITERIA_JSON="[]"
AC_INDEX=0

while IFS= read -r line; do
    # Match unchecked checkbox: - [ ] text
    if echo "$line" | grep -qE '^\s*-\s*\[\s*\]'; then
        AC_INDEX=$((AC_INDEX + 1))

        # Extract the text after the checkbox (remove leading "- [ ] ")
        raw_text=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*\[[[:space:]]*\][[:space:]]*//')

        # Extract keywords:
        # 1. Split on whitespace and non-alphanumeric (keeping dots for filenames)
        # 2. Remove stop words
        # 3. Keep words >= 4 chars
        keywords="[]"
        for word in $raw_text; do
            # Clean: remove parens, brackets, etc. but keep dots
            clean=$(echo "$word" | sed 's/[^a-zA-Z0-9._-]//g' | tr '[:upper:]' '[:lower:]')

            # Skip empty, short words
            if [[ ${#clean} -lt 4 ]]; then
                continue
            fi

            # Skip stop words
            is_stop=false
            for sw in $STOP_WORDS; do
                if [[ "$clean" == "$sw" ]]; then
                    is_stop=true
                    break
                fi
            done
            if [[ "$is_stop" == true ]]; then
                continue
            fi

            keywords=$(echo "$keywords" | jq --arg w "$clean" '. + [$w]')
        done

        # Remove duplicate keywords
        keywords=$(echo "$keywords" | jq 'unique')

        CRITERIA_JSON=$(echo "$CRITERIA_JSON" | jq \
            --arg id "AC-$AC_INDEX" \
            --arg raw "$raw_text" \
            --argjson keywords "$keywords" \
            '. + [{"id": $id, "raw": $raw, "keywords": $keywords}]')
    fi
done < "$CCC_SPEC_PATH"

# ---------------------------------------------------------------------------
# 4. Write cache file
# ---------------------------------------------------------------------------

PARSED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

jq -n \
    --arg spec_path "$CCC_SPEC_PATH" \
    --arg spec_hash "$SPEC_HASH" \
    --arg parsed_at "$PARSED_AT" \
    --argjson criteria "$CRITERIA_JSON" \
    '{
        spec_path: $spec_path,
        spec_hash: $spec_hash,
        parsed_at: $parsed_at,
        criteria: $criteria
    }' > "$CACHE_FILE"

CRITERIA_COUNT=$(echo "$CRITERIA_JSON" | jq 'length')
echo "[CCC-CONFORMANCE] Cached $CRITERIA_COUNT acceptance criteria from $CCC_SPEC_PATH" >&2

exit 0
