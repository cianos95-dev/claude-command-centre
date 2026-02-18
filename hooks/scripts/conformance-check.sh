#!/usr/bin/env bash
# CCC Hook: Conformance Check (Stop) — CIA-396
#
# Batch processes the write queue against cached acceptance criteria.
# Produces a conformance report with drift details and AC coverage.
#
# Trigger: Stop hook
# Input: JSON on stdin (session metadata — ignored)
# Output: .ccc-conformance-report.json
# Cleanup: Removes queue and cache files

set -uo pipefail

PROJECT_ROOT="${CCC_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CACHE_FILE="$PROJECT_ROOT/.ccc-conformance-cache.json"
QUEUE_FILE="$PROJECT_ROOT/.ccc-conformance-queue.jsonl"
REPORT_FILE="$PROJECT_ROOT/.ccc-conformance-report.json"

# Consume stdin (required for hook protocol)
cat > /dev/null

# ---------------------------------------------------------------------------
# 1. Fail-open: nothing to audit
# ---------------------------------------------------------------------------

if [[ ! -f "$QUEUE_FILE" ]] || [[ ! -s "$QUEUE_FILE" ]]; then
    # Clean up cache if it exists
    rm -f "$CACHE_FILE"
    exit 0
fi

if [[ ! -f "$CACHE_FILE" ]]; then
    rm -f "$QUEUE_FILE"
    exit 0
fi

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. Load cache and queue
# ---------------------------------------------------------------------------

CACHE=$(<"$CACHE_FILE")
SPEC_PATH=$(echo "$CACHE" | jq -r '.spec_path // "unknown"')

# Read queue into a JSON array
QUEUE="[]"
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    QUEUE=$(echo "$QUEUE" | jq --argjson entry "$line" '. + [$entry]')
done < "$QUEUE_FILE"

TOTAL_WRITES=$(echo "$QUEUE" | jq 'length')

# ---------------------------------------------------------------------------
# 3. For each write, check keyword overlap against all criteria
# ---------------------------------------------------------------------------

# The big jq expression: for each write, check overlap with each criterion
RESULT=$(jq -n \
    --argjson cache "$CACHE" \
    --argjson queue "$QUEUE" \
    --arg spec_path "$SPEC_PATH" '

# Normalize: lowercase, split on non-alphanumeric
def tokenize:
    ascii_downcase | [scan("[a-z0-9._-]+")];

$cache.criteria as $criteria |
($queue | length) as $total_writes |

# Process each write
[
    $queue[] |
    . as $write |
    # Tokenize the file path + tool_input_keys
    ((.file // "") | tokenize) as $file_tokens |
    ((.tool_input_keys // "") | gsub(","; " ") | tokenize) as $key_tokens |
    ($file_tokens + $key_tokens) as $write_tokens |

    # Check against each criterion
    [
        $criteria[] |
        . as $criterion |
        ($criterion.keywords | length) as $kw_count |
        if $kw_count == 0 then
            {criterion_id: $criterion.id, match_pct: 0, matched: false}
        else
            # Count how many criterion keywords appear in write tokens
            ([
                $criterion.keywords[] |
                . as $kw |
                if ([$write_tokens[] | select(contains($kw))] | length) > 0
                then 1 else 0 end
            ] | add) as $matches |
            ($matches / $kw_count * 100) as $match_pct |
            {
                criterion_id: $criterion.id,
                match_pct: $match_pct,
                matched: ($match_pct >= 50)
            }
        end
    ] as $criterion_results |

    # A write is conforming if it matches ANY criterion at >= 50%
    ($criterion_results | map(select(.matched)) | length > 0) as $is_conforming |
    ([$criterion_results[] | select(.matched) | .criterion_id]) as $matched_criteria |

    {
        file: $write.file,
        tool: $write.tool,
        timestamp: $write.timestamp,
        is_conforming: $is_conforming,
        matched_criteria: $matched_criteria,
        is_suppressed: false
    }
] as $write_results |

# Build coverage map
[
    $criteria[] |
    .id as $ac_id |
    {
        key: $ac_id,
        value: {
            matching_writes: ([$write_results[] | select(.matched_criteria | index($ac_id))] | length)
        }
    }
] | from_entries as $coverage |

# Separate conforming vs drifting
([$write_results[] | select(.is_conforming)] | length) as $conforming |
([$write_results[] | select(.is_conforming | not)] | length) as $drifting |
[$write_results[] | select(.is_conforming | not) | {
    file: .file,
    tool: .tool,
    matched_criteria: .matched_criteria,
    reason: "No keyword overlap with any AC"
}] as $drift_details |

{
    spec_path: $spec_path,
    total_writes: $total_writes,
    conforming_writes: $conforming,
    potentially_drifting: $drifting,
    suppressed: 0,
    drift_details: $drift_details,
    coverage: $coverage
}
')

# ---------------------------------------------------------------------------
# 4. Check suppression comments in drifting files
# ---------------------------------------------------------------------------

# For each drifting file, check if it contains // ccc:suppress AC-N
SUPPRESSED_COUNT=0
UPDATED_DRIFT="[]"

DRIFT_FILES=$(echo "$RESULT" | jq -r '.drift_details[].file')
while IFS= read -r drift_file; do
    [[ -z "$drift_file" ]] && continue

    # Check if file exists and has suppression comment
    if [[ -f "$drift_file" ]] && grep -q '// ccc:suppress' "$drift_file" 2>/dev/null; then
        SUPPRESSED_COUNT=$((SUPPRESSED_COUNT + 1))
    else
        # Keep in drift details
        ENTRY=$(echo "$RESULT" | jq --arg f "$drift_file" '.drift_details[] | select(.file == $f)')
        UPDATED_DRIFT=$(echo "$UPDATED_DRIFT" | jq --argjson e "$ENTRY" '. + [$e]')
    fi
done <<< "$DRIFT_FILES"

# Update report with suppression data
NEW_DRIFTING=$(($(echo "$RESULT" | jq '.potentially_drifting') - SUPPRESSED_COUNT))
RESULT=$(echo "$RESULT" | jq \
    --argjson suppressed "$SUPPRESSED_COUNT" \
    --argjson drifting "$NEW_DRIFTING" \
    --argjson drift_details "$UPDATED_DRIFT" \
    '.suppressed = $suppressed | .potentially_drifting = $drifting | .drift_details = $drift_details')

# ---------------------------------------------------------------------------
# 5. Write report
# ---------------------------------------------------------------------------

echo "$RESULT" > "$REPORT_FILE"

CONFORMING=$(echo "$RESULT" | jq '.conforming_writes')
DRIFTING=$(echo "$RESULT" | jq '.potentially_drifting')
echo "[CCC-CONFORMANCE] Report: $TOTAL_WRITES writes, $CONFORMING conforming, $DRIFTING potentially drifting, $SUPPRESSED_COUNT suppressed" >&2

# ---------------------------------------------------------------------------
# 6. Cleanup
# ---------------------------------------------------------------------------

rm -f "$QUEUE_FILE"
rm -f "$CACHE_FILE"

exit 0
