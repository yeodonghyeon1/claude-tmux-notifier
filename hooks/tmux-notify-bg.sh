#!/usr/bin/env bash
# Background notification handler.
#
# Shows an interactive notify-send with an [Open] action button.
# When the user clicks it:
#   1. tmux switches to the target window (session:index)
#   2. xdotool raises/focuses the X11 terminal that holds the tmux client
#
# Designed to be spawned with `nohup ... &` from a hook so the hook returns
# immediately and this script blocks alone waiting for the user.
#
# Usage:
#   tmux-notify-bg.sh <urgency> <expire-ms> <title> <body> <tmux-target>
#
#   <urgency>      low / normal / critical
#   <expire-ms>    notification auto-dismiss timeout in milliseconds, 0 = never
#   <tmux-target>  "<session>:<window-index>", e.g. "1:6". Empty → action skipped.

set -u

URGENCY="${1:-normal}"
EXPIRE_MS="${2:-10000}"
TITLE="${3:-Claude}"
BODY="${4:-}"
TARGET="${5:-}"

# notify-send -A automatically implies --wait, so this call blocks until the
# user clicks an action, dismisses the notification, or it expires. Some
# desktops (GNOME among them) ignore --expire-time when actions are present,
# so we wrap the call in an explicit `timeout` as a safety net to prevent
# orphan background processes from piling up if the user never clicks.
if [ "$EXPIRE_MS" -gt 0 ] 2>/dev/null; then
  TIMEOUT_SEC=$(( EXPIRE_MS / 1000 + 30 ))
else
  TIMEOUT_SEC=600
fi

RESULT=$(timeout --signal=TERM "${TIMEOUT_SEC}s" notify-send \
  --app-name="Claude" \
  --urgency="$URGENCY" \
  --expire-time="$EXPIRE_MS" \
  -A "open=Open session" \
  "$TITLE" \
  "$BODY" 2>/dev/null)

# RESULT values we expect:
#   "open"   user clicked the Open action button (or, on GNOME Shell, the
#            notification body — body clicks fire the first action)
#   ""       expired / dismissed without clicking an action
[ "$RESULT" != "open" ] && exit 0
[ -z "$TARGET" ] && exit 0

# Switch tmux to the target window. Use -t with session:window-index since
# pane ids (%NN) can be reused after detach.
tmux select-window -t "$TARGET" 2>/dev/null || true

# Raise the X11 window of the terminal emulator holding the tmux client so
# the user actually sees the switch. Skipped silently if not on X11 or if
# xdotool / wmctrl is missing.
if [ -n "${DISPLAY:-}" ]; then
  CLIENT_TTY=$(tmux list-clients -F '#{client_tty}' 2>/dev/null | head -1)
  if [ -n "$CLIENT_TTY" ]; then
    CLIENT_PID=$(ps -t "${CLIENT_TTY##*/}" -o pid= 2>/dev/null | head -1 | tr -d ' ')
    # Walk up the parent chain until we find the terminal emulator process.
    P="$CLIENT_PID"
    TERM_PID=""
    for _ in 1 2 3 4 5 6; do
      [ -z "$P" ] && break
      PARENT=$(ps -o ppid= -p "$P" 2>/dev/null | tr -d ' ')
      NAME=$(ps -o comm= -p "${PARENT:-0}" 2>/dev/null)
      case "$NAME" in
        gnome-terminal*|x-terminal-emul|konsole|xterm|alacritty|kitty|tilix|terminator|wezterm-gui)
          TERM_PID="$PARENT"
          break
          ;;
      esac
      [ "$PARENT" = "1" ] || [ -z "$PARENT" ] && break
      P="$PARENT"
    done

    if [ -n "$TERM_PID" ] && command -v xdotool >/dev/null 2>&1; then
      WID=$(xdotool search --pid "$TERM_PID" 2>/dev/null | head -1)
      [ -n "$WID" ] && xdotool windowactivate "$WID" 2>/dev/null || true
    fi
  fi
fi

exit 0
