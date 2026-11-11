#!/bin/bash
# Removes Claude Notifier. Your sounds and notify.json are kept.
set -euo pipefail

HOOKS="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

pkill -x ClaudeNotifier 2>/dev/null || true
rm -rf "$HOME/Applications/Claude Notifier.app"
rm -f "$HOOKS/notify.sh" "$HOOKS/focus-iterm.sh"
echo "Removed the app and the hook scripts"

if [ -f "$SETTINGS" ] && grep -q 'hooks/notify.sh' "$SETTINGS"; then
  backup="$SETTINGS.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$backup"
  tmp=$(mktemp)
  jq '
    def drop: map(select((.hooks // []) | all(.command | test("hooks/notify\\.sh") | not)));
    (if .hooks.Stop then .hooks.Stop |= drop else . end)
    | (if .hooks.Notification then .hooks.Notification |= drop else . end)
    | if .hooks.Stop == [] then del(.hooks.Stop) else . end
    | if .hooks.Notification == [] then del(.hooks.Notification) else . end
    | if .hooks == {} then del(.hooks) else . end
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "Removed the hooks from $SETTINGS (backup: $backup)"
fi

echo "Kept $HOOKS/sounds and $HOOKS/notify.json. Delete them by hand if you want."
