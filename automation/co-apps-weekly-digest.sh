#!/bin/zsh
# CO Apps Weekly Email Digest -- Friday 5:00 PM SGT
# Sends a summary email of the week's progress to stakeholders
set -euo pipefail

ENV_FILE="$HOME/.config/agents.env"; [[ -r "$ENV_FILE" ]] || ENV_FILE="$HOME/Documents/New project/.env"
LOG_FILE="$HOME/.local/log/co-apps-meeting.log"
STATE_FILE="$HOME/.local/share/co-apps-meeting/state.json"
# A deferred rerun pins the date, so a digest finished after midnight keeps Friday's title.
TODAY="${CO_APPS_DIGEST_DATE:-$(date '+%Y-%m-%d')}"
# The fleet wrapper exits 75 on a usage limit; CLAUDE_BIN overrides it for a stub test.
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude-resilient.sh}"
SINCE=$(date -v-7d '+%Y-%m-%dT00:00:00Z')

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [digest] $1" >> "$LOG_FILE"; }
log "Starting weekly email digest"

set -a; source "$ENV_FILE"; set +a

REPOS=(
  "leotansingapore/hourhive-buddy"
  "leotansingapore/catalyst-opus"
  "leotansingapore/outsource-sales-portal-magic"
  "leotansingapore/catalyst-refresh-glow"
  "leotansingapore/partner-hub-40"
  "leotansingapore/tavus-talent-spotter-15b98171"
)

# Temp dir
TMPDIR_DIGEST=$(mktemp -d)
trap "rm -rf $TMPDIR_DIGEST" EXIT

# Gather data
echo "=== CO APPS WEEKLY DIGEST ===" > "$TMPDIR_DIGEST/context.txt"
echo "Week ending: $TODAY" >> "$TMPDIR_DIGEST/context.txt"
echo "" >> "$TMPDIR_DIGEST/context.txt"

TOTAL_COMMITS=0
for REPO in "${REPOS[@]}"; do
  REPO_NAME="${REPO#*/}"
  COMMITS=$(gh api "repos/${REPO}/commits?since=${SINCE}&per_page=50" \
    --jq '.[] | "- \(.commit.message | split("\n")[0]) (\(.commit.author.name))"' 2>/dev/null || echo "")
  ISSUES=$(gh api "repos/${REPO}/issues?state=open&per_page=10" \
    --jq '.[] | select(.pull_request == null) | "- #\(.number): \(.title)"' 2>/dev/null || echo "")

  COUNT=0
  if [[ -n "$COMMITS" ]]; then
    COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
    TOTAL_COMMITS=$((TOTAL_COMMITS + COUNT))
  fi

  echo "--- $REPO_NAME ($COUNT commits) ---" >> "$TMPDIR_DIGEST/context.txt"
  if [[ -n "$COMMITS" ]]; then
    echo "$COMMITS" >> "$TMPDIR_DIGEST/context.txt"
  else
    echo "(no activity)" >> "$TMPDIR_DIGEST/context.txt"
  fi
  if [[ -n "$ISSUES" ]]; then
    echo "Open issues:" >> "$TMPDIR_DIGEST/context.txt"
    echo "$ISSUES" >> "$TMPDIR_DIGEST/context.txt"
  fi
  echo "" >> "$TMPDIR_DIGEST/context.txt"
  sleep 1
done

# Action items status
if [[ -f "$STATE_FILE" ]]; then
  python3 -c "
import json
d = json.load(open('$STATE_FILE'))
items = d.get('action_items', [])
done = len([a for a in items if a.get('status') == 'done'])
open_items = len([a for a in items if a.get('status') != 'done'])
print(f'Action items: {done} completed, {open_items} still open')
for a in items:
    if a.get('status') != 'done':
        print(f'  - [{a.get(\"repo\",\"general\")}] {a.get(\"title\",\"\")} ({a.get(\"assignee\",\"unassigned\")})')
" >> "$TMPDIR_DIGEST/context.txt" 2>/dev/null
fi

# Generate digest via Claude (soft-fail on CLI error so launchd reports success)
DIGEST=$("$CLAUDE_BIN" -p --model sonnet "$(cat "$TMPDIR_DIGEST/context.txt")

Write a professional weekly progress email for the CO Apps ecosystem. This goes to stakeholders who want a high-level overview. Format as plain text email (no markdown).

Structure:
- Subject line suggestion
- 2-3 sentence executive summary
- Per-app highlights (2-3 bullets each, plain language not commit messages)
- Key metrics: total commits, active repos, outstanding items
- What to watch next week

Keep it under 30 lines. Professional but not formal. No technical jargon." 2>>"$LOG_FILE") || {
  RC=$?
  # A usage limit defers the digest instead of posting the raw-context fallback, so stakeholders get one real digest.
  if [[ $RC -eq 75 ]]; then
    log "DEFERRED: Claude usage limit; claude-deferred-retry reruns the $TODAY digest"
    "$HOME/.local/bin/claude-defer-mark" co-apps-weekly-digest "CO_APPS_DIGEST_DATE=$TODAY $HOME/.local/bin/co-apps-weekly-digest.sh"
    exit 0
  fi
  DIGEST="Claude CLI unavailable -- raw context follows:

$(cat "$TMPDIR_DIGEST/context.txt")"
}

if [[ -z "$DIGEST" ]]; then
  log "WARN: Empty digest, using raw context"
  DIGEST=$(cat "$TMPDIR_DIGEST/context.txt")
fi

log "Digest generated (${#DIGEST} chars)"

# Send to Lark as the digest (stakeholders are on Lark)
LARK_TEXT="$DIGEST"

curl -s -X POST "$LARK_CO_APPS_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "$(cat <<PAYLOAD
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {
        "tag": "plain_text",
        "content": "CO Apps Weekly Digest -- Week of $TODAY"
      },
      "template": "blue"
    },
    "elements": [
      {
        "tag": "markdown",
        "content": $(echo "$LARK_TEXT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
      }
    ]
  }
}
PAYLOAD
)" > /dev/null 2>&1

log "Weekly digest sent"

# Sync dashboard repo with latest scripts
"$HOME/.local/bin/co-apps-sync-dashboard.sh" 2>> "$LOG_FILE" || log "Dashboard sync failed (non-fatal)"

echo "CO Apps weekly digest sent: $TODAY"
