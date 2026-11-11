#!/bin/bash
# Builds "build/Claude Notifier.app" from the Swift package.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Claude Notifier.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/ClaudeNotifier"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ClaudeNotifier"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature, so macOS can run it and register it as a login item.
codesign --force --sign - "$APP" >/dev/null

echo "Built $APP"
