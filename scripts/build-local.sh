#!/usr/bin/env bash
# Builds this fork of Sol (ad-hoc signed, no Sentry upload) and installs it to
# /Applications, replacing the official build (kept as /Applications/Sol.app.bak).
# Sparkle's automatic update checks are turned off, so an official release doesn't
# replace this build. Turn them back on once upstream ships the fix:
#   defaults delete com.ospfranco.sol SUEnableAutomaticChecks
set -euo pipefail
cd "$(dirname "$0")/.."

command -v mise >/dev/null && mise install
# src/env.ts is gitignored upstream. An empty DSN also keeps this build's crashes out
# of upstream's Sentry.
[ -f src/env.ts ] || echo "export const SentryDSN = ''" > src/env.ts
bun install
bundle install
(cd macos && bundle exec pod install)

export SENTRY_DISABLE_AUTO_UPLOAD=true
xcodebuild -workspace macos/sol.xcworkspace -scheme release -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
  build

app=build/DerivedData/Build/Products/Release/sol.app
[ -d "$app" ] || { echo "build product missing: $app" >&2; exit 1; }
codesign --verify --deep --strict "$app"

osascript -e 'quit app id "com.ospfranco.sol"' 2>/dev/null || true
for _ in 1 2 3 4 5; do pgrep -x sol >/dev/null || break; sleep 1; done
pkill -x sol 2>/dev/null || true
if [ -d /Applications/Sol.app ] && [ ! -d /Applications/Sol.app.bak ]; then
  mv /Applications/Sol.app /Applications/Sol.app.bak
else
  rm -rf /Applications/Sol.app
fi
ditto "$app" /Applications/Sol.app
defaults write com.ospfranco.sol SUEnableAutomaticChecks -bool false
open /Applications/Sol.app
echo "Installed. macOS treats this as a new app: grant Accessibility (and Calendar) again if asked."
