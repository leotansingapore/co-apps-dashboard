#!/bin/zsh
# CO Apps Dashboard Sync -- pushes latest scripts and state to GitHub
# Called by other scripts after changes, or run manually
set -euo pipefail

DASHBOARD_DIR="$HOME/.local/share/co-apps-meeting/dashboard-repo"
LOG_FILE="$HOME/.local/log/co-apps-meeting.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [sync] $1" >> "$LOG_FILE"; }

# Ensure repo exists
if [[ ! -d "$DASHBOARD_DIR/.git" ]]; then
  git clone https://github.com/leotansingapore/co-apps-dashboard.git "$DASHBOARD_DIR" 2>> "$LOG_FILE"
fi

cd "$DASHBOARD_DIR"
git pull --rebase 2>> "$LOG_FILE" || true

# Sync automation scripts
cp ~/.local/bin/co-apps-meeting-reminder.sh automation/ 2>/dev/null || true
cp ~/.local/bin/co-apps-scrum-master.sh automation/ 2>/dev/null || true
cp ~/.local/bin/co-apps-post-meeting.sh automation/ 2>/dev/null || true
cp ~/.local/bin/co-apps-midweek-ping.sh automation/ 2>/dev/null || true
cp ~/.local/bin/co-apps-weekly-digest.sh automation/ 2>/dev/null || true
cp ~/.local/bin/co-apps-update-excalidraw.sh automation/ 2>/dev/null || true
cp ~/.local/bin/co-apps-export-excalidraw.js automation/ 2>/dev/null || true
cp ~/.local/bin/co-apps-meeting-sheet.py automation/ 2>/dev/null || true
cp ~/.local/bin/co-apps-ralph-dispatch.py automation/ 2>/dev/null || true
cp ~/.local/bin/co-apps-sync-dashboard.sh automation/ 2>/dev/null || true

# Sync launchd plists
mkdir -p automation/launchd
cp ~/Library/LaunchAgents/com.leo.co-apps-*.plist automation/launchd/ 2>/dev/null || true

# Sync workflow SOP
cp "$HOME/Documents/New project/workflows/co_apps_meeting.md" automation/ 2>/dev/null || true

# Check for changes
if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
  log "Dashboard repo already up to date"
  exit 0
fi

git add -A
git commit -m "sync: auto-update automation scripts and configs ($(date '+%Y-%m-%d %H:%M'))" 2>> "$LOG_FILE"
git push 2>> "$LOG_FILE"

log "Dashboard repo synced to GitHub"
echo "Dashboard synced"
