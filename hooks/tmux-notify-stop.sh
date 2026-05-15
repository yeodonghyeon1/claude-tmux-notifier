#!/usr/bin/env bash
# Stop hook: Claude 응답 완료 시 tmux 윈도우 이름 + 직전 사용자 질의 알림.
# stdin: {"session_id":"...","transcript_path":"...","stop_hook_active":false}

set -eu

INPUT=$(cat)

# 현재 claude가 실행 중인 tmux pane의 윈도우 이름. tmux 밖이면 빈 문자열.
W=$(tmux display-message -t "${TMUX_PANE:-}" -p -F '#W' 2>/dev/null || true)

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

notify-send -u normal -t 8000 \
  "Claude${W:+ [$W 터미널 세션]}" \
  "$BODY" 2>/dev/null || true
