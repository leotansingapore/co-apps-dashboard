#!/usr/bin/python3
"""
Regenerate index.html for the co-apps-dashboard GitHub Pages site.
Reads swarm-reports/*.md and prds/ to populate dynamic sections.
"""
from __future__ import annotations

import re
import sys
from datetime import datetime
from pathlib import Path

REPO = Path.home() / ".local/share/co-apps-meeting/dashboard-repo"
APPS = [
    {"name": "Catalyst Opus", "slug": "catalyst-opus",
     "desc": "Client dashboard -- task management, messaging, hiring pipeline, invoicing, OAuth SSO authority.",
     "owner": "Warren"},
    {"name": "HourHive Buddy", "slug": "hourhive-buddy",
     "desc": "Time tracker -- EOD reports, screenshots, payroll, leave requests, productivity analytics.",
     "owner": "Jilian"},
    {"name": "Sales Portal", "slug": "outsource-sales-portal-magic",
     "desc": "CRM + onboarding -- lead management, proposals, Stripe payments, recruiter notifications.",
     "owner": None},
    {"name": "Catalyst Refresh Glow", "slug": "catalyst-refresh-glow",
     "desc": "Marketing website -- service pages, SEO, lead capture, pricing.",
     "owner": None},
    {"name": "Partner Hub", "slug": "partner-hub-40",
     "desc": "Affiliate + admin portal -- referral tracking, commissions, partner resources.",
     "owner": None},
]


def list_swarm_reports():
    swarm = REPO / "swarm-reports"
    if not swarm.exists():
        return []
    files = sorted(swarm.glob("*.md"), reverse=True)
    return files[:8]


def extract_summary(md_path: Path) -> str:
    try:
        text = md_path.read_text()
    except Exception:
        return ""
    m = re.search(r"^##\s+Summary\s*$\n+(.+?)(?=^##\s|\Z)", text, re.M | re.S)
    if m:
        summary = m.group(1).strip()
        return summary[:300] + ("..." if len(summary) > 300 else "")
    return text.split("\n", 1)[0].lstrip("# ").strip()[:200]


def apps_cards_html() -> str:
    parts = []
    for a in APPS:
        owner_html = f'<span class="owner">Owner: {a["owner"]}</span>' if a["owner"] else ""
        prd_path = f"prds/{a['slug']}/PRD.md"
        prd_exists = (REPO / prd_path).exists()
        prd_link = f'<a class="pill" href="{prd_path}">PRD</a>' if prd_exists else '<span class="pill muted">PRD soon</span>'
        parts.append(f"""
  <div class="card">
    <h3>{a['name']}</h3>
    <p>{a['desc']}</p>
    {owner_html}
    <div class="links">
      {prd_link}
      <a class="pill" href="https://github.com/leotansingapore/{a['slug']}">Repo</a>
    </div>
  </div>""")
    return "".join(parts)


def meetings_list_html() -> str:
    reports = list_swarm_reports()
    if not reports:
        return '<p class="sub">No meeting logs yet. Check back after Tuesday 16:00 SGT.</p>'
    rows = []
    for r in reports:
        name = r.stem
        summary = extract_summary(r) or "No summary available."
        rows.append(f'<div class="card"><h3><a href="swarm-reports/{r.name}">{name}</a></h3><p>{summary}</p></div>')
    return '<div class="grid grid-2">' + "".join(rows) + "</div>"


def render() -> str:
    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>CO Apps Dashboard</title>
<style>
  :root {{
    --bg: #0b0d12; --panel: #12151c; --panel-2: #171b24;
    --border: #232834; --text: #e6e8ee; --muted: #8a92a3;
    --accent: #6ea8ff; --accent-2: #7ae0b6;
  }}
  * {{ box-sizing: border-box; }}
  html, body {{ margin: 0; padding: 0; background: var(--bg); color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
    font-size: 15px; line-height: 1.55; }}
  a {{ color: var(--accent); text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  .wrap {{ max-width: 1100px; margin: 0 auto; padding: 32px 20px 80px; }}
  header {{ display: flex; align-items: baseline; justify-content: space-between; flex-wrap: wrap; gap: 8px; margin-bottom: 28px; }}
  h1 {{ font-size: 24px; margin: 0; letter-spacing: -0.01em; }}
  .sub {{ color: var(--muted); font-size: 13px; }}
  h2 {{ font-size: 14px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); margin: 32px 0 12px; font-weight: 600; }}
  .grid {{ display: grid; gap: 12px; }}
  .grid-2 {{ grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); }}
  .grid-3 {{ grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); }}
  .card {{ background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; }}
  .card h3 {{ margin: 0 0 4px; font-size: 15px; font-weight: 600; }}
  .card p {{ margin: 0; color: var(--muted); font-size: 13px; }}
  .card .owner {{ display: inline-block; margin-top: 8px; font-size: 11px; color: var(--accent-2); background: rgba(122,224,182,0.08); padding: 2px 8px; border-radius: 999px; }}
  .links {{ display: flex; gap: 10px; flex-wrap: wrap; margin-top: 10px; font-size: 13px; }}
  .pill {{ background: var(--panel-2); border: 1px solid var(--border); padding: 4px 10px; border-radius: 6px; }}
  .pill.muted {{ color: var(--muted); }}
  .quick {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 10px; }}
  .quick a {{ display: block; background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; color: var(--text); }}
  .quick a .l {{ font-size: 13px; color: var(--muted); display: block; margin-bottom: 2px; }}
  .quick a:hover {{ border-color: var(--accent); text-decoration: none; }}
  .flow {{ background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 16px; font-family: "SF Mono", ui-monospace, Menlo, monospace; font-size: 12.5px; color: var(--muted); white-space: pre; overflow-x: auto; }}
  footer {{ margin-top: 48px; color: var(--muted); font-size: 12px; text-align: center; }}
  .badge {{ display: inline-block; font-size: 11px; background: var(--panel-2); border: 1px solid var(--border); padding: 2px 8px; border-radius: 999px; color: var(--muted); margin-left: 8px; }}
</style>
</head>
<body>
<div class="wrap">

<header>
  <div>
    <h1>CO Apps Dashboard <span class="badge">weekly meeting hub</span></h1>
    <div class="sub">Central hub for the Catalyst Outsource (CO) ecosystem -- PRDs, architecture, and weekly meeting automation.</div>
  </div>
</header>

<h2>Quick Links</h2>
<div class="quick">
  <a href="https://meet.google.com/igs-arbe-ntm" target="_blank"><span class="l">Weekly sync</span>Google Meet &rarr;</a>
  <a href="https://docs.google.com/spreadsheets/d/1HaT_811PWs-4p-uc4VUM-i6PYLRbwV0YHjt8DjWfIiM" target="_blank"><span class="l">Tracking</span>Meeting Sheet &rarr;</a>
  <a href="prds/ECOSYSTEM-PRD.md"><span class="l">Strategy</span>Ecosystem PRD &rarr;</a>
  <a href="architecture.excalidraw"><span class="l">Diagram</span>Architecture (.excalidraw) &rarr;</a>
  <a href="swarm-reports/"><span class="l">Weekly</span>Swarm Reports &rarr;</a>
  <a href="https://github.com/leotansingapore/co-apps-dashboard"><span class="l">Source</span>GitHub repo &rarr;</a>
</div>

<h2>The Ecosystem</h2>
<div class="grid grid-2">{apps_cards_html()}
</div>

<h2>How They Connect</h2>
<div class="flow">Sales Portal (lead enters) --> Catalyst Opus (client + VA workspace)
                                    |
                         OAuth SSO (auth authority)
                                    |
                            HourHive Buddy (time tracking + EOD reports)

Catalyst Refresh Glow (marketing) --> Sales Portal (conversion)
Partner Hub (affiliates) --> Sales Portal (referral tracking)</div>

<h2>Recent Meetings</h2>
{meetings_list_html()}

<h2>Weekly Automation</h2>
<div class="grid grid-3">
  <div class="card"><h3>Tue 15:00 reminder</h3><p>Pre-meeting ping in Lark with last week's action items.</p></div>
  <div class="card"><h3>Tue 15:30 agenda</h3><p>Scrum master: 7-day GitHub activity summary across 5 repos.</p></div>
  <div class="card"><h3>Tue 17:30 post-meeting</h3><p>Fireflies transcript &rarr; sheet auto-fill, issue creation, meeting log.</p></div>
  <div class="card"><h3>Thu 10:00 midweek ping</h3><p>GitHub activity nudge if progress has stalled.</p></div>
  <div class="card"><h3>Fri 17:00 digest</h3><p>Week in review with merged PRs, open issues, and blockers.</p></div>
  <div class="card"><h3>Dashboard auto-sync</h3><p>This page regenerates after post-meeting and midweek runs.</p></div>
</div>
<p class="sub" style="margin-top:10px">Scripts in <a href="automation/">automation/</a>, scheduled via launchd.</p>

<footer>
  Auto-generated {now} &middot; <a href="https://github.com/leotansingapore/co-apps-dashboard">leotansingapore/co-apps-dashboard</a>
</footer>

</div>
</body>
</html>
"""


def main():
    if not REPO.exists():
        print(f"Dashboard repo not found at {REPO}", file=sys.stderr)
        sys.exit(1)
    (REPO / "index.html").write_text(render())
    print(f"Wrote {REPO / 'index.html'}")


if __name__ == "__main__":
    main()
