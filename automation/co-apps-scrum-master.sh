#!/bin/zsh
# CO Apps Scrum Master -- Tuesday 3:30 PM SGT -> Lark
# Fetches GitHub activity from 5 repos, generates weekly agenda via Claude CLI
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
SINCE=$(date -v-7d '+%Y-%m-%dT00:00:00Z')

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [scrum] $1" >> "$LOG_FILE"; }
log "Starting CO Apps scrum master report"

# Load env
set -a; source "$ENV_FILE"; set +a

# Temp dir with cleanup
TMPDIR_REPORT=$(mktemp -d)
trap "rm -rf $TMPDIR_REPORT" EXIT

# ── 1. Fetch GitHub data per repo ─────────────────────────────────
echo "=== CO APPS WEEKLY STATUS ===" > "$TMPDIR_REPORT/context.txt"
echo "Report date: $TODAY" >> "$TMPDIR_REPORT/context.txt"
echo "Period: last 7 days (since $SINCE)" >> "$TMPDIR_REPORT/context.txt"
echo "" >> "$TMPDIR_REPORT/context.txt"

TOTAL_COMMITS=0

for REPO in "${REPOS[@]}"; do
  REPO_NAME="${REPO#*/}"
  log "Fetching data for $REPO_NAME"

  echo "--- REPO: $REPO_NAME (https://github.com/${REPO}) ---" >> "$TMPDIR_REPORT/context.txt"

  # Recent commits
  COMMITS=$(gh api "repos/${REPO}/commits?since=${SINCE}&per_page=50" \
    --jq '.[] | "- \(.commit.message | split("\n")[0]) (\(.commit.author.name), \(.commit.author.date[:10]))"' 2>/dev/null || echo "")

  if [[ -n "$COMMITS" ]]; then
    COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
    TOTAL_COMMITS=$((TOTAL_COMMITS + COMMIT_COUNT))
    echo "Commits ($COMMIT_COUNT):" >> "$TMPDIR_REPORT/context.txt"
    echo "$COMMITS" >> "$TMPDIR_REPORT/context.txt"
  else
    echo "Commits: None in last 7 days" >> "$TMPDIR_REPORT/context.txt"
  fi

  # Open PRs
  OPEN_PRS=$(gh pr list --repo "$REPO" --state open --json number,title,author \
    --jq '.[] | "- #\(.number): \(.title) (@\(.author.login))"' 2>/dev/null || echo "")
  if [[ -n "$OPEN_PRS" ]]; then
    echo "Open PRs:" >> "$TMPDIR_REPORT/context.txt"
    echo "$OPEN_PRS" >> "$TMPDIR_REPORT/context.txt"
  fi

  # Open issues (exclude PRs)
  OPEN_ISSUES=$(gh api "repos/${REPO}/issues?state=open&per_page=20" \
    --jq '.[] | select(.pull_request == null) | "- #\(.number): \(.title) [\(.labels | map(.name) | join(", "))]"' 2>/dev/null || echo "")
  if [[ -n "$OPEN_ISSUES" ]]; then
    echo "Open Issues:" >> "$TMPDIR_REPORT/context.txt"
    echo "$OPEN_ISSUES" >> "$TMPDIR_REPORT/context.txt"
  fi

  # Staleness check
  PUSHED_AT=$(gh repo view "$REPO" --json pushedAt --jq '.pushedAt' 2>/dev/null || echo "")
  if [[ -n "$PUSHED_AT" ]]; then
    echo "Last push: $PUSHED_AT" >> "$TMPDIR_REPORT/context.txt"
    # Flag stale repos (>5 days)
    PUSH_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${PUSHED_AT}" "+%s" 2>/dev/null || echo "0")
    NOW_EPOCH=$(date "+%s")
    DAYS_AGO=$(( (NOW_EPOCH - PUSH_EPOCH) / 86400 ))
    if [[ $DAYS_AGO -gt 5 ]]; then
      echo "** STALE: No activity for ${DAYS_AGO} days **" >> "$TMPDIR_REPORT/context.txt"
    fi
  fi

  echo "" >> "$TMPDIR_REPORT/context.txt"
  sleep 1  # Rate limit buffer
done

log "Fetched data for ${#REPOS[@]} repos ($TOTAL_COMMITS total commits)"

# Save repo status snapshot for Excalidraw updater
python3 << 'PYEOF' > "$TMPDIR_REPORT/repo_status.json"
import json, subprocess
from datetime import datetime, timezone

repos = [
    ("hourhive-buddy", "VA Analytics & Integrations", "Jilian Garette"),
    ("catalyst-opus", "Task Management Platform", "Warren Apit"),
    ("outsource-sales-portal-magic", "Sales Portal", "Lovable Bot"),
    ("catalyst-refresh-glow", "Marketing Website", "Lovable Bot"),
    ("partner-hub-40", "Partner Hub", "Lovable Bot"),
]
results = []
for name, desc, contributor in repos:
    full = f"leotansingapore/{name}"
    try:
        r = subprocess.run(["gh", "repo", "view", full, "--json", "pushedAt", "--jq", ".pushedAt"], capture_output=True, text=True, timeout=15)
        pushed = r.stdout.strip()[:10] if r.stdout.strip() else "unknown"
        days = (datetime.now(timezone.utc).date() - datetime.fromisoformat(pushed).date()).days if pushed != "unknown" else 999
    except:
        pushed, days = "unknown", 999
    try:
        r = subprocess.run(["gh", "api", f"repos/{full}/issues?state=open&per_page=100", "--jq", "[.[] | select(.pull_request == null)] | length"], capture_output=True, text=True, timeout=15)
        issues = int(r.stdout.strip()) if r.stdout.strip() else 0
    except:
        issues = 0
    results.append({"name": name, "desc": desc, "contributor": contributor, "pushed": pushed, "days_ago": days, "issues": issues, "status": "stale" if days > 5 else "active"})
print(json.dumps(results))
PYEOF
cp "$TMPDIR_REPORT/repo_status.json" "$HOME/.local/share/co-apps-meeting/repo_status.json"

# ── 2. Load previous action items ─────────────────────────────────
if [[ -f "$STATE_FILE" ]]; then
  PREV_ACTIONS=$(python3 -c "
import json
d = json.load(open('$STATE_FILE'))
items = [a for a in d.get('action_items', []) if a.get('status') != 'done']
if items:
    print('OUTSTANDING ACTION ITEMS FROM PREVIOUS MEETING:')
    for a in items:
        repo = a.get('repo', 'general')
        title = a.get('title', 'No title')
        issue = a.get('issue_number', '')
        assignee = a.get('assignee', 'unassigned')
        status = a.get('status', 'open')
        issue_str = f' (#{issue})' if issue else ''
        print(f'- [{repo}] {title}{issue_str} -- {assignee} ({status})')
else:
    print('No outstanding action items from previous meeting.')
" 2>/dev/null || echo "No action item history available.")
  echo "$PREV_ACTIONS" >> "$TMPDIR_REPORT/context.txt"
fi

# ── 3. Generate agenda via Claude CLI ──────────────────────────────
log "Generating agenda via Claude CLI"

AGENDA=$(claude -p --model sonnet "$(cat "$TMPDIR_REPORT/context.txt")

You are a scrum master preparing a weekly meeting agenda for the CO Apps team. Based on the GitHub activity above, write a concise weekly agenda with these exact sections (use ** for bold headings, no # headers, no code blocks):

IMPORTANT: When mentioning a repo name, always hyperlink it using Lark markdown format: [repo-name](https://github.com/leotansingapore/repo-name). For example: [catalyst-opus](https://github.com/leotansingapore/catalyst-opus).

**Per-Repo Progress**
For each of the 5 repos, write 1-3 bullet points summarizing what was accomplished this week. Group by themes (features, fixes, integrations). Name contributors where visible. Hyperlink each repo name.

**Stale Repos**
Flag any repos with no activity in 5+ days. Suggest whether to discuss or deprioritize.

**Open Blockers**
List all open issues and PRs across repos. Highlight bugs and blocked items.

**Outstanding Action Items**
List any action items carried over from last week (from the data above).

**Discussion Points**
Suggest 3-5 discussion topics based on patterns in the activity (e.g. cross-repo alignment, shared features, deployment status).

**Proposed Focus This Week**
For each repo, suggest 1-2 priorities based on current momentum and open issues.

Keep the entire agenda under 60 lines. Be direct, no fluff. Use bullet points. Format for Lark markdown (supports **bold** and bullet lists with -).")

log "Agenda generated (${#AGENDA} chars)"

# ── 3.5. Update Google Sheet with meeting template ─────────────────
log "Updating Google Sheet"
SHEET_URL=$(cd "$HOME/Documents/New project" && python3 "$HOME/.local/bin/co-apps-meeting-sheet.py" 2>/dev/null || echo "")
if [[ -n "$SHEET_URL" ]]; then
  log "Google Sheet updated: $SHEET_URL"
else
  log "Google Sheet update failed (non-fatal)"
  SHEET_URL="https://docs.google.com/spreadsheets/d/1HaT_811PWs-4p-uc4VUM-i6PYLRbwV0YHjt8DjWfIiM"
fi

# ── 3.6. Pre-fill sheet with GitHub commit summaries ──────────────
log "Pre-filling sheet with GitHub activity"
cd "$HOME/Documents/New project" && python3 << 'PYEOF' 2>> "$LOG_FILE" || log "Sheet pre-fill failed (non-fatal)"
import json, subprocess, sys, os
sys.path.insert(0, os.path.join(os.environ["HOME"], "Documents/New project/tools"))
from lib.sheets import get_sheets_client
from datetime import datetime, timedelta

sheet_id = open(os.path.join(os.environ["HOME"], ".local/share/co-apps-meeting/sheet_id.txt")).read().strip()
today = datetime.now().strftime("%Y-%m-%d")
since = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%dT00:00:00Z")

gc = get_sheets_client()
ss = gc.open_by_key(sheet_id)
ws = ss.worksheet(today)
all_vals = ws.get_all_values()

# Map contributors to apps
contributor_map = {
    "jilian garette": ("Jilian", "HourHive Buddy"),
    "jilian": ("Jilian", "HourHive Buddy"),
    "warren apit": ("Warren", "Catalyst Opus"),
    "warren": ("Warren", "Catalyst Opus"),
}

repos = [
    ("leotansingapore/hourhive-buddy", "HourHive Buddy"),
    ("leotansingapore/catalyst-opus", "Catalyst Opus"),
    ("leotansingapore/outsource-sales-portal-magic", "Sales Portal"),
    ("leotansingapore/catalyst-refresh-glow", "Catalyst Refresh Glow"),
    ("leotansingapore/partner-hub-40", "Partner Hub"),
]

# Gather commit summaries per app
app_summaries = {}
for repo_full, app_name in repos:
    r = subprocess.run(
        ["gh", "api", f"repos/{repo_full}/commits?since={since}&per_page=30",
         "--jq", '.[] | "\(.commit.author.name): \(.commit.message | split("\n")[0])"'],
        capture_output=True, text=True, timeout=15
    )
    commits = [c.strip() for c in r.stdout.strip().split("\n") if c.strip()] if r.stdout.strip() else []
    if commits:
        # Summarize: group by author, max 3 commits each
        by_author = {}
        for c in commits:
            parts = c.split(": ", 1)
            author = parts[0] if len(parts) > 1 else "Unknown"
            msg = parts[1] if len(parts) > 1 else c
            by_author.setdefault(author, []).append(msg)
        summary_parts = []
        for author, msgs in by_author.items():
            top = msgs[:3]
            summary_parts.append(f"{author}: " + "; ".join(top))
        app_summaries[app_name] = ". ".join(summary_parts)
    else:
        app_summaries[app_name] = "(no commits this week)"

# Find team updates section and pre-fill "What I did last week"
team_row = None
for i, row in enumerate(all_vals):
    if "TEAM UPDATES" in str(row[0]):
        team_row = i + 1
        break

if team_row:
    for i in range(team_row + 1, team_row + 8):
        if i <= len(all_vals):
            cell_val = str(all_vals[i-1][0])
            for app_name, summary in app_summaries.items():
                if app_name.lower() in cell_val.lower():
                    ws.update(f"B{i}", [[summary]], value_input_option="USER_ENTERED")
                    break

# Pre-fill PRD progress "current state" with recent activity summary
prd_row = None
for i, row in enumerate(all_vals):
    if "PRD PROGRESS" in str(row[0]):
        prd_row = i + 1
        break

if prd_row:
    for i in range(prd_row + 1, prd_row + 8):
        if i <= len(all_vals):
            cell_val = str(all_vals[i-1][0])
            for app_name, summary in app_summaries.items():
                if app_name.lower() in cell_val.lower():
                    if summary != "(no commits this week)":
                        ws.update(f"B{i}", [[summary[:200]]], value_input_option="USER_ENTERED")
                    else:
                        ws.update(f"B{i}", [["No activity this week"]], value_input_option="USER_ENTERED")
                    break

print("Sheet pre-filled with GitHub activity")
PYEOF

# ── 4. Send to Lark ────────────────────────────────────────────────
LARK_TEXT=$(echo "$AGENDA" | sed 's/\[\[\([^]|]*\)\]\]/\1/g; s/\[\[[^|]*|\([^]]*\)\]\]/\1/g')

# Append meet link
LARK_TEXT="${LARK_TEXT}

---
**Join:** [Google Meet](https://meet.google.com/igs-arbe-ntm) | 4:00 - 5:00 PM SGT
**Meeting Sheet:** [Open Google Sheet](${SHEET_URL}) -- check off items, add comments, and drop tasks for the AI agent"

# Append Excalidraw link if available
EXCALIDRAW_LINK="$HOME/.local/share/co-apps-meeting/excalidraw_url.txt"
if [[ -f "$EXCALIDRAW_LINK" ]]; then
  EX_URL=$(cat "$EXCALIDRAW_LINK")
  if [[ -n "$EX_URL" ]]; then
    LARK_TEXT="${LARK_TEXT}
**Architecture:** [Excalidraw Diagram](${EX_URL})"
  fi
fi

curl -s -X POST "$LARK_CO_APPS_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "$(cat <<PAYLOAD
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {
        "tag": "plain_text",
        "content": "CO Apps Weekly Agenda -- $TODAY"
      },
      "template": "purple"
    },
    "elements": [
      {
        "tag": "markdown",
        "content": $(echo "$LARK_TEXT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
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
)" > /dev/null 2>&1

log "Agenda sent successfully ($TOTAL_COMMITS commits across ${#REPOS[@]} repos)"

# ── 5. Update Excalidraw diagram ───────────────────────────────────
"$HOME/.local/bin/co-apps-update-excalidraw.sh" 2>> "$LOG_FILE" || log "Obsidian Excalidraw update failed (non-fatal)"

# Generate excalidraw.com shareable URL for Lark
EXCALIDRAW_URL=$(node "$HOME/.local/bin/co-apps-export-excalidraw.js" 2>> "$LOG_FILE" || echo "")
if [[ -n "$EXCALIDRAW_URL" ]]; then
  log "Excalidraw URL: $EXCALIDRAW_URL"
else
  log "Excalidraw URL generation failed (non-fatal)"
fi

# Push raw .excalidraw file to GitHub for version history
DASHBOARD_DIR="$HOME/.local/share/co-apps-meeting/dashboard-repo"
if [[ ! -d "$DASHBOARD_DIR/.git" ]]; then
  git clone https://github.com/leotansingapore/co-apps-dashboard.git "$DASHBOARD_DIR" 2>> "$LOG_FILE" || true
fi
if [[ -d "$DASHBOARD_DIR/.git" ]]; then
  node "$HOME/.local/bin/co-apps-export-excalidraw.js" --github "$DASHBOARD_DIR/architecture.excalidraw" 2>> "$LOG_FILE"
  cd "$DASHBOARD_DIR" && git add architecture.excalidraw && \
    git commit -m "update: CO Apps architecture diagram ($TODAY)" 2>> "$LOG_FILE" && \
    git push 2>> "$LOG_FILE" && \
    log "Excalidraw pushed to GitHub" || log "Excalidraw GitHub push failed (non-fatal)"
  cd "$HOME"
fi

# ── 6. Sync dashboard repo ─────────────────────────────────────────
"$HOME/.local/bin/co-apps-sync-dashboard.sh" 2>> "$LOG_FILE" || log "Dashboard sync failed (non-fatal)"

echo "CO Apps scrum master agenda sent: $TODAY"
