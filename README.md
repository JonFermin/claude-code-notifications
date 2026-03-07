# claude-code-notify

Native macOS notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Get notified when Claude finishes a task or needs your input — click the notification to focus your terminal window.

## Features

- **Stop notification** — alert with sound when Claude completes a task
- **Input notification** — alert when Claude asks a question or needs input
- **Click to focus** — clicking a notification brings your terminal/editor to the front
- **Auto-detects your terminal** — works with Cursor, VS Code, iTerm2, Terminal.app, Ghostty, Alacritty, Zed, kitty, and more

## Requirements

- macOS
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [Homebrew](https://brew.sh) (for installing dependencies)
- `jq` (`brew install jq`)
- `terminal-notifier` (`brew install terminal-notifier`) — installed automatically by the installer if missing

## Install

```bash
git clone https://github.com/honsfermin/claude-code-notify.git
cd claude-code-notify
./install.sh
```

The installer adds `Notification` and `Stop` hooks to your `~/.claude/settings.json`.

## Uninstall

```bash
cd claude-code-notify
./uninstall.sh
```

## How it works

Claude Code [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) are shell commands that run in response to lifecycle events. This project registers two hooks:

| Event | What happens |
|---|---|
| `Stop` | Claude finished its task. You get a notification with the repo name and a summary of what it did. |
| `Notification` | Claude needs input (e.g. asking a question, waiting for permission). You get the question text in the notification. |

Clicking either notification runs an AppleScript to bring your terminal/editor window to the front and raise the matching project window.

## Manual setup

If you prefer not to use the installer, add this to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/claude-code-notify/notify.sh notification"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/claude-code-notify/notify.sh stop"
          }
        ]
      }
    ]
  }
}
```

## License

MIT
