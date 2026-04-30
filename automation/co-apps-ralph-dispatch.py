#!/usr/bin/python3
"""
CO Apps Ralph Dispatcher

Reads the "AI Agent Tasks" section from the weekly meeting Google Sheet,
converts valid tasks into prd.json files for Ralph to execute.

Usage:
  python3 co-apps-ralph-dispatch.py           # read latest meeting tab
  python3 co-apps-ralph-dispatch.py --dry-run  # preview without writing

Creates prd.json files in each repo's .ralph/ directory.
"""

import json
import os
import subprocess
import sys
from datetime import datetime

sys.path.insert(0, os.path.join(os.environ["HOME"], "Documents/New project/tools"))
from lib.sheets import get_sheets_client

SHEET_ID_FILE = os.path.join(os.environ["HOME"], ".local/share/co-apps-meeting/sheet_id.txt")
STATE_FILE = os.path.join(os.environ["HOME"], ".local/share/co-apps-meeting/state.json")
LOG_FILE = os.path.join(os.environ["HOME"], ".local/log/co-apps-meeting.log")
TODAY = datetime.now().strftime("%Y-%m-%d")

REPO_MAP = {
    "hourhive buddy": "leotansingapore/hourhive-buddy",
    "hourhive": "leotansingapore/hourhive-buddy",
    "catalyst opus": "leotansingapore/catalyst-opus",
    "opus": "leotansingapore/catalyst-opus",
    "sales portal": "leotansingapore/outsource-sales-portal-magic",
    "sales": "leotansingapore/outsource-sales-portal-magic",
    "catalyst refresh glow": "leotansingapore/catalyst-refresh-glow",
    "refresh glow": "leotansingapore/catalyst-refresh-glow",
    "marketing": "leotansingapore/catalyst-refresh-glow",
    "partner hub": "leotansingapore/partner-hub-40",
    "partner": "leotansingapore/partner-hub-40",
    "tavus talent spotter": "leotansingapore/tavus-talent-spotter-15b98171",
    "tavus": "leotansingapore/tavus-talent-spotter-15b98171",
    "talent spotter": "leotansingapore/tavus-talent-spotter-15b98171",
    "recruitment portal": "leotansingapore/tavus-talent-spotter-15b98171",
    "recruitment": "leotansingapore/tavus-talent-spotter-15b98171",
}

DRY_RUN = "--dry-run" in sys.argv


def log(msg):
    with open(LOG_FILE, "a") as f:
        f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [ralph] {msg}\n")


def find_repo(app_name):
    """Match app name to repo."""
    if not app_name:
        return None
    app_lower = app_name.strip().lower()
    for key, repo in REPO_MAP.items():
        if key in app_lower:
            return repo
    return None


def read_agent_tasks(gc, sheet_id):
    """Read AI Agent Tasks from the latest meeting tab."""
    spreadsheet = gc.open_by_key(sheet_id)
    worksheets = spreadsheet.worksheets()

    # Find the latest date-named tab
    date_tabs = [ws for ws in worksheets if ws.title.startswith("202")]
    if not date_tabs:
        log("No meeting tabs found")
        return []

    # Sort by date, take latest
    date_tabs.sort(key=lambda ws: ws.title, reverse=True)
    latest = date_tabs[0]
    log(f"Reading from tab: {latest.title}")

    all_values = latest.get_all_values()

    # Find "AI AGENT TASKS" section
    tasks = []
    in_section = False
    header_row = None

    for i, row in enumerate(all_values):
        if row and ("AI AGENT TASKS" in str(row[0]).upper() or "TASKS FOR THE AI AGENT" in str(row[0]).upper()):
            in_section = True
            header_row = i
            continue

        if in_section and header_row is not None and i == header_row + 1:
            # Skip the instruction row
            if "write what you want" in str(row[0]).lower() or "ai agent will read" in str(row[0]).lower():
                continue

        if in_section and i > header_row + 1:
            # Check if we hit the next section or empty area
            task_text = str(row[0]).strip() if row else ""
            if not task_text:
                continue

            # Check if this is a new section header (all caps)
            if task_text.isupper() and len(task_text) > 5:
                break

            app = str(row[1]).strip() if len(row) > 1 else ""
            priority = str(row[2]).strip() if len(row) > 2 else ""
            status = str(row[3]).strip() if len(row) > 3 else ""
            details = str(row[4]).strip() if len(row) > 4 else ""

            if task_text and task_text != "(The AI agent will read this section after the meeting and work on these)":
                tasks.append({
                    "task": task_text,
                    "app": app,
                    "priority": priority,
                    "status": status,
                    "details": details,
                })

    return tasks


def generate_prd_json(repo, tasks):
    """Generate a prd.json for Ralph from a list of tasks for one repo."""
    repo_short = repo.split("/")[1]
    branch = f"ralph/meeting-tasks-{TODAY}"

    stories = []
    for i, task in enumerate(tasks, 1):
        description = task["task"]
        if task["details"]:
            description += f". {task['details']}"

        # Generate acceptance criteria from task description
        criteria = [
            task["task"],
            "Typecheck passes",
        ]

        # Add browser verification for likely UI tasks
        ui_keywords = ["add", "fix", "update", "change", "show", "display", "button", "page", "ui", "design"]
        if any(kw in task["task"].lower() for kw in ui_keywords):
            criteria.insert(-1, "Verify in browser using dev-browser skill")

        stories.append({
            "id": f"US-{i:03d}",
            "title": task["task"],
            "description": f"As requested in CO Apps weekly meeting on {TODAY}: {description}",
            "acceptanceCriteria": criteria,
            "priority": i,
            "passes": False,
            "notes": task.get("details", ""),
        })

    return {
        "project": repo_short,
        "branchName": branch,
        "description": f"Tasks from CO Apps weekly meeting ({TODAY})",
        "userStories": stories,
    }


def dispatch_to_repo(repo, prd_json):
    """Push prd.json to the repo's .ralph/ directory via GitHub API."""
    repo_short = repo.split("/")[1]
    content = json.dumps(prd_json, indent=2)

    if DRY_RUN:
        print(f"\n--- DRY RUN: {repo} ---")
        print(content)
        return True

    # Use gh CLI to create/update the file
    import base64
    encoded = base64.b64encode(content.encode()).decode()

    # Check if .ralph/prd.json exists
    result = subprocess.run(
        ["gh", "api", f"repos/{repo}/contents/.ralph/prd.json", "--jq", ".sha"],
        capture_output=True, text=True,
    )
    sha = result.stdout.strip() if result.returncode == 0 else None

    # Create or update
    payload = {
        "message": f"feat: add meeting tasks from {TODAY} for Ralph",
        "content": encoded,
    }
    if sha:
        payload["sha"] = sha

    result = subprocess.run(
        ["gh", "api", f"repos/{repo}/contents/.ralph/prd.json",
         "--method", "PUT",
         "--input", "-"],
        input=json.dumps(payload),
        capture_output=True, text=True,
    )

    if result.returncode == 0:
        log(f"Dispatched {len(prd_json['userStories'])} tasks to {repo}")
        return True
    else:
        log(f"Failed to dispatch to {repo}: {result.stderr}")
        return False


def main():
    sheet_id = open(SHEET_ID_FILE).read().strip()
    gc = get_sheets_client()

    tasks = read_agent_tasks(gc, sheet_id)

    if not tasks:
        log("No AI agent tasks found in meeting sheet")
        print("No AI agent tasks found in the latest meeting tab.")
        return

    log(f"Found {len(tasks)} AI agent tasks")
    print(f"Found {len(tasks)} AI agent tasks:")

    # Group tasks by repo
    grouped = {}
    unmatched = []
    for task in tasks:
        repo = find_repo(task["app"])
        if repo:
            grouped.setdefault(repo, []).append(task)
        else:
            unmatched.append(task)

    # Dispatch to each repo
    for repo, repo_tasks in grouped.items():
        print(f"\n{repo}: {len(repo_tasks)} tasks")
        for t in repo_tasks:
            print(f"  - {t['task']}")

        prd_json = generate_prd_json(repo, repo_tasks)
        success = dispatch_to_repo(repo, prd_json)
        if success and not DRY_RUN:
            print(f"  -> Dispatched to .ralph/prd.json")

    if unmatched:
        print(f"\n{len(unmatched)} tasks without a matching app (skipped):")
        for t in unmatched:
            print(f"  - [{t['app']}] {t['task']}")

    print(f"\nDone. Ralph will pick up tasks on next run.")


if __name__ == "__main__":
    main()
