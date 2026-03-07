#!/bin/bash
# Installer for claude-code-notify
# Adds notification hooks to Claude Code settings.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS_FILE="$HOME/.claude/settings.json"
NOTIFY_SCRIPT="$SCRIPT_DIR/notify.sh"

# Check dependencies
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

if ! command -v terminal-notifier &>/dev/null; then
  echo "terminal-notifier not found. Installing via Homebrew..."
  brew install terminal-notifier
fi

# Make notify.sh executable
chmod +x "$NOTIFY_SCRIPT"

# Create settings file if it doesn't exist
mkdir -p "$HOME/.claude"
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Add hooks to settings using jq (upsert: remove our entry if present, then append)
UPDATED=$(jq \
  --arg notify "$NOTIFY_SCRIPT notification" \
  --arg stop "$NOTIFY_SCRIPT stop" \
  '(.hooks.Notification) |= (((. // []) | map(select(.hooks | map(.command) | map(. == $notify) | any | not))) + [{"hooks": [{"type": "command", "command": $notify}]}]) |
   (.hooks.Stop) |= (((. // []) | map(select(.hooks | map(.command) | map(. == $stop) | any | not))) + [{"hooks": [{"type": "command", "command": $stop}]}])' \
  "$SETTINGS_FILE")

echo "$UPDATED" > "$SETTINGS_FILE"

echo "✅ Installed claude-code-notify hooks."
echo ""
echo "Hooks added to: $SETTINGS_FILE"
echo "  - Notification: sends alert when Claude needs input"
echo "  - Stop: sends alert when Claude finishes a task"
echo ""
echo "Clicking a notification will focus your terminal window."
echo "To uninstall, run: $SCRIPT_DIR/uninstall.sh"
