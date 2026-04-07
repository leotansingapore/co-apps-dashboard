#!/bin/zsh
# CO Apps Post-Meeting Analyzer -- Tuesday 5:30 PM SGT
# Fetches Fireflies transcript, analyzes with Claude CLI, creates GitHub issues
set -euo pipefail

ENV_FILE="$HOME/Documents/New project/.env"
STATE_FILE="$HOME/.local/share/co-apps-meeting/state.json"
LOG_FILE="$HOME/.local/log/co-apps-meeting.log"
OBSIDIAN_DIR="$HOME/Documents/Obsidian Vault/Meetings/CO Apps"
TODAY=$(date '+%Y-%m-%d')
POLL_MODE=true

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --now) POLL_MODE=false; shift;;
    --poll) POLL_MODE=true; shift;;
    *) shift;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [post-meeting] $1" >> "$LOG_FILE"; }
log "Starting CO Apps post-meeting analysis (poll=$POLL_MODE)"

# Load env
set -a; source "$ENV_FILE"; set +a

# Ensure dirs exist
mkdir -p "$OBSIDIAN_DIR"

# Temp dir with cleanup
TMPDIR_REPORT=$(mktemp -d)
trap "rm -rf $TMPDIR_REPORT" EXIT

# ── 1. Find the CO Apps meeting transcript ─────────────────────────
find_transcript() {
  python3 << 'PYEOF'
import json, os, sys, time
from datetime import datetime, timezone, timedelta
from urllib.request import Request, urlopen

API_KEY = os.environ["FIREFLIES_API_KEY"]
SGT = timezone(timedelta(hours=8))

query = """{
    transcripts(limit: 15) {
        id
        title
        date
        duration
        organizer_email
        summary {
            overview
            shorthand_bullet
            action_items
        }
    }
}"""

req = Request(
    "https://api.fireflies.ai/graphql",
    data=json.dumps({"query": query}).encode(),
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    },
)

try:
    resp = urlopen(req, timeout=60)
    data = json.loads(resp.read())
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)

transcripts = data.get("data", {}).get("transcripts", [])

# Match by title first
for t in transcripts:
    title = (t.get("title") or "").lower()
    if "co apps" in title or "co-apps" in title or "co app" in title:
        print(t["id"])
        sys.exit(0)

# Fallback: Tuesday 3:30-5:30 PM SGT window
today_str = datetime.now(SGT).strftime("%Y-%m-%d")
for t in transcripts:
    ts = t.get("date", 0)
    if isinstance(ts, str):
        continue
    # Fireflies date is in milliseconds
    dt = datetime.fromtimestamp(ts / 1000, tz=SGT)
    if dt.strftime("%Y-%m-%d") == today_str and dt.weekday() == 1:
        if 15 <= dt.hour <= 17:
            print(t["id"])
            sys.exit(0)

sys.exit(1)
PYEOF
}

TRANSCRIPT_ID=""
if $POLL_MODE; then
  for attempt in $(seq 1 6); do
    log "Poll attempt $attempt/6 for Fireflies transcript"
    TRANSCRIPT_ID=$(find_transcript 2>/dev/null || echo "")
    if [[ -n "$TRANSCRIPT_ID" ]]; then
      break
    fi
    if [[ $attempt -lt 6 ]]; then
      log "Transcript not ready, waiting 10 minutes..."
      sleep 600
    fi
  done
else
  TRANSCRIPT_ID=$(find_transcript 2>/dev/null || echo "")
fi

if [[ -z "$TRANSCRIPT_ID" ]]; then
  log "No CO Apps meeting transcript found after polling. Exiting."
  echo "No CO Apps meeting transcript found for $TODAY"
  exit 0
fi

# Check if already processed
if [[ -f "$STATE_FILE" ]]; then
  ALREADY=$(python3 -c "
import json
d = json.load(open('$STATE_FILE'))
print('yes' if '$TRANSCRIPT_ID' in d.get('processed_transcripts', []) else 'no')
" 2>/dev/null || echo "no")
  if [[ "$ALREADY" == "yes" ]]; then
    log "Transcript $TRANSCRIPT_ID already processed. Skipping."
    exit 0
  fi
fi

log "Found transcript: $TRANSCRIPT_ID"

# ── 2. Fetch full transcript ──────────────────────────────────────
TRANSCRIPT=$(python3 << PYEOF
import json, os, sys
from urllib.request import Request, urlopen

API_KEY = os.environ["FIREFLIES_API_KEY"]

query = """{
    transcript(id: "$TRANSCRIPT_ID") {
        title
        audio_url
        video_url
        sentences {
            text
            speaker_name
        }
        summary {
            overview
            shorthand_bullet
            action_items
        }
    }
}"""

req = Request(
    "https://api.fireflies.ai/graphql",
    data=json.dumps({"query": query}).encode(),
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    },
)

try:
    resp = urlopen(req, timeout=120)
    data = json.loads(resp.read())
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)

transcript_data = data.get("data", {}).get("transcript", {})
sentences = transcript_data.get("sentences", [])
summary = transcript_data.get("summary", {})
title = transcript_data.get("title", "CO Apps Meeting")

audio_url = transcript_data.get("audio_url", "")
video_url = transcript_data.get("video_url", "")
recording_url = video_url or audio_url or ""

# Print metadata first
print(f"TITLE: {title}")
print(f"RECORDING_URL: {recording_url}")
print(f"SUMMARY: {summary.get('overview', 'N/A')}")
print(f"ACTION_ITEMS: {summary.get('action_items', 'N/A')}")
print("---TRANSCRIPT---")

lines = []
for s in sentences:
    speaker = s.get("speaker_name", "Unknown")
    text = s.get("text", "")
    if text.strip():
        lines.append(f"{speaker}: {text}")

# Truncate to ~80% if very long (skip small talk at start)
if len(lines) > 500:
    start = len(lines) // 5  # skip first 20%
    lines = lines[start:]

print("\n".join(lines))
PYEOF
)

if [[ -z "$TRANSCRIPT" ]]; then
  log "Failed to fetch transcript content"
  exit 1
fi

log "Transcript fetched ($(echo "$TRANSCRIPT" | wc -l | tr -d ' ') lines)"

# ── 3. Analyze with Claude CLI ────────────────────────────────────
log "Analyzing transcript with Claude CLI"

# Write transcript to temp file to avoid arg length limits
echo "$TRANSCRIPT" > "$TMPDIR_REPORT/transcript.txt"

ANALYSIS=$(claude -p --model sonnet "$(cat "$TMPDIR_REPORT/transcript.txt")

You are a scrum master analyzing a CO Apps team meeting transcript. The team works on 5 apps:
- [hourhive-buddy](https://github.com/leotansingapore/hourhive-buddy): VA management and analytics
- [catalyst-opus](https://github.com/leotansingapore/catalyst-opus): Task management platform
- [outsource-sales-portal-magic](https://github.com/leotansingapore/outsource-sales-portal-magic): Sales portal
- [catalyst-refresh-glow](https://github.com/leotansingapore/catalyst-refresh-glow): Marketing website
- [partner-hub-40](https://github.com/leotansingapore/partner-hub-40): Partner hub

IMPORTANT: When mentioning a repo name, always hyperlink it using markdown: [repo-name](https://github.com/leotansingapore/repo-name).

Extract the following (use ** for bold headings, no # headers):

**Meeting Summary**
3-5 sentence overview of what was discussed and decided.

**Key Decisions**
List each decision made with brief context.

**Action Items**
For each action item: who is responsible, what needs to be done, which repo it relates to.

**Bugs/Issues Discussed**
Any bugs, errors, or technical issues mentioned.

**Follow-ups for Next Week**
Items that need follow-up in the next meeting.

IMPORTANT: At the very end of your response, output a JSON array of action items wrapped in triple backticks with json tag. Each item must have these exact fields:
- assignee: person's name (string)
- description: what needs to be done (string)
- repo: one of hourhive-buddy, catalyst-opus, outsource-sales-portal-magic, catalyst-refresh-glow, partner-hub-40, or general (string)

Example:
\`\`\`json
[{\"assignee\":\"Jilian Garette\",\"description\":\"Add webhook error handling\",\"repo\":\"hourhive-buddy\"}]
\`\`\`

If there are no clear action items, output an empty array: \`\`\`json\n[]\n\`\`\`")

log "Analysis complete (${#ANALYSIS} chars)"

# ── 4. Parse action items and create GitHub issues ─────────────────
log "Creating GitHub issues from action items"

# Contributor -> GitHub username mapping
declare -A GH_USERS
GH_USERS[jilian garette]=jiliangarette
GH_USERS[jilian]=jiliangarette
GH_USERS[warren apit]=warren-apit
GH_USERS[warren]=warren-apit

# Extract JSON block and create issues
ISSUE_RESULTS=$(python3 << PYEOF
import json, re, subprocess, sys

analysis = """$ANALYSIS"""

# Extract JSON block
match = re.search(r'\`\`\`json\s*\n(.*?)\n\`\`\`', analysis, re.DOTALL)
if not match:
    print("NO_ACTIONS")
    sys.exit(0)

try:
    actions = json.loads(match.group(1))
except json.JSONDecodeError:
    print("PARSE_ERROR")
    sys.exit(0)

if not actions:
    print("NO_ACTIONS")
    sys.exit(0)

# GitHub username mapping
gh_users = {
    "jilian garette": "jiliangarette",
    "jilian": "jiliangarette",
    "warren apit": "warren-apit",
    "warren": "warren-apit",
}

repo_prefix = "leotansingapore/"
results = []

for item in actions:
    repo_short = item.get("repo", "general")
    description = item.get("description", "No description")
    assignee = item.get("assignee", "")

    if repo_short == "general":
        repo = f"{repo_prefix}catalyst-opus"  # default repo for general items
    else:
        repo = f"{repo_prefix}{repo_short}"

    # Ensure label exists
    subprocess.run(
        ["gh", "label", "create", "meeting-action", "--repo", repo,
         "--description", "Action item from CO Apps weekly meeting",
         "--color", "D93F0B", "--force"],
        capture_output=True
    )

    # Build issue body
    body = f"**Assigned to:** {assignee}\n**Context:** Discussed in CO Apps weekly meeting on {sys.argv[1] if len(sys.argv) > 1 else 'today'}\n\n---\n*Created by CO Apps Meeting Bot*"

    # Create issue
    cmd = [
        "gh", "issue", "create",
        "--repo", repo,
        "--title", f"[Meeting Action] {description}",
        "--body", body,
        "--label", "meeting-action",
    ]

    # Try to assign if username is known
    gh_user = gh_users.get(assignee.lower(), "")
    if gh_user:
        cmd.extend(["--assignee", gh_user])

    result = subprocess.run(cmd, capture_output=True, text=True)
    issue_url = result.stdout.strip()

    # Extract issue number from URL
    issue_num = ""
    if issue_url:
        parts = issue_url.rstrip("/").split("/")
        issue_num = parts[-1] if parts else ""

    results.append({
        "repo": repo_short,
        "issue_number": issue_num,
        "title": description,
        "assignee": assignee,
        "url": issue_url,
        "status": "open",
        "created_date": sys.argv[1] if len(sys.argv) > 1 else "",
    })

print(json.dumps(results))
PYEOF
"$TODAY")

log "Issue creation results: $ISSUE_RESULTS"

# ── 5. Update state.json ──────────────────────────────────────────
python3 << PYEOF
import json

state_file = "$STATE_FILE"
try:
    state = json.load(open(state_file))
except (FileNotFoundError, json.JSONDecodeError):
    state = {"last_meeting_date": "", "processed_transcripts": [], "action_items": []}

state["last_meeting_date"] = "$TODAY"
state["processed_transcripts"].append("$TRANSCRIPT_ID")

# Keep only last 20 processed transcript IDs
state["processed_transcripts"] = state["processed_transcripts"][-20:]

# Parse new action items
issue_results = """$ISSUE_RESULTS"""
if issue_results not in ("NO_ACTIONS", "PARSE_ERROR", ""):
    try:
        new_items = json.loads(issue_results)
        # Mark old items as carried-over if still open
        for item in state.get("action_items", []):
            if item.get("status") == "open":
                item["status"] = "carried-over"
        state["action_items"].extend(new_items)
    except json.JSONDecodeError:
        pass

# Keep only last 50 action items
state["action_items"] = state["action_items"][-50:]

json.dump(state, open(state_file, "w"), indent=2)
PYEOF

log "State updated"

# ── 6. Save to Obsidian ───────────────────────────────────────────
MEETING_TITLE=$(echo "$TRANSCRIPT" | head -1 | sed 's/^TITLE: //')
RECORDING_URL=$(echo "$TRANSCRIPT" | grep "^RECORDING_URL:" | sed 's/^RECORDING_URL: //')
OBSIDIAN_FILE="$OBSIDIAN_DIR/${TODAY} CO Apps Meeting.md"

RECORDING_LINE=""
if [[ -n "$RECORDING_URL" && "$RECORDING_URL" != "None" ]]; then
  RECORDING_LINE="recording_url: $RECORDING_URL"
fi

cat > "$OBSIDIAN_FILE" << OBSEOF
---
date: $TODAY
type: meeting-notes
meeting: CO Apps Weekly
source: fireflies
transcript_id: $TRANSCRIPT_ID
${RECORDING_LINE}
---

# CO Apps Weekly Meeting -- $TODAY

$ANALYSIS
OBSEOF

log "Obsidian note saved: $OBSIDIAN_FILE"

# ── 7. Send summary to Lark ───────────────────────────────────────
# Strip JSON block from analysis for Lark display
LARK_TEXT=$(echo "$ANALYSIS" | sed '/^```json/,/^```$/d')

# Append issue links if any were created
if [[ "$ISSUE_RESULTS" != "NO_ACTIONS" && "$ISSUE_RESULTS" != "PARSE_ERROR" && -n "$ISSUE_RESULTS" ]]; then
  ISSUE_LINKS=$(python3 -c "
import json
items = json.loads('''$ISSUE_RESULTS''')
for i in items:
    if i.get('url'):
        print(f\"- [{i['repo']} #{i['issue_number']}]({i['url']}): {i['title']}\")
" 2>/dev/null || echo "")
  if [[ -n "$ISSUE_LINKS" ]]; then
    LARK_TEXT="${LARK_TEXT}

**GitHub Issues Created:**
${ISSUE_LINKS}"
  fi
fi

# Append Excalidraw link if available
EXCALIDRAW_LINK="$HOME/.local/share/co-apps-meeting/excalidraw_url.txt"
if [[ -f "$EXCALIDRAW_LINK" ]]; then
  EX_URL=$(cat "$EXCALIDRAW_LINK")
  if [[ -n "$EX_URL" ]]; then
    LARK_TEXT="${LARK_TEXT}

---
**Architecture:** [Excalidraw Diagram](${EX_URL})"
  fi
fi

# Append recording link if available
if [[ -n "$RECORDING_URL" && "$RECORDING_URL" != "None" ]]; then
  LARK_TEXT="${LARK_TEXT}
**Recording:** [Listen to meeting](${RECORDING_URL})"
fi

# Append sheet link
SHEET_URL="https://docs.google.com/spreadsheets/d/1HaT_811PWs-4p-uc4VUM-i6PYLRbwV0YHjt8DjWfIiM"
LARK_TEXT="${LARK_TEXT}
**Meeting Sheet:** [View auto-filled notes](${SHEET_URL})"

curl -s -X POST "$LARK_CO_APPS_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "$(cat <<PAYLOAD
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {
        "tag": "plain_text",
        "content": "CO Apps Meeting Summary -- $TODAY"
      },
      "template": "green"
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

log "Meeting summary sent to Lark"

# ── 8. Auto-fill Google Sheet from transcript ──────────────────────
log "Auto-filling Google Sheet from transcript"

SHEET_DATA=$(claude -p --model sonnet "$(cat "$TMPDIR_REPORT/transcript.txt")

You are extracting structured meeting data from a CO Apps team meeting transcript. The team members are:
- Jilian (HourHive Buddy)
- Warren (Catalyst Opus)
- Leo (Overall / Cross-app)
- Others may be unassigned to Sales Portal, Catalyst Refresh Glow, Partner Hub

Output ONLY a JSON object with these exact keys (no markdown, no explanation, just raw JSON):

{
  \"team_updates\": [
    {\"person\": \"Jilian\", \"app\": \"HourHive Buddy\", \"did_last_week\": \"...\", \"doing_this_week\": \"...\", \"blockers\": \"...\", \"help_needed\": \"\"},
    {\"person\": \"Warren\", \"app\": \"Catalyst Opus\", \"did_last_week\": \"...\", \"doing_this_week\": \"...\", \"blockers\": \"...\", \"help_needed\": \"\"},
    {\"person\": \"Leo\", \"app\": \"Overall / Cross-app\", \"did_last_week\": \"...\", \"doing_this_week\": \"...\", \"blockers\": \"...\", \"help_needed\": \"\"}
  ],
  \"prd_progress\": [
    {\"app\": \"HourHive Buddy\", \"current_state\": \"...\", \"next_milestone\": \"...\", \"percent\": \"...\", \"blockers\": \"\"},
    {\"app\": \"Catalyst Opus\", \"current_state\": \"...\", \"next_milestone\": \"...\", \"percent\": \"...\", \"blockers\": \"\"},
    {\"app\": \"Sales Portal\", \"current_state\": \"...\", \"next_milestone\": \"...\", \"percent\": \"...\", \"blockers\": \"\"},
    {\"app\": \"Catalyst Refresh Glow\", \"current_state\": \"...\", \"next_milestone\": \"...\", \"percent\": \"...\", \"blockers\": \"\"},
    {\"app\": \"Partner Hub\", \"current_state\": \"...\", \"next_milestone\": \"...\", \"percent\": \"...\", \"blockers\": \"\"}
  ],
  \"decisions\": [
    {\"decision\": \"...\", \"options\": \"...\", \"outcome\": \"...\", \"owner\": \"...\", \"deadline\": \"\"}
  ],
  \"discussion_topics\": [
    {\"topic\": \"...\", \"raised_by\": \"...\", \"outcome\": \"\"}
  ],
  \"action_items\": [
    {\"task\": \"...\", \"owner\": \"...\", \"app\": \"...\", \"due_by\": \"\", \"notes\": \"\"}
  ],
  \"agent_tasks\": [
    {\"task\": \"...\", \"app\": \"...\", \"priority\": \"High|Medium|Low\", \"details\": \"\"}
  ]
}

Rules:
- Fill in what was discussed. Leave empty string if not mentioned.
- For percent, use values like 50%, 70%, etc.
- For agent_tasks, extract any requests for automated/AI work.
- If a section had no relevant discussion, use an empty array [].
- Output ONLY the JSON, no markdown fences, no explanation.") 2>> "$LOG_FILE"

if [[ -n "$SHEET_DATA" ]]; then
  cd "$HOME/Documents/New project" && python3 << PYEOF
import json, sys, os
sys.path.insert(0, os.path.join(os.environ["HOME"], "Documents/New project/tools"))
from lib.sheets import get_sheets_client

sheet_id = open(os.path.join(os.environ["HOME"], ".local/share/co-apps-meeting/sheet_id.txt")).read().strip()
gc = get_sheets_client()
ss = gc.open_by_key(sheet_id)
ws = ss.worksheet("$TODAY")

try:
    data = json.loads('''$SHEET_DATA''')
except json.JSONDecodeError:
    print("Failed to parse sheet data JSON", file=sys.stderr)
    sys.exit(0)

all_vals = ws.get_all_values()

# Helper: find section row
def find_row(label):
    for i, row in enumerate(all_vals):
        if label in str(row[0]):
            return i + 1  # 1-indexed
    return None

# Fill team updates (rows 9-14 based on known structure)
team_row = find_row("TEAM UPDATES")
if team_row and data.get("team_updates"):
    for update in data["team_updates"]:
        person = update.get("person", "")
        # Find the row matching this person
        for i in range(team_row + 1, team_row + 8):
            if i <= len(all_vals) and person.lower() in str(all_vals[i-1][0]).lower():
                ws.update(f"B{i}:E{i}", [[
                    update.get("did_last_week", ""),
                    update.get("doing_this_week", ""),
                    update.get("blockers", ""),
                    update.get("help_needed", ""),
                ]], value_input_option="USER_ENTERED")
                break

# Fill PRD progress
prd_row = find_row("PRD PROGRESS")
if prd_row and data.get("prd_progress"):
    for prog in data["prd_progress"]:
        app = prog.get("app", "")
        for i in range(prd_row + 1, prd_row + 8):
            if i <= len(all_vals) and app.lower() in str(all_vals[i-1][0]).lower():
                ws.update(f"B{i}:E{i}", [[
                    prog.get("current_state", ""),
                    prog.get("next_milestone", ""),
                    prog.get("percent", ""),
                    prog.get("blockers", ""),
                ]], value_input_option="USER_ENTERED")
                break

# Fill decisions
dec_row = find_row("DECISIONS TO MAKE")
if dec_row and data.get("decisions"):
    for j, dec in enumerate(data["decisions"][:4]):
        r = dec_row + 1 + j
        ws.update(f"A{r}:E{r}", [[
            dec.get("decision", ""),
            dec.get("options", ""),
            dec.get("outcome", ""),
            dec.get("owner", ""),
            dec.get("deadline", ""),
        ]], value_input_option="USER_ENTERED")

# Fill discussion topics
disc_row = find_row("OPEN DISCUSSION")
if disc_row and data.get("discussion_topics"):
    for j, topic in enumerate(data["discussion_topics"][:5]):
        r = disc_row + 1 + j
        ws.update(f"A{r}:D{r}", [[
            topic.get("topic", ""),
            topic.get("raised_by", ""),
            "",
            topic.get("outcome", ""),
        ]], value_input_option="USER_ENTERED")

# Fill action items
action_row = find_row("NEW ACTION ITEMS")
if action_row and data.get("action_items"):
    for j, item in enumerate(data["action_items"][:8]):
        r = action_row + 1 + j
        ws.update(f"A{r}:E{r}", [[
            item.get("task", ""),
            item.get("owner", ""),
            item.get("app", ""),
            item.get("due_by", ""),
            item.get("notes", ""),
        ]], value_input_option="USER_ENTERED")

# Fill agent tasks
agent_row = find_row("TASKS FOR THE AI AGENT")
if agent_row and data.get("agent_tasks"):
    for j, task in enumerate(data["agent_tasks"][:6]):
        r = agent_row + 2 + j  # skip instruction row
        ws.update(f"A{r}:E{r}", [[
            task.get("task", ""),
            task.get("app", ""),
            task.get("priority", ""),
            "To Do",
            task.get("details", ""),
        ]], value_input_option="USER_ENTERED")

print("Sheet auto-filled from transcript")
PYEOF
  log "Google Sheet auto-filled"
else
  log "No sheet data extracted (non-fatal)"
fi

# ── 9. Dispatch Ralph tasks from sheet ─────────────────────────────
log "Dispatching Ralph tasks"
cd "$HOME/Documents/New project" && python3 "$HOME/.local/bin/co-apps-ralph-dispatch.py" 2>> "$LOG_FILE" || log "Ralph dispatch failed (non-fatal)"

echo "CO Apps post-meeting analysis complete: $TODAY"
