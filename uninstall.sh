#!/bin/bash
# Uninstaller for claude-code-notify
# Removes notification hooks from Claude Code settings.

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "No settings file found. Nothing to uninstall."
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

UPDATED=$(jq \
  '(.hooks.Notification) |= ((. // []) | map(select(.hooks | map(.command | test("notify.sh")) | any | not))) |
   (.hooks.Stop) |= ((. // []) | map(select(.hooks | map(.command | test("notify.sh")) | any | not)))' \
  "$SETTINGS_FILE")
echo "$UPDATED" > "$SETTINGS_FILE"

echo "✅ Removed claude-code-notify hooks from settings."
