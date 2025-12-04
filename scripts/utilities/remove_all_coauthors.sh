#!/bin/bash
# Remove all co-author tags from git history
# This will rewrite history - use with caution

set -e

echo "=== Removing all co-author tags from git history ==="
echo ""
echo "Current branch: $(git branch --show-current)"
echo "Commits with co-author tags: $(git log --format='%B' --all | grep -i 'co-authored' | wc -l | tr -d ' ')"
echo ""
echo "This will rewrite ALL commits in the repository."
echo "Make sure you have a backup and are on the correct branch."
echo ""
read -p "Continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "Rewriting history for all branches and tags..."
echo "This may take a few minutes..."
echo ""

# Backup refs first
BACKUP_DIR=".git/refs/original"
if [[ -d "$BACKUP_DIR" ]]; then
  echo "Removing old backup refs..."
  rm -rf "$BACKUP_DIR"
fi

# Use git filter-branch to remove co-author tags from all commits
# This handles all branches and tags
git filter-branch --force --msg-filter '
  # Remove Co-authored-by lines (case insensitive, various formats)
  # Handle both leading whitespace and no whitespace
  sed -E "/^[[:space:]]*[Cc]o-[Aa]uthored-[Bb]y:.*$/d" | \
  # Remove empty lines that might be left behind (but keep at least one newline)
  sed -E "/^[[:space:]]*$/d" | \
  # Ensure message ends with newline
  cat
' --tag-name-filter cat -- --branches --tags

# Clean up backup refs
rm -rf .git/refs/original

# Expire reflog and garbage collect
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "=== History rewrite complete ==="
echo ""
echo "Verifying removal..."
REMAINING=$(git log --format='%B' --all | grep -i 'co-authored' | wc -l | tr -d ' ')
if [[ "$REMAINING" -eq 0 ]]; then
  echo "✅ All co-author tags removed successfully!"
else
  echo "⚠️  Warning: $REMAINING co-author tags still found"
fi
echo ""
echo "Next steps:"
echo "1. Review the changes: git log --oneline | head -20"
echo "2. Verify: git log --format='%B' --all | grep -i 'co-authored' | wc -l"
echo "3. Force push to remote: git push origin --force --all --tags"
echo ""
echo "WARNING: This rewrites history. Make sure to coordinate with any collaborators."
echo "You may need to disable branch protection rules temporarily."

