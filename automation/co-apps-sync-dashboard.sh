#!/bin/zsh
# CO Apps Dashboard Sync -- pushes latest scripts, state and regenerates index.html
# Called by other scripts after changes, or run manually.
set -euo pipefail

DASHBOARD_DIR="$HOME/.local/share/co-apps-meeting/dashboard-repo"
LOG_FILE="$HOME/.local/log/co-apps-meeting.log"
ENV_FILE="$HOME/Documents/New project/.env"
DASHBOARD_URL="https://leotansingapore.github.io/co-apps-dashboard/"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [sync] $1" >> "$LOG_FILE"; }

# Load env
set -a; source "$ENV_FILE"; set +a

# Ensure repo exists
if [[ ! -d "$DASHBOARD_DIR/.git" ]]; then
  git clone https://github.com/leotansingapore/co-apps-dashboard.git "$DASHBOARD_DIR" 2>> "$LOG_FILE"
fi

cd "$DASHBOARD_DIR"
git pull --rebase 2>> "$LOG_FILE" || true

# ── 1. Sync automation scripts ──────────────────────────────────
for src in \
  co-apps-meeting-reminder.sh \
  co-apps-scrum-master.sh \
  co-apps-post-meeting.sh \
  co-apps-midweek-ping.sh \
  co-apps-weekly-digest.sh \
  co-apps-update-excalidraw.sh \
  co-apps-export-excalidraw.js \
  co-apps-meeting-sheet.py \
  co-apps-meeting-log.py \
  co-apps-ralph-dispatch.py \
  co-apps-sync-dashboard.sh \
  co-apps-dashboard-regen.py; do
  cp "$HOME/.local/bin/$src" automation/ 2>/dev/null || true
done

# Sync launchd plists
mkdir -p automation/launchd
cp ~/Library/LaunchAgents/com.leo.co-apps-*.plist automation/launchd/ 2>/dev/null || true

# Sync workflow SOP
cp "$HOME/Documents/New project/workflows/co_apps_meeting.md" automation/ 2>/dev/null || true

# ── 2. Run meeting-log for today (pulls Fireflies, writes sheet + swarm-reports/*.md) ──
if [[ -n "${FIREFLIES_API_KEY:-}" ]]; then
  /usr/bin/python3 "$HOME/.local/bin/co-apps-meeting-log.py" 2>> "$LOG_FILE" || log "meeting-log skipped (no matching transcript or error)"
fi

# ── 3. Regenerate index.html ────────────────────────────────────
/usr/bin/python3 "$HOME/.local/bin/co-apps-dashboard-regen.py" 2>> "$LOG_FILE" || log "dashboard regen failed"

# ── 4. Detect changes and commit ────────────────────────────────
if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
  log "Dashboard repo already up to date"
  exit 0
fi

# Build changelog summary (file-level)
CHANGELOG=$(git status --porcelain | awk '{
  s=$1; f=substr($0, index($0,$2))
  tag = "changed"
  if (s ~ /A|\?\?/) tag = "added"
  else if (s ~ /D/) tag = "removed"
  else if (s ~ /M/) tag = "updated"
  printf "- %s: %s\n", tag, f
}' | head -20)

CHANGED_COUNT=$(git status --porcelain | wc -l | tr -d ' ')

git add -A
git commit -m "sync: dashboard auto-update ($(date '+%Y-%m-%d %H:%M')) -- $CHANGED_COUNT files" 2>> "$LOG_FILE"
git push 2>> "$LOG_FILE"

log "Dashboard synced ($CHANGED_COUNT files)"

# ── 5. Notify Lark with summary ─────────────────────────────────
if [[ -n "${LARK_CO_APPS_WEBHOOK:-}" ]]; then
  /usr/bin/python3 - <<PYEOF 2>> "$LOG_FILE" || true
import json, os, urllib.request
webhook = os.environ.get("LARK_CO_APPS_WEBHOOK", "")
if not webhook:
    raise SystemExit(0)
changelog = """$CHANGELOG""".strip() or "(no file-level details)"
count = "$CHANGED_COUNT"
content = f"""**Dashboard auto-synced** ({count} files)

[Open dashboard]($DASHBOARD_URL)

**Changes:**
{changelog}
"""
payload = {
    "msg_type": "interactive",
    "card": {
        "header": {"title": {"tag": "plain_text", "content": "CO Apps Dashboard updated"}, "template": "blue"},
        "elements": [{"tag": "markdown", "content": content}],
    },
}
req = urllib.request.Request(webhook, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
urllib.request.urlopen(req, timeout=5).read()
print("Lark notified")
PYEOF
fi

echo "Dashboard synced and Lark notified"
