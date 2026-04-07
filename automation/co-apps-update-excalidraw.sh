#!/bin/zsh
# CO Apps Excalidraw Diagram Updater
# Generates the CO Apps architecture diagram in Obsidian vault
# Uses cached repo_status.json from scrum master (no GitHub API calls)
set -euo pipefail

OBSIDIAN_DIR="$HOME/Documents/Obsidian Vault"
DIAGRAM_FILE="$OBSIDIAN_DIR/CO Apps Architecture.excalidraw.md"
STATE_FILE="$HOME/.local/share/co-apps-meeting/state.json"
REPO_STATUS="$HOME/.local/share/co-apps-meeting/repo_status.json"
LOG_FILE="$HOME/.local/log/co-apps-meeting.log"
TODAY=$(date '+%Y-%m-%d')

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [excalidraw] $1" >> "$LOG_FILE"; }
log "Updating CO Apps Excalidraw diagram"

# Use cached repo status or fallback
if [[ ! -f "$REPO_STATUS" ]]; then
  log "No repo_status.json found, using defaults"
  REPO_DATA='[{"name":"hourhive-buddy","desc":"VA Analytics","contributor":"Jilian Garette","issues":0,"status":"unknown"},{"name":"catalyst-opus","desc":"Task Management","contributor":"Warren Apit","issues":0,"status":"unknown"},{"name":"outsource-sales-portal-magic","desc":"Sales Portal","contributor":"Lovable Bot","issues":0,"status":"unknown"},{"name":"catalyst-refresh-glow","desc":"Marketing Website","contributor":"Lovable Bot","issues":0,"status":"unknown"},{"name":"partner-hub-40","desc":"Partner Hub","contributor":"Lovable Bot","issues":0,"status":"unknown"}]'
else
  REPO_DATA=$(cat "$REPO_STATUS")
fi

# Count outstanding action items
OUTSTANDING=0
if [[ -f "$STATE_FILE" ]]; then
  OUTSTANDING=$(python3 -c "
import json
d = json.load(open('$STATE_FILE'))
print(len([a for a in d.get('action_items', []) if a.get('status') != 'done']))
" 2>/dev/null || echo 0)
fi

# Generate Excalidraw file
python3 - "$REPO_DATA" "$OUTSTANDING" "$TODAY" << 'PYEOF' > "$DIAGRAM_FILE"
import json, sys

repo_data = json.loads(sys.argv[1])
outstanding = int(sys.argv[2])
today = sys.argv[3]

elements = []
eid = 100

def nid():
    global eid
    eid += 1
    return f"e{eid}"

def box(x, y, w, h, text, bg, stroke, fs=16):
    rid, tid = nid(), nid()
    elements.append({
        "id": rid, "type": "rectangle",
        "x": x, "y": y, "width": w, "height": h,
        "strokeColor": stroke, "backgroundColor": bg,
        "fillStyle": "solid", "strokeWidth": 2,
        "roundness": {"type": 3},
        "boundElements": [{"id": tid, "type": "text"}],
        "locked": False,
    })
    elements.append({
        "id": tid, "type": "text",
        "x": x + 10, "y": y + h/2 - fs/2 - 4,
        "width": w - 20, "height": fs + 8,
        "text": text, "fontSize": fs,
        "fontFamily": 1,
        "textAlign": "center", "verticalAlign": "middle",
        "containerId": rid,
        "strokeColor": stroke,
        "locked": False,
    })
    return rid

def link(fid, tid, label=""):
    aid = nid()
    a = {
        "id": aid, "type": "arrow",
        "x": 0, "y": 0,
        "strokeColor": "#495057", "strokeWidth": 2,
        "startBinding": {"elementId": fid, "focus": 0, "gap": 5},
        "endBinding": {"elementId": tid, "focus": 0, "gap": 5},
        "points": [[0, 0], [100, 0]],
        "roundness": {"type": 2},
        "locked": False,
    }
    if label:
        lid = nid()
        a["boundElements"] = [{"id": lid, "type": "text"}]
        elements.append(a)
        elements.append({
            "id": lid, "type": "text",
            "x": 0, "y": 0, "width": 120, "height": 16,
            "text": label, "fontSize": 12, "fontFamily": 1,
            "textAlign": "center", "containerId": aid,
            "strokeColor": "#495057", "locked": False,
        })
    else:
        elements.append(a)
    return aid

# Colors
C = {
    "auto": ("#f3d9fa", "#9c36b5"),
    "lark": ("#fff9db", "#e67700"),
    "gh": ("#e9ecef", "#495057"),
    "ff": ("#fff4e6", "#f76707"),
    "ob": ("#e5dbff", "#7048e8"),
    "hdr": ("#d0ebff", "#1864ab"),
    "ok": ("#d3f9d8", "#1e7e34"),
    "bad": ("#ffe3e3", "#e03131"),
}

# Title
box(200, 20, 550, 50, f"CO Apps Weekly Meeting Automation", C["hdr"][0], C["hdr"][1], 20)
box(200, 75, 550, 25, f"Updated: {today} | {outstanding} outstanding action items", "#f8f9fa", "#868e96", 11)

# Schedule column
box(30, 130, 220, 35, "Tuesday Schedule (SGT)", C["auto"][0], C["auto"][1], 13)
r1 = box(30, 180, 220, 55, "3:00 PM\nMeeting Reminder", C["auto"][0], C["auto"][1], 12)
r2 = box(30, 250, 220, 55, "3:30 PM\nScrum Master Agenda", C["auto"][0], C["auto"][1], 12)
r3 = box(30, 320, 220, 55, "5:30 PM\nPost-Meeting Analyzer", C["auto"][0], C["auto"][1], 12)

# Lark column
box(330, 130, 220, 35, "Lark Notifications", C["lark"][0], C["lark"][1], 13)
l1 = box(330, 180, 220, 55, "Purple Card\nJoin Reminder + Meet Link", C["lark"][0], C["lark"][1], 11)
l2 = box(330, 250, 220, 55, "Purple Card\nWeekly Agenda + Repo Links", C["lark"][0], C["lark"][1], 11)
l3 = box(330, 320, 220, 55, "Green Card\nSummary + Issue Links", C["lark"][0], C["lark"][1], 11)

link(r1, l1)
link(r2, l2)
link(r3, l3)

# Data sources
gh = box(630, 180, 180, 50, "GitHub\n5 Repos", C["gh"][0], C["gh"][1], 13)
ff = box(630, 280, 180, 50, "Fireflies\nTranscripts", C["ff"][0], C["ff"][1], 13)
link(gh, r2, "commits, PRs, issues")
link(ff, r3, "transcript")

# Outputs
gi = box(630, 370, 180, 45, "GitHub Issues\nmeeting-action label", C["gh"][0], C["gh"][1], 11)
ob = box(630, 430, 180, 45, "Obsidian Notes\nMeetings/CO Apps/", C["ob"][0], C["ob"][1], 11)
link(r3, gi)
link(r3, ob)

# State
st = box(30, 410, 220, 45, "state.json\nAction Items Tracker", "#f8f9fa", "#495057", 11)
link(st, r1, "outstanding count")
link(st, r2, "previous items")
link(gi, st, "new items")

# Repo status
box(330, 410, 250, 30, "Repo Status (Live)", C["hdr"][0], C["hdr"][1], 13)
y = 450
for repo in repo_data:
    s = repo.get("status", "unknown")
    tag = "Active" if s == "active" else ("STALE" if s == "stale" else "?")
    bg, stroke = (C["ok"] if s == "active" else C["bad"]) if s != "unknown" else ("#f8f9fa", "#495057")
    iss = f" | {repo['issues']} issues" if repo.get("issues", 0) > 0 else ""
    box(330, y, 250, 40, f"{repo['name']}\n{tag} | {repo['contributor']}{iss}", bg, stroke, 10)
    y += 47

# Google Meet
box(330, y + 10, 250, 35, "Google Meet: igs-arbe-ntm", C["hdr"][0], C["hdr"][1], 11)

# Excalidraw diagram
box(30, y + 10, 220, 35, "Excalidraw Diagram\nAuto-updated weekly", C["ob"][0], C["ob"][1], 10)

scene = {
    "type": "excalidraw",
    "version": 2,
    "source": "co-apps-scrum-master",
    "elements": elements,
    "appState": {"gridSize": None, "viewBackgroundColor": "#ffffff"},
    "files": {},
}

print("---")
print("excalidraw-plugin: parsed")
print("tags: [excalidraw, co-apps, automation]")
print(f"date: {today}")
print("---")
print("")
print("# CO Apps Architecture")
print("")
print(f"Updated automatically by co-apps-scrum-master.sh every Tuesday.")
print("")
print("%%")
print("# Excalidraw Data")
print("## Text Elements")
print("")
print("## Drawing")
print("```json")
print(json.dumps(scene, indent=2))
print("```")
print("%%")
PYEOF

log "Excalidraw diagram updated: $DIAGRAM_FILE"
echo "CO Apps Excalidraw diagram updated"
