#!/usr/bin/env bash
# Notification hook: 권한 요청/입력 대기 시 tmux 윈도우 이름과 함께 알림.
# stdin: { "hook_event_name": "Notification", "message": "...", "session_id": "..." }
#
# critical 긴급도로 alarm-style. 클릭하면 그 tmux 윈도우로 전환되도록
# tmux-notify-bg.sh 를 nohup으로 spawn (hook 즉시 반환).

set -eu

INPUT=$(cat)

PANE_ID="${TMUX_PANE:-}"
W=$(tmux display-message -t "$PANE_ID" -p -F '#W' 2>/dev/null || true)
TARGET=$(tmux display-message -t "$PANE_ID" -p -F '#S:#I' 2>/dev/null || true)
MSG=$(echo "$INPUT" | jq -r '.message // "입력 대기"' 2>/dev/null || echo "입력 대기")

TITLE="Claude${W:+ [$W 터미널 세션]}"
BODY="⏳ ${MSG}"

# critical 은 GNOME에서 자동 사라짐 X. expire-time 0 → bg 스크립트가 10분 watchdog.
nohup ~/.claude/hooks/tmux-notify-bg.sh \
  "critical" "0" \
  "$TITLE" "$BODY" "$TARGET" \
  </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
