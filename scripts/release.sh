#!/bin/sh
# Build a universal (Apple Silicon + Intel) app and zip it for a GitHub
# release: build/Typing-Madness-<version>.zip.
#
#   VERSION=0.2.0 sh scripts/release.sh
#
# Upload the zip to a GitHub release. The app is ad-hoc signed, not notarized,
# so people need the "Open Anyway" step from the README's Install section.
# Also updates the Homebrew cask's version and sha256.
set -eu

cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
APP="build/Typing Madness.app"
ZIP="build/Typing-Madness-$VERSION.zip"

UNIVERSAL=1 VERSION="$VERSION" sh scripts/bundle.sh

rm -f "$ZIP"
# ditto keeps the bundle's symlinks, permissions and signature intact.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"

# Point the Homebrew cask at this release.
CASK=packaging/homebrew/typing-madness.rb
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"

echo
echo "Release zip: $ZIP"
lipo -info "$APP/Contents/MacOS/TypingMadness"
echo "sha256:      $SHA"
echo "Cask:        $CASK updated to $VERSION"
echo
echo "Next: tag v$VERSION, attach the zip to a GitHub release, then copy"
echo "$CASK to Casks/typing-madness.rb in your homebrew-tap repository."
