#!/bin/bash
# Installs Claude Notifier:
#   1. builds the app and copies it to ~/Applications
#   2. copies the hook scripts to ~/.claude/hooks
#   3. adds the Stop and Notification hooks to ~/.claude/settings.json
#      (only if they are not there yet; a backup is made first)
set -euo pipefail
cd "$(dirname "$0")/.."

HOOKS="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
APP_NAME="Claude Notifier.app"

step() { printf '\n==> %s\n' "$1"; }

step "Checking requirements"
missing=()
for tool in swift jq terminal-notifier; do
  command -v "$tool" >/dev/null || missing+=("$tool")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing: ${missing[*]}"
  echo "Install them first, for example:"
  echo "  xcode-select --install          # swift"
  echo "  brew install jq terminal-notifier"
  exit 1
fi
echo "OK"

step "Building the app"
scripts/build-app.sh

step "Installing the app to ~/Applications"
mkdir -p "$HOME/Applications"
pkill -x ClaudeNotifier 2>/dev/null || true
rm -rf "$HOME/Applications/$APP_NAME"
cp -R "build/$APP_NAME" "$HOME/Applications/"
echo "Installed ~/Applications/$APP_NAME"

step "Installing the hook scripts to $HOOKS"
mkdir -p "$HOOKS/sounds"
install -m 755 hooks/notify.sh hooks/focus-iterm.sh "$HOOKS/"
echo "Installed notify.sh and focus-iterm.sh"

step "Adding the hooks to $SETTINGS"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if grep -q 'hooks/notify.sh' "$SETTINGS"; then
  echo "Already configured, nothing to change"
else
  backup="$SETTINGS.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$backup"
  tmp=$(mktemp)
  jq '
    .hooks.Stop = ((.hooks.Stop // []) + [{
      hooks: [{ type: "command", command: "~/.claude/hooks/notify.sh '\''Done, waiting for you'\'' done" }]
    }])
    | .hooks.Notification = ((.hooks.Notification // []) + [{
      matcher: "permission_prompt|elicitation_dialog",
      hooks: [{ type: "command", command: "~/.claude/hooks/notify.sh '\''Needs your input'\'' input" }]
    }])
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "Added hooks (backup: $backup)"
fi

step "Starting Claude Notifier"
open "$HOME/Applications/$APP_NAME"

cat <<'EOF'

Done. Next steps:
  - Restart Claude Code so it loads the hooks.
  - Put your sounds in ~/.claude/hooks/sounds, or pick macOS sounds in the panel.
  - The first banner may ask for notification permission. If no banners show,
    see "Troubleshooting" in the README.
EOF
