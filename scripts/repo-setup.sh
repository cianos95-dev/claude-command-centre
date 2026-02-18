#!/usr/bin/env bash
# repo-setup.sh — Apply standard GitHub settings after creating a repo from template
#
# Usage: ./scripts/repo-setup.sh <owner/repo>
# Example: ./scripts/repo-setup.sh cianos95-dev/cognito-acme
#
# Prerequisites: gh CLI authenticated with repo scope

set -euo pipefail

REPO="${1:?Usage: $0 <owner/repo>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULESETS_DIR="$SCRIPT_DIR/../.github/rulesets"

echo "Setting up repository: $REPO"

# 1. Apply rulesets
for ruleset in "$RULESETS_DIR"/*.json; do
  name=$(basename "$ruleset" .json)
  echo "  Applying ruleset: $name"
  gh api "repos/$REPO/rulesets" --input "$ruleset" 2>&1 || {
    echo "  Warning: Failed to apply ruleset $name (may already exist)"
  }
done

# 2. Authorize repo in Tembo (manual step — print reminder)
echo ""
echo "Manual steps remaining:"
echo "  1. Tembo: Authorize repo at https://app.tembo.dev/settings/integrations"
echo "  2. Linear: Link repo to project in Linear settings"
echo "  3. Secrets: Add any required repository secrets via gh secret set"

echo ""
echo "Setup complete for $REPO"
