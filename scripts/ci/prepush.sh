#!/usr/bin/env bash
set -euo pipefail

# This script runs a quick pre-push check to prevent pushing directly to main.
# Usage: add to your shell rc: git config hooks.prepush "scripts/ci/prepush.sh"

branch=$(git rev-parse --abbrev-ref HEAD)
remote=${1:-origin}

if [[ "$branch" == "main" ]]; then
  echo "❌ Prevented push to main. Please create a PR from a feature/* branch."
  exit 1
fi

echo "✓ Pre-push check passed for branch $branch"
exit 0
