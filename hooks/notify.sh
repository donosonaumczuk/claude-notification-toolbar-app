#!/bin/bash
# Claude Code hook: plays a sound and shows a macOS banner when Claude needs you.
#
# Usage (from ~/.claude/settings.json):
#   notify.sh "<fallback message>" <event>
#   <event> is "input" (Notification hook) or "done" (Stop hook).
#
# Settings are read from ~/.claude/hooks/notify.json (written by the menu bar app).
# If the file is missing, defaults are used. If you are already looking at the
# iTerm2 tab where Claude runs, no banner is shown (and no sound, unless
# "soundWhenWatching" is on).

event="${2:-done}"
fallback="${1:-Claude Code}"
CONF="$HOME/.claude/hooks/notify.json"
NOTIFIER="$(command -v terminal-notifier || echo /opt/homebrew/bin/terminal-notifier)"

input=$(cat)

# One jq call reads every setting. `//` can't be used for defaults because it
# also replaces `false`, so `d` only replaces null.
IFS=$'\t' read -r enabled sound_on banner_on sound_watching volume ev_on sound < <(
  { [ -f "$CONF" ] && cat "$CONF" || echo '{}'; } | jq -r --arg e "$event" '
    def d(v; x): if v == null then x else v end;
    [ d(.enabled; true), d(.soundEnabled; true), d(.bannerEnabled; true),
      d(.soundWhenWatching; false), d(.volume; 0.3),
      d(.events[$e].enabled; true), d(.events[$e].sound; "") ] | @tsv' 2>/dev/null
)

[ "${enabled:-true}" = "true" ] || exit 0
[ "${ev_on:-true}" = "true" ] || exit 0
sound="${sound:-$HOME/.claude/hooks/sounds/$event.m4a}"

project=$(basename "$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)")
msg=$(jq -r '.message // empty' <<<"$input" 2>/dev/null)
msg="${msg:-$fallback}"
sid="${ITERM_SESSION_ID#*:}"

play_sound() {
  [ "${sound_on:-true}" = "true" ] && [ -f "$sound" ] &&
    afplay -v "${volume:-0.3}" "$sound" >/dev/null 2>&1 &
}

# Are you looking at this exact iTerm2 tab right now?
watching=false
front=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
if [ "$front" = "iTerm2" ] && [ -n "$sid" ]; then
  cur=$(osascript -e 'tell application "iTerm2" to get id of current session of current window' 2>/dev/null)
  [ "$cur" = "$sid" ] && watching=true
fi

if [ "$watching" = "true" ]; then
  [ "${sound_watching:-false}" = "true" ] && play_sound
  exit 0
fi

play_sound

if [ "${banner_on:-true}" = "true" ] && [ -x "$NOTIFIER" ]; then
  "$NOTIFIER" -title "Claude · ${project:-session}" -message "$msg" \
    -group "claude-$sid" -execute "$HOME/.claude/hooks/focus-iterm.sh $sid" >/dev/null 2>&1 &
fi

exit 0
