# claude-tmux-notifier

Desktop notifications for [Claude Code](https://claude.com/claude-code) that tell you **which tmux window** finished a task or needs your input, and **what you asked it to do**, so juggling many parallel Claude sessions stops being a guessing game.

Without this plugin, every Claude session pops the same generic toast:

```
Claude Code
Task completed or input needed
```

With this plugin:

```
Claude [build-pipeline terminal session]
✅ Run the integration tests on the staging cluster

Claude [auth-refactor terminal session]
⏳ Permission needed for Bash(rm tmp/old_session_*)
```

You can finally tell **which** of your six Claude tabs is asking for permission, and **which** prompt it just finished — all from the OS notification, without switching to the terminal.

## Features

- **tmux window name in every notification** — taken from the pane Claude is actually running in (`tmux display-message`)
- **Last user prompt embedded in the completion toast** — extracted from the session transcript, truncated to 30 characters
- **Two distinct severities**:
  - `Stop` hook → `normal` urgency, auto-dismisses after 8 seconds
  - `Notification` hook (permission / input prompts) → `critical` urgency, stays until you click it
- **Tool result and system-reminder messages are filtered out** when picking the "last user prompt" — you only see what you actually typed
- **Graceful fallback** when run outside tmux: notification title degrades to plain `Claude` instead of breaking

## Requirements

- Linux desktop with a notification daemon that handles `notify-send` (GNOME Shell, KDE Plasma, dunst, mako, …)
- `tmux` (optional — without it the window-name segment is just omitted)
- `jq` (used to parse the hook stdin JSON and the session transcript)
- [Claude Code](https://claude.com/claude-code) CLI installed

Install the prerequisites on Ubuntu/Debian:

```bash
sudo apt install libnotify-bin tmux jq
```

## Install

### Option A — one-line install script (recommended)

```bash
git clone https://github.com/yeodonghyeon1/claude-tmux-notifier.git
cd claude-tmux-notifier
./install.sh
```

The script copies the two hook scripts into `~/.claude/hooks/` and prints the exact JSON snippet to paste into `~/.claude/settings.json`. Then open `/hooks` once inside Claude Code (or restart the session) so the config watcher reloads.

### Option B — manual install

1. Clone the repo anywhere.
2. Copy (or symlink) the two scripts into `~/.claude/hooks/`:
   ```bash
   install -m 0755 hooks/tmux-notify-stop.sh  ~/.claude/hooks/
   install -m 0755 hooks/tmux-notify-input.sh ~/.claude/hooks/
   ```
3. Merge this into your `~/.claude/settings.json` (preserve anything else under `hooks`):
   ```json
   {
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
   }
   ```
4. Open `/hooks` in Claude Code or restart so the new config is loaded.

### Verifying it works

End the next Claude turn and watch for a notification titled `Claude [<your tmux window name> terminal session]`. If you see the old generic title, the settings watcher hasn't picked up the new config yet — opening `/hooks` once is enough to force a reload.

You can also fire the hook directly:

```bash
echo '{}' | ~/.claude/hooks/tmux-notify-stop.sh
```

## How it works

Claude Code fires lifecycle hooks for every session. This plugin registers two of them:

| Event | When it fires | What this plugin does |
|------:|:--------------|:----------------------|
| `Stop` | Claude finishes responding | Reads `transcript_path` from the hook input, scans the JSONL backwards for the most recent `type=="user"` message whose `content` is a string and doesn't start with `<` (filters out tool results and system reminders), takes its first line, truncates to 30 characters, and shows a `normal` toast |
| `Notification` | A permission prompt or input request is waiting | Pulls the `message` field from stdin (e.g. `"Permission needed for Bash(rm …)"`) and shows a `critical` toast that stays on screen until clicked |

Both scripts call `tmux display-message -t "$TMUX_PANE" -p -F '#W'` to get the name of the pane Claude is actually running in — not whatever window happens to be focused. If `$TMUX_PANE` is unset (Claude running outside tmux), the title falls back to plain `Claude`.

## Customizing

The two scripts are short and have no exotic dependencies — open them up and edit.

### Change the title format

In both `hooks/tmux-notify-stop.sh` and `hooks/tmux-notify-input.sh`:

```bash
"Claude${W:+ [$W terminal session]}"
```

Replace `terminal session` with whatever suffix you want, or drop it entirely:

```bash
"Claude${W:+ [$W]}"
```

### Change the prompt-preview length

In `hooks/tmux-notify-stop.sh`, the jq pipeline ends with:

```jq
| if length > 30 then .[0:30] + "…" else . end
```

Change `30` to taste. Long previews can wrap awkwardly in GNOME Shell, so 30–60 characters is a sweet spot.

### Change urgency or timeout

The `notify-send` calls at the bottom of each script accept the usual flags:

```bash
notify-send -u normal   -t 8000   ...   # Stop
notify-send -u critical            ...   # Notification (sticky until clicked)
```

- `-u low|normal|critical` — controls visual priority and (for `critical`) auto-dismiss behavior
- `-t <milliseconds>` — auto-dismiss delay; `0` means never auto-dismiss

### Use a different transcript filter

The "last user prompt" is extracted by this jq filter (in `tmux-notify-stop.sh`):

```jq
map(select(
  .type == "user"
  and (.message.content | type == "string")
  and ((.message.content | startswith("<")) | not)
))
| (last // empty)
| .message.content
| split("\n")[0]
| if length > 30 then .[0:30] + "…" else . end
```

If you want to include hook-feedback or system messages too, drop the `startswith("<")` check. If you want the whole multi-line prompt, drop `split("\n")[0]`.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Title is still `Claude Code` / `Task completed or input needed` | Settings watcher hasn't reloaded. Open `/hooks` inside Claude Code once, or restart the session. |
| Window-name segment is missing in the title | `$TMUX_PANE` not set in the hook's environment — verify Claude was launched from inside tmux. |
| Wrong window name shown | You're inside a nested tmux session and the hook is reading the outer pane. Use only one level of tmux, or override `TMUX` in your shell init. |
| No prompt preview, only `✅ Task complete` | Either the hook's stdin doesn't have `transcript_path` (older Claude Code) or `jq` isn't installed. |
| Permission notification doesn't stay on screen | Your notification daemon doesn't honor `--urgency=critical`. dunst and GNOME Shell do; some minimal stacks don't. |
| Notification works in interactive shell but not from systemd / IDE | `DBUS_SESSION_BUS_ADDRESS` not propagated to the Claude process — launch Claude from a regular desktop terminal. |

## What this plugin does not do

- **No mobile push.** This is local desktop only. For phone push notifications, use Claude Code's built-in `inputNeededNotifEnabled` / `agentPushNotifEnabled` settings.
- **No remote sessions.** If you run Claude over SSH, the hook fires on the remote machine — install `libnotify-bin` and a notification forwarder there, or use the built-in mobile push instead.
- **No auto-registration.** Claude Code plugins don't (yet) auto-register hooks into your settings.json. Hence the install script / manual snippet step.

## Why I wrote this

Running 8–12 Claude sessions in parallel across tmux windows is great until they all start asking for permission with identical-looking toasts. Once you start mistaking the auth refactor's `rm` for the test pipeline's `rm`, you start denying everything reflexively — which means you stop trusting the prompt, which means you stop trusting Claude. Showing the source pane and the original task in the toast fixes that.

## Contributing

Bug reports and small PRs welcome. Larger changes — please open an issue first.

## License

MIT — see [LICENSE](LICENSE).
