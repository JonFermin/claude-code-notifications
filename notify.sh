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

# Build session stats from transcript
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
SUMMARY="Done"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  EDITED=$(jq -c 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' "$TRANSCRIPT" 2>/dev/null \
    | grep -cE '"(Edit|Write|NotebookEdit)"' || true)
  CMDS=$(jq -c 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' "$TRANSCRIPT" 2>/dev/null \
    | grep -c '"Bash"' || true)
  FIRST_TS=$(jq -r 'select(.type == "user" or .type == "assistant") | .timestamp' "$TRANSCRIPT" 2>/dev/null | head -1)
  LAST_TS=$(jq -r 'select(.type == "user" or .type == "assistant") | .timestamp' "$TRANSCRIPT" 2>/dev/null | tail -1)
  if [ -n "$FIRST_TS" ] && [ -n "$LAST_TS" ]; then
    START=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${FIRST_TS%%.*}" "+%s" 2>/dev/null || echo "")
    END=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_TS%%.*}" "+%s" 2>/dev/null || echo "")
    if [ -n "$START" ] && [ -n "$END" ]; then
      SECS=$((END - START))
      if [ "$SECS" -ge 3600 ]; then
        DURATION="$((SECS / 3600))h$((SECS % 3600 / 60))m"
      elif [ "$SECS" -ge 60 ]; then
        DURATION="$((SECS / 60))m$((SECS % 60))s"
      else
        DURATION="${SECS}s"
      fi
    fi
  fi
  PARTS=""
  [ "$EDITED" -gt 0 ] 2>/dev/null && PARTS="$EDITED edited"
  [ "$CMDS" -gt 0 ] 2>/dev/null && PARTS="${PARTS:+$PARTS  }$CMDS cmds"
  [ -n "$DURATION" ] && PARTS="${PARTS:+$PARTS  }$DURATION"
  [ -n "$PARTS" ] && SUMMARY="Done. $PARTS"
fi

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

# Detect terminal app for focus switching (returns name compatible with `open -a`)
detect_terminal() {
  local key="${TERM_PROGRAM:-$__CFBundleIdentifier}"
  case "$key" in
    vscode|com.microsoft.VSCode)       echo "Visual Studio Code" ;;
    cursor|com.todesktop.230313mzl4w4u92) echo "Cursor" ;;
    Apple_Terminal|com.apple.Terminal)  echo "Terminal" ;;
    iTerm.app|com.googlecode.iterm2)   echo "iTerm" ;;
    Hyper)                             echo "Hyper" ;;
    dev.zed.Zed*)                      echo "Zed" ;;
    io.alacritty)                      echo "Alacritty" ;;
    com.mitchellh.ghostty)             echo "Ghostty" ;;
    net.kovidgoyal.kitty)              echo "kitty" ;;
    "")                                echo "" ;;
    *)                                 echo "$key" ;;
  esac
}

TERMINAL_APP=$(detect_terminal)
ICON="$SCRIPT_DIR/icon.png"

# Sanitize terminal app name for shell quoting in -execute callback
sanitize() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }
SAFE_APP=$(sanitize "$TERMINAL_APP")

case "$1" in
  stop)
    "$NOTIFIER" -message "$REPO — $SUMMARY" -title "Claude Code ✅" -sound Glass \
      -appIcon "$ICON" \
      -execute "$SCRIPT_DIR/notify.sh focus '${SAFE_APP}'"
    ;;
  notification)
    "$NOTIFIER" -message "$QUESTION" -title "Claude Code 🙋" -subtitle "$REPO" -sound Ping \
      -appIcon "$ICON" \
      -execute "$SCRIPT_DIR/notify.sh focus '${SAFE_APP}'"
    ;;
  focus)
    APP="$2"
    if [ -n "$APP" ]; then
      open -a "$APP"
    fi
    ;;
esac
