#!/usr/bin/env bash
# Stop hook: Claude 응답 완료 시 tmux 윈도우 이름 + 직전 사용자 질의 알림.
# stdin: {"session_id":"...","transcript_path":"...","stop_hook_active":false}
#
# 알림을 클릭하면 그 tmux 윈도우로 자동 전환되도록, 실제 알림 표시는
# tmux-notify-bg.sh 로 nohup spawn 한다. 그래서 이 hook은 즉시 반환한다.

set -eu

INPUT=$(cat)

PANE_ID="${TMUX_PANE:-}"
# 현재 tmux 윈도우 이름 + select-window용 타겟(session:window-index).
W=$(tmux display-message -t "$PANE_ID" -p -F '#W' 2>/dev/null || true)
TARGET=$(tmux display-message -t "$PANE_ID" -p -F '#S:#I' 2>/dev/null || true)

# 트랜스크립트에서 직전 사용자 질의 추출 (30자 컷).
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
PROMPT=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  PROMPT=$(jq -rs '
    map(select(
      .type == "user"
      and (.message.content | type == "string")
      and ((.message.content | startswith("<")) | not)
    ))
    | (last // empty)
    | .message.content
    | split("\n")[0]
    | if length > 30 then .[0:30] + "…" else . end
  ' "$TRANSCRIPT" 2>/dev/null || echo "")
fi

BODY="✅ 작업 완료"
[ -n "$PROMPT" ] && BODY="✅ $PROMPT"
TITLE="Claude${W:+ [$W 터미널 세션]}"

# 백그라운드로 분리. hook은 즉시 반환.
nohup ~/.claude/hooks/tmux-notify-bg.sh \
  "normal" "8000" \
  "$TITLE" "$BODY" "$TARGET" \
  </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
