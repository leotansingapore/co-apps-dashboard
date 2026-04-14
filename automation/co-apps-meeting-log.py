#!/usr/bin/python3
"""
CO Apps Meeting Log -- fetches Fireflies transcript for the weekly CO Apps meeting
and writes:
  1. A "Meeting Log" tab row in the Google Sheet (creates tab if missing)
  2. A markdown file swarm-reports/YYYY-MM-DD-meeting.md in the dashboard repo

Run: python3 co-apps-meeting-log.py [--transcript-id ID] [--date YYYY-MM-DD]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.request import Request, urlopen

SGT = timezone(timedelta(hours=8))
SHEET_ID = "1HaT_811PWs-4p-uc4VUM-i6PYLRbwV0YHjt8DjWfIiM"
LOG_TAB = "Meeting Log"
DASHBOARD_REPO = Path.home() / ".local/share/co-apps-meeting/dashboard-repo"
MEETING_TITLE_HINTS = ("co apps", "co-apps", "co app")


def fireflies_query(query: str) -> dict:
    key = os.environ["FIREFLIES_API_KEY"]
    req = Request(
        "https://api.fireflies.ai/graphql",
        data=json.dumps({"query": query}).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"},
    )
    with urlopen(req, timeout=60) as resp:
        return json.loads(resp.read())


def find_transcript(transcript_id: str | None, target_date: str) -> dict:
    if transcript_id:
        q = f"""{{ transcript(id: "{transcript_id}") {{
            id title date duration organizer_email
            meeting_attendees {{ displayName email }}
            summary {{ overview action_items keywords }}
        }} }}"""
        data = fireflies_query(q)
        return data.get("data", {}).get("transcript") or {}

    q = """{ transcripts(limit: 20) {
        id title date duration organizer_email
        meeting_attendees { displayName email }
        summary { overview action_items keywords }
    } }"""
    data = fireflies_query(q)
    transcripts = data.get("data", {}).get("transcripts", []) or []

    # Prefer exact title match on target date
    for t in transcripts:
        title = (t.get("title") or "").lower()
        dt = datetime.fromtimestamp((t.get("date") or 0) / 1000, tz=SGT)
        if dt.strftime("%Y-%m-%d") != target_date:
            continue
        if any(h in title for h in MEETING_TITLE_HINTS):
            return t

    # Fallback: Tuesday 15:00-17:30 SGT window on target date
    for t in transcripts:
        dt = datetime.fromtimestamp((t.get("date") or 0) / 1000, tz=SGT)
        if dt.strftime("%Y-%m-%d") == target_date and dt.weekday() == 1 and 15 <= dt.hour <= 17:
            return t

    return {}


def ensure_log_tab(ss):
    import gspread

    try:
        ws = ss.worksheet(LOG_TAB)
    except gspread.exceptions.WorksheetNotFound:
        ws = ss.add_worksheet(title=LOG_TAB, rows=500, cols=10)
        ws.update("A1:H1", [[
            "Date", "Time", "Meeting Title", "Duration (min)",
            "Attendees", "Summary", "Action Items", "Transcript ID",
        ]], value_input_option="USER_ENTERED")
        try:
            ws.format("A1:H1", {"textFormat": {"bold": True}, "backgroundColor": {"red": 0.9, "green": 0.9, "blue": 0.95}})
        except Exception:
            pass
    return ws


def upsert_row(ws, row: list):
    date_val = row[0]
    existing = ws.get_all_values()
    for i, r in enumerate(existing[1:], start=2):
        if r and r[0] == date_val:
            ws.update(f"A{i}:H{i}", [row], value_input_option="USER_ENTERED")
            return i
    ws.append_row(row, value_input_option="USER_ENTERED")
    return len(existing) + 1


def format_markdown(t: dict, date_str: str) -> str:
    dt = datetime.fromtimestamp((t.get("date") or 0) / 1000, tz=SGT)
    duration = round(float(t.get("duration") or 0), 1)
    attendees = t.get("meeting_attendees") or []
    summary = t.get("summary") or {}
    overview = (summary.get("overview") or "").strip()
    action_items = (summary.get("action_items") or "").strip()
    keywords = summary.get("keywords") or []

    lines = [
        f"# CO Apps Meeting -- {date_str}",
        "",
        f"- **Title:** {t.get('title', 'CO Apps Meeting')}",
        f"- **When:** {dt.strftime('%Y-%m-%d %H:%M SGT')}",
        f"- **Duration:** {duration} min",
        f"- **Organizer:** {t.get('organizer_email') or 'unknown'}",
        f"- **Transcript ID:** `{t.get('id', '')}`",
        "",
        "## Attendance",
        "",
    ]
    if attendees:
        for a in attendees:
            name = a.get("displayName") or a.get("email") or "Unknown"
            email = a.get("email") or ""
            lines.append(f"- {name}" + (f" ({email})" if email and email != name else ""))
    else:
        lines.append("_No attendee data available_")

    lines += ["", "## Summary", "", overview or "_No summary available._"]
    lines += ["", "## Action Items", "", action_items or "_No action items recorded._"]

    if keywords:
        kw = ", ".join(str(k) for k in keywords[:20])
        lines += ["", "## Keywords", "", kw]

    return "\n".join(lines) + "\n"


def write_markdown(md: str, date_str: str) -> Path | None:
    if not DASHBOARD_REPO.exists():
        return None
    swarm_dir = DASHBOARD_REPO / "swarm-reports"
    swarm_dir.mkdir(parents=True, exist_ok=True)
    path = swarm_dir / f"{date_str}-meeting.md"
    path.write_text(md)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--transcript-id")
    ap.add_argument("--date", default=datetime.now(SGT).strftime("%Y-%m-%d"))
    ap.add_argument("--sheet-id", default=SHEET_ID)
    args = ap.parse_args()

    if not os.environ.get("FIREFLIES_API_KEY"):
        print("FIREFLIES_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    t = find_transcript(args.transcript_id, args.date)
    if not t:
        print(f"No CO Apps transcript found for {args.date}", file=sys.stderr)
        sys.exit(2)

    dt = datetime.fromtimestamp((t.get("date") or 0) / 1000, tz=SGT)
    date_str = dt.strftime("%Y-%m-%d")
    time_str = dt.strftime("%H:%M")
    attendees = t.get("meeting_attendees") or []
    attendee_names = ", ".join([a.get("displayName") or a.get("email") or "Unknown" for a in attendees])
    summary = t.get("summary") or {}

    # Sheet row
    sys.path.insert(0, str(Path.home() / "Documents/New project/tools"))
    from lib.sheets import get_sheets_client  # type: ignore

    gc = get_sheets_client()
    ss = gc.open_by_key(args.sheet_id)
    ws = ensure_log_tab(ss)
    row = [
        date_str,
        time_str,
        t.get("title") or "CO Apps Meeting",
        round(float(t.get("duration") or 0), 1),
        attendee_names or "(none)",
        (summary.get("overview") or "").strip()[:500],
        (summary.get("action_items") or "").strip()[:1500],
        t.get("id") or "",
    ]
    upsert_row(ws, row)

    # Markdown file in dashboard repo
    md = format_markdown(t, date_str)
    md_path = write_markdown(md, date_str)

    print(json.dumps({
        "date": date_str,
        "transcript_id": t.get("id"),
        "attendees": len(attendees),
        "duration_min": round(float(t.get("duration") or 0), 1),
        "sheet_tab": LOG_TAB,
        "markdown_path": str(md_path) if md_path else None,
    }))


if __name__ == "__main__":
    main()
