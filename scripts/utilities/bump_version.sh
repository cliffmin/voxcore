#!/bin/bash
# Version bump script for VoxCore
# Usage: ./scripts/utilities/bump_version.sh 0.5.0
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.5.0"
    exit 1
fi

VERSION="$1"

# Validate version format (semver)
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Error: Version must be in semver format (e.g., 0.5.0)"
    exit 1
fi

echo "Bumping version to $VERSION..."
echo ""

# Update build.gradle
echo "→ Updating whisper-post-processor/build.gradle"
sed -i '' "s/version = '.*'/version = '$VERSION'/" whisper-post-processor/build.gradle

# Update CLI
echo "→ Updating WhisperPostProcessorCLI.java"
sed -i '' "s/version = \".*\"/version = \"$VERSION\"/" whisper-post-processor/src/main/java/com/cliffmin/whisper/WhisperPostProcessorCLI.java

# Update CHANGELOG
DATE=$(date +%Y-%m-%d)
echo "→ Updating CHANGELOG.md"
if grep -q "## \[Unreleased\]" CHANGELOG.md; then
    sed -i '' "s/## \[Unreleased\]/## [Unreleased]\n\n## [$VERSION] - $DATE/" CHANGELOG.md
else
    echo "Warning: No [Unreleased] section found in CHANGELOG.md"
fi

echo ""
echo "✓ Version updated to $VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes:    git diff"
echo "  2. Update CHANGELOG:  Add release notes under [$VERSION]"
echo "  3. Commit changes:    git add -A && git commit -m 'chore: bump version to $VERSION'"
echo "  4. Create tag:        git tag -a v$VERSION -m 'Release $VERSION'"
echo "  5. Push with tags:    git push origin main --tags"
echo ""
echo "Note: Branch protection may require a PR instead of direct push"

