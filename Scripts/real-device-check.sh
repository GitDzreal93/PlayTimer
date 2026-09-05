#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Xcode =="
xcodebuild -version

echo
echo "== Code signing identities =="
security find-identity -v -p codesigning || true

echo
echo "== Connected devices =="
xcrun devicectl list devices || true

echo
echo "== Generate project =="
xcodegen generate

echo
echo "== Build with automatic provisioning =="
xcodebuild \
  -project PlayTimer.xcodeproj \
  -scheme PlayTimer \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  build
