# Claude Notifier

A small macOS menu bar app that tells you when [Claude Code](https://claude.com/claude-code) needs you.

When Claude finishes an answer, or stops to ask for permission, you hear a sound and get a macOS banner. Click the banner and iTerm2 jumps to the exact tab where Claude is waiting. If you are already looking at that tab, nothing happens, so it doesn't bother you while you watch.

The menu bar icon lets you change everything without editing files:

- **Left click** turns all notifications on or off.
- **Right click** (or Control-click) opens the settings panel.

> This is a personal project. It is not made by or affiliated with Anthropic.

## Features

- Separate events, each with its own on/off switch and sound:
  - **Needs input**: permission prompts and questions from Claude.
  - **Response done**: Claude finished its answer.
- Pick sounds from your own folder or from the built-in macOS sounds, and play them from the panel.
- Add any audio file (`.m4a`, `.mp3`, `.wav`, `.aiff`, `.caf`, ...) with the **+** button.
- Volume slider.
- Turn the sound and the banner on or off separately.
- Optional: play the sound even when you are looking at the tab.
- Clicking a banner focuses the right iTerm2 window, tab and pane.
- Open at login.

## Requirements

- macOS 13 or later
- [Claude Code](https://claude.com/claude-code)
- Swift (Xcode or the Command Line Tools: `xcode-select --install`)
- [`jq`](https://jqlang.github.io/jq/) and [`terminal-notifier`](https://github.com/julienXX/terminal-notifier):

  ```sh
  brew install jq terminal-notifier
  ```

- iTerm2, for click-to-focus and for "stay quiet when I'm looking at the tab". Sounds and banners work in other terminals too, but there clicking a banner won't open the tab and you are always notified.

## Install

```sh
git clone https://github.com/donosonaumczuk/claude-notification-toolbar-app.git
cd claude-notification-toolbar-app
scripts/install.sh
```

The script:

1. Builds the app and copies it to `~/Applications/Claude Notifier.app`.
2. Copies the hook scripts to `~/.claude/hooks/`.
3. Copies the default sounds to `~/.claude/hooks/sounds/<event>/Default.m4a`.
4. Adds two hooks to `~/.claude/settings.json`, only if they are not there yet. It saves a backup of the file first.
5. Starts the app.

Then **restart Claude Code**, because it reads hooks only at startup. You can check that they are loaded with `/hooks`.

To start the app at login, turn on **Open at login** in the panel.

### Sounds

Each event comes with a sound called **Default**:

- `~/.claude/hooks/sounds/input/Default.m4a` for **Needs input**
- `~/.claude/hooks/sounds/done/Default.m4a` for **Response done**

The Default sound is also the fallback. If the sound you picked is deleted or moved, the Default plays instead, and the panel shows it as "(missing), plays Default".

To use your own sounds, put audio files in `~/.claude/hooks/sounds/` or use the **+** button in the panel. Don't put them in the `input/` or `done/` folders: `install.sh` overwrites the Default files there.

## How it works

```
Claude Code ──hook──▶ ~/.claude/hooks/notify.sh ──reads──▶ ~/.claude/hooks/notify.json
                              │                                     ▲
                              ├─ afplay (sound)                     │ writes
                              └─ terminal-notifier (banner)   Claude Notifier (menu bar)
                                       │ click
                                       ▼
                              focus-iterm.sh (opens the tab)
```

- Claude Code runs `notify.sh` on two [hook events](https://docs.claude.com/en/docs/claude-code/hooks):
  - `Stop`: Claude finished its answer.
  - `Notification` with matcher `permission_prompt|elicitation_dialog`: Claude needs permission or asks you a question.
- `notify.sh` reads `notify.json` on every run. So changes in the panel apply right away, with no restart.
- The app and Claude Code never talk to each other directly. The JSON file is the only link between them. You can quit the app and the notifications keep working with the last settings.

The hooks added to `~/.claude/settings.json` look like this:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh 'Done, waiting for you' done" }] }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh 'Needs your input' input" }]
      }
    ]
  }
}
```

### Settings file

`~/.claude/hooks/notify.json` is written by the app, but you can also edit it by hand. Missing keys use the defaults shown here.

```json
{
  "enabled": true,
  "soundEnabled": true,
  "bannerEnabled": true,
  "soundWhenWatching": false,
  "volume": 0.3,
  "events": {
    "input": { "enabled": true, "sound": "/Users/you/.claude/hooks/sounds/input/Default.m4a" },
    "done":  { "enabled": true, "sound": "/Users/you/.claude/hooks/sounds/done/Default.m4a" }
  }
}
```

| Key | Meaning |
|---|---|
| `enabled` | Main switch. `false` turns off everything. |
| `soundEnabled` | Play sounds. |
| `bannerEnabled` | Show macOS banners. |
| `soundWhenWatching` | Also play the sound when you are looking at the Claude tab. Banners are never shown in that case. |
| `volume` | `0.0` to `1.0`, relative to the system volume. |
| `events.<name>.enabled` | Turn one event on or off. |
| `events.<name>.sound` | Full path to the sound file. If it is empty or the file is missing, `sounds/<name>/Default.m4a` plays. |

## Troubleshooting

**No banners at all.** Run this:

```sh
terminal-notifier -title test -message test
```

If it prints `Notifications are not allowed for this application`, macOS has not registered `terminal-notifier` yet. Open it once as an app so macOS asks for permission:

```sh
open -a "$(brew --prefix terminal-notifier)/terminal-notifier.app" --args -title test -message test
```

Click **Allow**. Then check System Settings → Notifications → terminal-notifier. Choose **Alerts** if you want banners to stay until you click them.

**Banners show, but clicking one does nothing.** Allow `terminal-notifier` to control iTerm2 in System Settings → Privacy & Security → Automation.

**No sound.** Check that the sound file exists (the panel shows "(missing)" if not), that **Play sound** is on, and that your Mac is not muted. Test the hook by hand:

```sh
echo '{"cwd":"'$PWD'"}' | ITERM_SESSION_ID=test ~/.claude/hooks/notify.sh "Test" done
```

**Nothing happens after installing.** Restart Claude Code and check `/hooks`.

**Banners are hidden.** A Focus mode (Do Not Disturb) hides banners. Sounds still play, because they don't go through macOS notifications.

## Uninstall

```sh
scripts/uninstall.sh
```

This removes the app, the hook scripts, the Default sounds and the hooks in `~/.claude/settings.json` (with a backup). Your own sounds and `notify.json` stay in `~/.claude/hooks/`.

## Development

```sh
swift build                 # debug build
scripts/build-app.sh        # build "build/Claude Notifier.app"
open "build/Claude Notifier.app"
```

Code layout:

| Path | What it does |
|---|---|
| `Sources/ClaudeNotifier/main.swift` | Menu bar icon: left click toggles, right click opens the panel |
| `Sources/ClaudeNotifier/PanelView.swift` | Settings panel (SwiftUI) |
| `Sources/ClaudeNotifier/Config.swift` | `notify.json` model, load and save |
| `Sources/ClaudeNotifier/SoundLibrary.swift` | Sound list, preview, import |
| `Sources/ClaudeNotifier/LoginItem.swift` | Open at login |
| `hooks/notify.sh` | The Claude Code hook |
| `hooks/focus-iterm.sh` | Focuses the iTerm2 tab on banner click |
| `sounds/<event>/Default.m4a` | Default sound for each event |
| `scripts/` | Build, install and uninstall |
