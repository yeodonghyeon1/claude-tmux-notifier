#!/usr/bin/env bash
# Stop hook: Claude 응답 완료 시 tmux 윈도우 이름 + 직전 사용자 질의 알림.
# stdin: {"session_id":"...","transcript_path":"...","stop_hook_active":false}

set -eu

INPUT=$(cat)

# 현재 claude가 실행 중인 tmux pane의 윈도우 이름.
W=$(tmux display-message -t "${TMUX_PANE:-}" -p -F '#W' 2>/dev/null || true)

# 트랜스크립트에서 직전 사용자 질의 추출.
# - type=="user" + content가 string (tool_result array 제외)
# - "<"로 시작하는 것 제외 (system-reminder 등)
# - 멀티라인이면 첫 줄만, 80자 초과면 잘라서 "…" 붙임
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
if [ -n "$PROMPT" ]; then
  BODY="✅ $PROMPT"
fi

notify-send -u normal -t 8000 \
  "Claude${W:+ [$W 터미널 세션]}" \
  "$BODY" 2>/dev/null || true
