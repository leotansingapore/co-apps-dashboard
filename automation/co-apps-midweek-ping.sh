#!/bin/zsh
# CO Apps Mid-Week Progress Ping -- Thursday 10:00 AM SGT -> Lark
# Checks GitHub activity since Tuesday meeting and pings the team
set -euo pipefail

REPOS=(
  "leotansingapore/hourhive-buddy"
  "leotansingapore/catalyst-opus"
  "leotansingapore/outsource-sales-portal-magic"
  "leotansingapore/catalyst-refresh-glow"
  "leotansingapore/partner-hub-40"
)

ENV_FILE="$HOME/.config/agents.env"; [[ -r "$ENV_FILE" ]] || ENV_FILE="$HOME/Documents/New project/.env"
STATE_FILE="$HOME/.local/share/co-apps-meeting/state.json"
LOG_FILE="$HOME/.local/log/co-apps-meeting.log"
TODAY=$(date '+%Y-%m-%d')
SINCE=$(date -v-2d '+%Y-%m-%dT00:00:00Z')  # Since Tuesday

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [midweek] $1" >> "$LOG_FILE"; }
log "Starting mid-week progress ping"

set -a; source "$ENV_FILE"; set +a

# Fetch activity per repo
ACTIVITY=""
TOTAL_COMMITS=0
ACTIVE_REPOS=0
STALE_REPOS=""

for REPO in "${REPOS[@]}"; do
  REPO_NAME="${REPO#*/}"
  COMMITS=$(gh api "repos/${REPO}/commits?since=${SINCE}&per_page=20" \
    --jq '.[] | .commit.message | split("\n")[0]' 2>/dev/null || echo "")

  if [[ -n "$COMMITS" ]]; then
    COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
    TOTAL_COMMITS=$((TOTAL_COMMITS + COUNT))
    ACTIVE_REPOS=$((ACTIVE_REPOS + 1))
    TOP3=$(echo "$COMMITS" | head -3 | sed 's/^/  - /')
    ACTIVITY="${ACTIVITY}
**[${REPO_NAME}](https://github.com/${REPO})** -- ${COUNT} commits since Tuesday
${TOP3}
"
  else
    STALE_REPOS="${STALE_REPOS}
- [${REPO_NAME}](https://github.com/${REPO})"
  fi
  sleep 1
done

# Count outstanding action items
OUTSTANDING=0
if [[ -f "$STATE_FILE" ]]; then
  OUTSTANDING=$(python3 -c "
import json
d = json.load(open('$STATE_FILE'))
print(len([a for a in d.get('action_items', []) if a.get('status') != 'done']))
" 2>/dev/null || echo 0)
fi

# Check open meeting-action issues
OPEN_ISSUES=$(gh search issues --label meeting-action --state open --owner leotansingapore --json repository,title \
  --jq '.[] | "- \(.repository.name): \(.title)"' 2>/dev/null | head -5 || echo "")

# Build message
MSG="Hey team! Quick mid-week check-in.

**Since Tuesday's meeting:** ${TOTAL_COMMITS} commits across ${ACTIVE_REPOS} repos.
${ACTIVITY}"

if [[ -n "$STALE_REPOS" ]]; then
  MSG="${MSG}
**No activity since Tuesday:**${STALE_REPOS}
"
fi

if [[ "$OUTSTANDING" -gt 0 ]]; then
  MSG="${MSG}
**${OUTSTANDING} action item(s)** still open from Tuesday's meeting."
fi

if [[ -n "$OPEN_ISSUES" ]]; then
  MSG="${MSG}

**Open meeting-action issues:**
${OPEN_ISSUES}"
fi

MSG="${MSG}

Keep it up! Next meeting is Tuesday 4 PM."

# Send to Lark
curl -s -X POST "$LARK_CO_APPS_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "$(cat <<PAYLOAD
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {
        "tag": "plain_text",
        "content": "CO Apps Mid-Week Check-In"
      },
      "template": "turquoise"
    },
    "elements": [
      {
        "tag": "markdown",
        "content": $(echo "$MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
      }
    ]
  }
}
PAYLOAD
)" > /dev/null 2>&1

log "Mid-week ping sent ($TOTAL_COMMITS commits, $ACTIVE_REPOS active repos)"

# Refresh dashboard with latest week-in-progress state
"$HOME/.local/bin/co-apps-sync-dashboard.sh" 2>> "$LOG_FILE" || log "Dashboard sync failed (non-fatal)"

echo "CO Apps mid-week ping sent: $TODAY"
