#!/usr/bin/env bash
# Copy hook scripts into ~/.claude/hooks/ and print the settings.json snippet
# you need to paste. Idempotent — safe to re-run.

set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
DEST=${CLAUDE_HOOKS_DIR:-$HOME/.claude/hooks}

mkdir -p "$DEST"
install -m 0755 "$REPO_DIR/hooks/tmux-notify-stop.sh"  "$DEST/"
install -m 0755 "$REPO_DIR/hooks/tmux-notify-input.sh" "$DEST/"
# Clean up any leftover bg.sh from older versions (≤ v0.2.x) that had
# the click-to-jump action button. Safe to remove unconditionally.
rm -f "$DEST/tmux-notify-bg.sh"

echo
echo "Hook scripts installed to: $DEST"
echo
echo "Now add the following to ~/.claude/settings.json (merge with any existing 'hooks' object):"
echo "─────────────────────────────────────────────────────────────────────────"
cat <<'EOF'
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/tmux-notify-stop.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/tmux-notify-input.sh" }
        ]
      }
    ]
  }
EOF
echo "─────────────────────────────────────────────────────────────────────────"
echo
echo "Then open /hooks in Claude Code once (or restart) so the watcher reloads."
