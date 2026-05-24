#!/usr/bin/env bash
# One-time Mac setup for Marine Weather iOS. Does not change global git config.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Marine Weather iOS — macOS setup"
echo "    Repo: $ROOT"

if [[ ! -d "/Applications/Xcode.app" ]]; then
  echo "ERROR: Xcode.app not found. Install Xcode from the App Store first."
  echo "       iOS apps cannot be built with Docker or Command Line Tools alone."
  exit 1
fi

ACTIVE="$(xcode-select -p 2>/dev/null || true)"
if [[ "$ACTIVE" != *"Xcode.app"* ]]; then
  echo "WARNING: Active developer dir is not Xcode.app:"
  echo "  $ACTIVE"
  echo ""
  echo "Run (requires admin password):"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "  sudo xcodebuild -license accept"
  exit 1
fi

if ! command -v xcodegen >/dev/null; then
  echo "==> Installing XcodeGen via Homebrew..."
  brew install xcodegen
fi

echo "==> Generating MarineWeather.xcodeproj from project.yml"
xcodegen generate

echo ""
echo "Done. Open the project:"
echo "  open \"$ROOT/MarineWeather.xcodeproj\""
echo ""
echo "Build (iPad simulator):"
echo "  xcodebuild -scheme MarineWeather -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build"
