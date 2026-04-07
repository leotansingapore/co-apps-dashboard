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
    r(['=HYPERLINK("https://meet.google.com/igs-arbe-ntm","Meeting: 4:00-5:00 PM SGT | Click to join Google Meet")', "", "", "", "", ""])
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
        "HourHive Buddy": "https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/hourhive-buddy/PRD.md",
        "Catalyst Opus": "https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/catalyst-opus/PRD.md",
        "Sales Portal": "https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/outsource-sales-portal-magic/PRD.md",
        "Catalyst Refresh Glow": "https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/catalyst-refresh-glow/PRD.md",
        "Partner Hub": "https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/partner-hub-40/PRD.md",
    }

    for app in APPS:
        link = prd_links.get(app["name"], "")
        formula = f'=HYPERLINK("{link}","View PRD")' if link else ""
        r([app["name"], "", "", "", "", formula])
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

    # Write all rows (USER_ENTERED so formulas like HYPERLINK render)
    ws.update(range_name="A1", values=rows, value_input_option="USER_ENTERED")

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

    # ── Dropdowns (data validation) ──
    app_choices = [
        "HourHive Buddy",
        "Catalyst Opus",
        "Sales Portal",
        "Catalyst Refresh Glow",
        "Partner Hub",
        "General / Cross-app",
    ]
    priority_choices = ["High", "Medium", "Low"]
    status_choices = ["To Do", "In Progress", "Done", "Blocked"]
    owner_choices = ["Jilian", "Warren", "Leo", ""]

    percent_choices = ["0%", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"]

    # Find row ranges for each section
    agent_task_rows = []
    action_item_rows = []
    prd_progress_rows = []
    for i, row in enumerate(rows):
        if row[0] == "TASKS FOR THE AI AGENT":
            agent_task_rows = list(range(i + 2, i + 2 + 6))
        if row[0] == "NEW ACTION ITEMS (fill in during meeting)":
            action_item_rows = list(range(i + 1, i + 1 + 8))
        if row[0] == "PRD PROGRESS -- WHERE WE ARE vs WHERE WE WANT TO BE":
            prd_progress_rows = list(range(i + 2, i + 2 + 5))  # 5 app rows

    def make_dropdown(sheet_id, row_start, row_end, col, values):
        """Create a data validation dropdown rule."""
        return {
            "setDataValidation": {
                "range": {
                    "sheetId": sheet_id,
                    "startRowIndex": row_start - 1,
                    "endRowIndex": row_end,
                    "startColumnIndex": col,
                    "endColumnIndex": col + 1,
                },
                "rule": {
                    "condition": {
                        "type": "ONE_OF_LIST",
                        "values": [{"userEnteredValue": v} for v in values],
                    },
                    "showCustomUi": True,
                    "strict": False,
                },
            }
        }

    dropdown_requests = []

    if agent_task_rows:
        first = agent_task_rows[0] + 1  # 1-indexed
        last = agent_task_rows[-1] + 1
        # App dropdown (column B = index 1)
        dropdown_requests.append(make_dropdown(ws.id, first, last, 1, app_choices))
        # Priority dropdown (column C = index 2)
        dropdown_requests.append(make_dropdown(ws.id, first, last, 2, priority_choices))
        # Status dropdown (column D = index 3)
        dropdown_requests.append(make_dropdown(ws.id, first, last, 3, status_choices))

    if action_item_rows:
        first = action_item_rows[0] + 1
        last = action_item_rows[-1] + 1
        # App dropdown (column C = index 2)
        dropdown_requests.append(make_dropdown(ws.id, first, last, 2, app_choices))
        # Owner dropdown (column B = index 1)
        dropdown_requests.append(make_dropdown(ws.id, first, last, 1, owner_choices + ["Lovable Bot"]))
        # Due by date picker (column D = index 3)
        dropdown_requests.append({
            "setDataValidation": {
                "range": {
                    "sheetId": ws.id,
                    "startRowIndex": first - 1,
                    "endRowIndex": last,
                    "startColumnIndex": 3,
                    "endColumnIndex": 4,
                },
                "rule": {
                    "condition": {
                        "type": "DATE_IS_VALID",
                    },
                    "showCustomUi": True,
                    "strict": False,
                },
            }
        })

    if prd_progress_rows:
        first = prd_progress_rows[0] + 1
        last = prd_progress_rows[-1] + 1
        # % complete dropdown (column D = index 3)
        dropdown_requests.append(make_dropdown(ws.id, first, last, 3, percent_choices))

    # Column widths
    body = {
        "requests": dropdown_requests + [
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

    # ── Quick Links tab ──
    try:
        ql = spreadsheet.worksheet("Quick Links")
        ql.clear()
    except Exception:
        ql = spreadsheet.add_worksheet(title="Quick Links", rows=30, cols=3)

    links = [
        ["CO Apps -- Quick Links", "", ""],
        ["", "", ""],
        ["Weekly Meeting", "", ""],
        ['=HYPERLINK("https://meet.google.com/igs-arbe-ntm","Join Google Meet")', "Tuesdays 4:00-5:00 PM SGT", ""],
        ['=HYPERLINK("https://docs.google.com/spreadsheets/d/1HaT_811PWs-4p-uc4VUM-i6PYLRbwV0YHjt8DjWfIiM","Meeting Sheet")', "Auto-filled after each meeting", ""],
        ["", "", ""],
        ["Product Requirements (PRDs)", "", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/ECOSYSTEM-PRD.md","Ecosystem PRD")', "How all 5 apps connect", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/catalyst-opus/PRD.md","Catalyst Opus PRD")', "Client dashboard, SSO, tasks, hiring", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/hourhive-buddy/PRD.md","HourHive Buddy PRD")', "Time tracking, EOD reports, payroll", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/outsource-sales-portal-magic/PRD.md","Sales Portal PRD")', "CRM, proposals, Stripe payments", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/catalyst-refresh-glow/PRD.md","Catalyst Refresh Glow PRD")', "Marketing website, SEO", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/co-apps-dashboard/blob/main/prds/partner-hub-40/PRD.md","Partner Hub PRD")', "Affiliate portal, commissions", ""],
        ["", "", ""],
        ["GitHub Repos", "", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/co-apps-dashboard","CO Apps Dashboard")', "This repo -- PRDs, automation, diagrams", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/catalyst-opus","Catalyst Opus")', "Warren", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/hourhive-buddy","HourHive Buddy")', "Jilian", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/outsource-sales-portal-magic","Sales Portal")', "", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/catalyst-refresh-glow","Catalyst Refresh Glow")', "", ""],
        ['=HYPERLINK("https://github.com/leotansingapore/partner-hub-40","Partner Hub")', "", ""],
    ]

    ql.update(range_name="A1", values=links, value_input_option="USER_ENTERED")

    # Format headers
    ql.format("A1:C1", {
        "backgroundColor": {"red": 0.12, "green": 0.12, "blue": 0.45},
        "textFormat": {"bold": True, "fontSize": 14,
                       "foregroundColor": {"red": 1, "green": 1, "blue": 1}},
    })
    for label in ["Weekly Meeting", "Product Requirements (PRDs)", "GitHub Repos"]:
        for i, row in enumerate(links):
            if row[0] == label:
                ql.format(f"A{i+1}:C{i+1}", {
                    "backgroundColor": {"red": 0.15, "green": 0.15, "blue": 0.15},
                    "textFormat": {"bold": True,
                                   "foregroundColor": {"red": 1, "green": 1, "blue": 1}},
                })

    # Column widths for Quick Links
    spreadsheet.batch_update({"requests": [
        {"updateDimensionProperties": {
            "range": {"sheetId": ql.id, "dimension": "COLUMNS",
                      "startIndex": 0, "endIndex": 1},
            "properties": {"pixelSize": 300}, "fields": "pixelSize"}},
        {"updateDimensionProperties": {
            "range": {"sheetId": ql.id, "dimension": "COLUMNS",
                      "startIndex": 1, "endIndex": 2},
            "properties": {"pixelSize": 350}, "fields": "pixelSize"}},
    ]})

    # Remove default Sheet1 if exists
    try:
        default = spreadsheet.worksheet("Sheet1")
        spreadsheet.del_worksheet(default)
    except Exception:
        pass

    print(spreadsheet.url)


if __name__ == "__main__":
    main()
