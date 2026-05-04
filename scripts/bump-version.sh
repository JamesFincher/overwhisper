#!/bin/bash
set -e

# Usage: ./scripts/bump-version.sh <version>
# Example: ./scripts/bump-version.sh 1.0.24

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.24"
    exit 1
fi

VERSION="$1"

# Validate version format (basic check)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format X.Y.Z (e.g., 1.0.24)"
    exit 1
fi

echo "Bumping version to $VERSION..."

# Update project.yml
sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$VERSION\"/" project.yml

# Update project.pbxproj (has multiple occurrences)
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" Overwhisper.xcodeproj/project.pbxproj

echo "Updated version in project files"

# Commit
git add project.yml Overwhisper.xcodeproj/project.pbxproj
git commit -m "Bump version to $VERSION"

# Create and push tag
git tag "v$VERSION"

CURRENT_BRANCH="$(git branch --show-current)"
REMOTE="${RELEASE_REMOTE:-$(git config "branch.$CURRENT_BRANCH.remote" || true)}"
REMOTE="${REMOTE:-origin}"
REMOTE_URL="$(git remote get-url --push "$REMOTE" 2>/dev/null || git remote get-url "$REMOTE")"

if echo "$REMOTE_URL" | grep -qi 'OverseedAI/overwhisper'; then
    echo "Error: refusing to release to $REMOTE_URL"
    echo "Set this checkout to use https://github.com/JamesFincher/overwhisper.git before releasing."
    exit 1
fi

echo "Pushing commit and tag to $REMOTE ($REMOTE_URL)..."
git push "$REMOTE" HEAD:main
git push "$REMOTE" "v$VERSION"

echo "Done! Version $VERSION released."
echo "GitHub Actions 'Build and Release DMG' workflow should now trigger."
