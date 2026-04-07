#!/usr/bin/env python3
"""
CO Apps Weekly Scrum -- Google Sheet Agenda

Creates a new tab each week structured as a scrum meeting agenda:
- What each person accomplished last week
- What they're working on this week
- Blockers / help needed
- Decisions to make
- Action items
- AI agent requests
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta

sys.path.insert(0, os.path.join(os.environ["HOME"], "Documents/New project/tools"))
from lib.sheets import get_sheets_client

SHEET_ID_FILE = os.path.join(os.environ["HOME"], ".local/share/co-apps-meeting/sheet_id.txt")
STATE_FILE = os.path.join(os.environ["HOME"], ".local/share/co-apps-meeting/state.json")
TODAY = datetime.now().strftime("%Y-%m-%d")
WEEK = datetime.now().strftime("Week %U")

APPS = [
    {"name": "HourHive Buddy", "repo": "hourhive-buddy", "owner": "Jilian"},
    {"name": "Catalyst Opus", "repo": "catalyst-opus", "owner": "Warren"},
    {"name": "Sales Portal", "repo": "outsource-sales-portal-magic", "owner": ""},
    {"name": "Catalyst Refresh Glow", "repo": "catalyst-refresh-glow", "owner": ""},
    {"name": "Partner Hub", "repo": "partner-hub-40", "owner": ""},
]


def load_action_items():
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
        return [a for a in state.get("action_items", []) if a.get("status") != "done"]
    except Exception:
        return []


def main():
    sheet_id = open(SHEET_ID_FILE).read().strip()
    gc = get_sheets_client()
    spreadsheet = gc.open_by_key(sheet_id)
    action_items = load_action_items()

    tab_name = f"{TODAY}"

    # Create or clear tab
    try:
        ws = spreadsheet.worksheet(tab_name)
        ws.clear()
    except Exception:
        ws = spreadsheet.add_worksheet(title=tab_name, rows=120, cols=6)

    rows = []
    r = rows.append

    # ── Header ──
    r([f"CO Apps Weekly Scrum -- {TODAY}", "", "", "", "", ""])
    r(["Meeting: 4:00-5:00 PM SGT | Google Meet: meet.google.com/igs-arbe-ntm", "", "", "", "", ""])
    r(["", "", "", "", "", ""])

    # ── Section 1: Follow-ups ──
    r(["FOLLOW-UPS FROM LAST WEEK", "Owner", "Status", "Done?", "Notes", ""])
    if action_items:
        for item in action_items:
            r([
                item.get("title", ""),
                item.get("assignee", ""),
                item.get("status", "open"),
                "",
                "",
                "",
            ])
    else:
        r(["Nothing outstanding -- all clear", "", "", "", "", ""])
    r(["", "", "", "", "", ""])

    # ── Section 2: Per-person updates ──
    r(["TEAM UPDATES", "", "", "", "", ""])
    r(["", "What I did last week", "What I'm doing this week", "Any blockers?", "Help needed?", ""])

    for app in APPS:
        owner = app["owner"] if app["owner"] else "(unassigned)"
        r([f"{owner} -- {app['name']}", "", "", "", "", ""])

    r(["Leo -- Overall / Cross-app", "", "", "", "", ""])
    r(["", "", "", "", "", ""])

    # ── Section 3: PRD Progress -- where are we vs where we want to be ──
    r(["PRD PROGRESS -- WHERE WE ARE vs WHERE WE WANT TO BE", "", "", "", "", ""])
    r(["App", "Current state (where we are)", "Next milestone (where we want to be)", "% complete", "What's blocking us?", "PRD link"])

    prd_links = {
        "HourHive Buddy": "github.com/leotansingapore/co-apps-dashboard/blob/main/prds/hourhive-buddy/lovable-plan.md",
        "Catalyst Opus": "github.com/leotansingapore/co-apps-dashboard/blob/main/prds/catalyst-opus/PRD.md",
        "Sales Portal": "github.com/leotansingapore/co-apps-dashboard/blob/main/prds/outsource-sales-portal-magic/lovable-plan.md",
        "Catalyst Refresh Glow": "github.com/leotansingapore/co-apps-dashboard/blob/main/prds/catalyst-refresh-glow/lovable-plan.md",
        "Partner Hub": "github.com/leotansingapore/co-apps-dashboard/blob/main/prds/partner-hub-40/lovable-plan.md",
    }

    for app in APPS:
        r([app["name"], "", "", "", "", prd_links.get(app["name"], "")])
    r(["", "", "", "", "", ""])

    # ── Section 4: Decisions ──
    r(["DECISIONS TO MAKE", "Options", "Decision", "Owner", "Deadline", ""])
    for _ in range(4):
        r(["", "", "", "", "", ""])
    r(["", "", "", "", "", ""])

    # ── Section 5: Discussion topics ──
    r(["OPEN DISCUSSION", "Raised by", "Discussed?", "Notes / Outcome", "", ""])
    for _ in range(5):
        r(["", "", "", "", "", ""])
    r(["", "", "", "", "", ""])

    # ── Section 6: Action items ──
    r(["NEW ACTION ITEMS (fill in during meeting)", "Owner", "App", "Due by", "Notes", ""])
    for _ in range(8):
        r(["", "", "", "", "", ""])
    r(["", "", "", "", "", ""])

    # ── Section 7: AI agent tasks ──
    r(["TASKS FOR THE AI AGENT", "App", "Priority", "Status", "Describe what you want done", ""])
    r(["(The AI agent will read this section after the meeting and work on these)", "", "", "", "", ""])
    for _ in range(6):
        r(["", "", "", "", "", ""])

    # Write all rows
    ws.update(range_name="A1", values=rows)

    # ── Formatting ──
    # Title
    ws.format("A1:F1", {
        "backgroundColor": {"red": 0.12, "green": 0.12, "blue": 0.45},
        "textFormat": {"bold": True, "fontSize": 14,
                       "foregroundColor": {"red": 1, "green": 1, "blue": 1}},
    })
    # Subtitle
    ws.format("A2:F2", {
        "backgroundColor": {"red": 0.85, "green": 0.85, "blue": 0.95},
        "textFormat": {"fontSize": 10, "italic": True},
    })

    # Section headers
    section_labels = [
        "FOLLOW-UPS FROM LAST WEEK",
        "TEAM UPDATES",
        "PRD PROGRESS -- WHERE WE ARE vs WHERE WE WANT TO BE",
        "DECISIONS TO MAKE",
        "OPEN DISCUSSION",
        "NEW ACTION ITEMS (fill in during meeting)",
        "TASKS FOR THE AI AGENT",
    ]
    for i, row in enumerate(rows):
        if row[0] in section_labels:
            row_num = i + 1
            ws.format(f"A{row_num}:F{row_num}", {
                "backgroundColor": {"red": 0.15, "green": 0.15, "blue": 0.15},
                "textFormat": {"bold": True,
                               "foregroundColor": {"red": 1, "green": 1, "blue": 1}},
            })
            # Sub-header row (column labels)
            if row_num + 1 <= len(rows):
                next_row = rows[row_num]  # 0-indexed
                if next_row[0] == "" or next_row[1]:  # has sub-headers
                    ws.format(f"A{row_num + 1}:F{row_num + 1}", {
                        "backgroundColor": {"red": 0.93, "green": 0.93, "blue": 0.93},
                        "textFormat": {"bold": True, "fontSize": 10},
                    })

    # Column widths
    body = {
        "requests": [
            {"updateDimensionProperties": {
                "range": {"sheetId": ws.id, "dimension": "COLUMNS",
                          "startIndex": 0, "endIndex": 1},
                "properties": {"pixelSize": 350}, "fields": "pixelSize"}},
            {"updateDimensionProperties": {
                "range": {"sheetId": ws.id, "dimension": "COLUMNS",
                          "startIndex": 1, "endIndex": 6},
                "properties": {"pixelSize": 220}, "fields": "pixelSize"}},
        ]
    }
    spreadsheet.batch_update(body)

    # Remove default Sheet1 if exists
    try:
        default = spreadsheet.worksheet("Sheet1")
        spreadsheet.del_worksheet(default)
    except Exception:
        pass

    print(spreadsheet.url)


if __name__ == "__main__":
    main()
