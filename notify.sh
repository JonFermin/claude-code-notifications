#!/bin/bash
# Claude Code notification hook
# Sends macOS notifications when Claude finishes a task or needs input.
# Usage: echo '{"json":"input"}' | notify.sh <stop|notification>

INPUT=$(cat)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Skip subagent events — only notify for main session
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')
if [ -n "$AGENT_ID" ]; then
  exit 0
fi

# Extract repo name from cwd
REPO=$(echo "$INPUT" | jq -r '(.cwd // "") | split("/") | last // "unknown"')

# Get first sentence of last assistant message, truncated to 60 chars
SUMMARY=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' \
  | tr '\n' ' ' \
  | sed 's/  */ /g' \
  | grep -oE '^[^.!?]+' \
  | head -1 \
  | cut -c1-60)
SUMMARY="${SUMMARY:-Session}"

# Get notification message - use hook message first, fall back to last assistant message
QUESTION=$(echo "$INPUT" | jq -r '.message // ""')
if [ -z "$QUESTION" ]; then
  QUESTION=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' \
    | tr '\n' ' ' \
    | sed 's/  */ /g' \
    | cut -c1-200)
fi
QUESTION="${QUESTION:-Needs your input}"

# Find terminal-notifier
NOTIFIER=$(command -v terminal-notifier 2>/dev/null)
if [ -z "$NOTIFIER" ]; then
  echo "Error: terminal-notifier not found. Install with: brew install terminal-notifier" >&2
  exit 1
fi

# Detect terminal app for focus switching
detect_terminal() {
  if [ -n "$TERM_PROGRAM" ]; then
    case "$TERM_PROGRAM" in
      vscode) echo "Code" ;;
      cursor) echo "Cursor" ;;
      Apple_Terminal) echo "Terminal" ;;
      iTerm.app) echo "iTerm2" ;;
      Hyper) echo "Hyper" ;;
      *) echo "$TERM_PROGRAM" ;;
    esac
  elif [ -n "$__CFBundleIdentifier" ]; then
    case "$__CFBundleIdentifier" in
      com.microsoft.VSCode) echo "Code" ;;
      com.todesktop.230313mzl4w4u92) echo "Cursor" ;;
      dev.zed.Zed*) echo "Zed" ;;
      com.apple.Terminal) echo "Terminal" ;;
      com.googlecode.iterm2) echo "iTerm2" ;;
      io.alacritty) echo "Alacritty" ;;
      com.mitchellh.ghostty) echo "Ghostty" ;;
      net.kovidgoyal.kitty) echo "kitty" ;;
      *) echo "" ;;
    esac
  else
    echo ""
  fi
}

TERMINAL_APP=$(detect_terminal)

# Sanitize values for shell quoting in -execute callback
sanitize() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }
SAFE_APP=$(sanitize "$TERMINAL_APP")
SAFE_REPO=$(sanitize "$REPO")

case "$1" in
  stop)
    "$NOTIFIER" -message "$REPO — $SUMMARY" -title "Claude Code ✅" -sound Glass \
      -execute "$SCRIPT_DIR/notify.sh focus '${SAFE_APP}' '${SAFE_REPO}'"
    ;;
  notification)
    "$NOTIFIER" -message "$QUESTION" -title "Claude Code 🙋" -subtitle "$REPO" -sound Ping \
      -execute "$SCRIPT_DIR/notify.sh focus '${SAFE_APP}' '${SAFE_REPO}'"
    ;;
  focus)
    APP="$2"
    WINDOW_MATCH="$3"
    if [ -n "$APP" ]; then
      # Escape backslashes and double quotes for safe AppleScript interpolation
      SAFE_AS_APP=$(printf '%s' "$APP" | sed 's/\\/\\\\/g; s/"/\\"/g')
      SAFE_AS_MATCH=$(printf '%s' "$WINDOW_MATCH" | sed 's/\\/\\\\/g; s/"/\\"/g')
      osascript -e "
        tell application \"System Events\"
          tell process \"$SAFE_AS_APP\"
            set frontmost to true
            repeat with w in every window
              if name of w contains \"$SAFE_AS_MATCH\" then
                perform action \"AXRaise\" of w
                exit repeat
              end if
            end repeat
          end tell
        end tell
      " 2>/dev/null
    fi
    ;;
esac
