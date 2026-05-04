#!/bin/zsh
# CO Apps Meeting Reminder -- Tuesday 3:00 PM SGT -> Lark
# Sends a simple reminder with Google Meet link
set -uo pipefail

ENV_FILE="$HOME/.config/agents.env"; [[ -r "$ENV_FILE" ]] || ENV_FILE="$HOME/Documents/New project/.env"
LOG_FILE="$HOME/.local/log/co-apps-meeting.log"
STATE_FILE="$HOME/.local/share/co-apps-meeting/state.json"
TODAY=$(date '+%Y-%m-%d')

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [reminder] $1" >> "$LOG_FILE"; }
log "Starting CO Apps meeting reminder"

# Load env
set -a; source "$ENV_FILE"; set +a

# Count outstanding action items
OUTSTANDING=0
if [[ -f "$STATE_FILE" ]]; then
  OUTSTANDING=$(python3 -c "
import json
d = json.load(open('$STATE_FILE'))
print(len([a for a in d.get('action_items', []) if a.get('status') != 'done']))
" 2>/dev/null || echo 0)
fi

# Build reminder text
if [[ "$OUTSTANDING" -gt 0 ]]; then
  ACTION_LINE="We have **${OUTSTANDING} action item(s)** to follow up on from last week."
else
  ACTION_LINE="No outstanding items from last week -- clean slate!"
fi

REMINDER_TEXT="Hey team! Our weekly CO Apps catch-up is in **1 hour**.

**When:** 4:00 - 5:00 PM SGT (today)
**Where:** [Click here to join Google Meet](https://meet.google.com/igs-arbe-ntm)

${ACTION_LINE}

The full agenda will be posted here at 3:30 PM -- see you soon!"

# Send to Lark (soft-fail on curl/payload errors so launchd reports exit 0)
if [[ -z "${LARK_CO_APPS_WEBHOOK:-}" ]]; then
  log "WARN: LARK_CO_APPS_WEBHOOK unset, skipping Lark send"
else
  curl -s -X POST "$LARK_CO_APPS_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "$(cat <<PAYLOAD
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {
        "tag": "plain_text",
        "content": "CO Apps Weekly Catch-Up -- Today at 4 PM"
      },
      "template": "purple"
    },
    "elements": [
      {
        "tag": "markdown",
        "content": $(echo "$REMINDER_TEXT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '"(reminder text encode failed)"')
      },
      {
        "tag": "action",
        "actions": [
          {
            "tag": "button",
            "text": {
              "tag": "plain_text",
              "content": "Join Google Meet"
            },
            "url": "https://meet.google.com/igs-arbe-ntm",
            "type": "primary"
          }
        ]
      }
    ]
  }
}
PAYLOAD
)" > /dev/null 2>&1 || log "WARN: Lark curl failed (non-fatal)"
fi

log "Reminder sent successfully"
echo "CO Apps meeting reminder sent: $TODAY"
exit 0
