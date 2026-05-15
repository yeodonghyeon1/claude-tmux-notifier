#!/usr/bin/env bash
# Notification hook: 권한 요청/입력 대기 시 tmux 윈도우 이름과 함께 알림.
# stdin: { "hook_event_name": "Notification", "message": "...", "session_id": "..." }

set -eu

INPUT=$(cat)
W=$(tmux display-message -t "${TMUX_PANE:-}" -p -F '#W' 2>/dev/null || true)
MSG=$(echo "$INPUT" | jq -r '.message // "입력 대기"' 2>/dev/null || echo "입력 대기")

# critical은 사용자가 닫기 전까지 화면에 남음 (입력이 필요하므로 시급).
notify-send -u critical \
  "Claude${W:+ [$W 터미널 세션]}" \
  "⏳ ${MSG}" 2>/dev/null || true
