# CO Apps Dashboard

Central hub for the Catalyst Outsource (CO) Apps ecosystem -- product requirements, architecture diagrams, and weekly meeting automation.

## Quick Links

| What | Link |
|------|------|
| **Google Meet (weekly)** | https://meet.google.com/igs-arbe-ntm |
| **Meeting Sheet** | https://docs.google.com/spreadsheets/d/1HaT_811PWs-4p-uc4VUM-i6PYLRbwV0YHjt8DjWfIiM |
| **Ecosystem PRD** | [prds/ECOSYSTEM-PRD.md](prds/ECOSYSTEM-PRD.md) |
| **All PRDs** | [prds/](prds/) |

| App PRD | Repo |
|---------|------|
| [Catalyst Opus PRD](prds/catalyst-opus/PRD.md) | [catalyst-opus](https://github.com/leotansingapore/catalyst-opus) |
| [HourHive Buddy PRD](prds/hourhive-buddy/PRD.md) | [hourhive-buddy](https://github.com/leotansingapore/hourhive-buddy) |
| [Sales Portal PRD](prds/outsource-sales-portal-magic/PRD.md) | [outsource-sales-portal-magic](https://github.com/leotansingapore/outsource-sales-portal-magic) |
| [Catalyst Refresh Glow PRD](prds/catalyst-refresh-glow/PRD.md) | [catalyst-refresh-glow](https://github.com/leotansingapore/catalyst-refresh-glow) |
| [Partner Hub PRD](prds/partner-hub-40/PRD.md) | [partner-hub-40](https://github.com/leotansingapore/partner-hub-40) |

## The Ecosystem

Five apps that power CO's virtual assistant outsourcing business:

| App | What it does | Owner | Repo |
|-----|-------------|-------|------|
| **Catalyst Opus** | Client dashboard -- task management, messaging, hiring pipeline, invoicing, OAuth SSO authority | Warren | [catalyst-opus](https://github.com/leotansingapore/catalyst-opus) |
| **HourHive Buddy** | Time tracker -- EOD reports, screenshots, payroll, leave requests, productivity analytics | Jilian | [hourhive-buddy](https://github.com/leotansingapore/hourhive-buddy) |
| **Sales Portal** | CRM + onboarding -- lead management, proposals, Stripe payments, recruiter notifications | -- | [outsource-sales-portal-magic](https://github.com/leotansingapore/outsource-sales-portal-magic) |
| **Catalyst Refresh Glow** | Marketing website -- service pages, SEO, lead capture, pricing | -- | [catalyst-refresh-glow](https://github.com/leotansingapore/catalyst-refresh-glow) |
| **Partner Hub** | Affiliate + admin portal -- referral tracking, commissions, partner resources | -- | [partner-hub-40](https://github.com/leotansingapore/partner-hub-40) |

### How they connect

```
Sales Portal (lead enters) --> Catalyst Opus (client + VA workspace)
                                    |
                         OAuth SSO (auth authority)
                                    |
                            HourHive Buddy (time tracking + EOD reports)

Catalyst Refresh Glow (marketing) --> Sales Portal (conversion)
Partner Hub (affiliates) --> Sales Portal (referral tracking)
```

- **Shared auth:** Catalyst Opus is the SSO authority via OAuth PKCE. HourHive authenticates through it.
- **Data sync:** EOD reports and time tracking flow from HourHive to Catalyst Opus via `sso-data-access` API.
- **Common key:** User email / UUID links records across all 4 independent Supabase databases.

## Product Requirements (PRDs)

Each app's PRD lives in [`prds/`](prds/):

```
prds/
  catalyst-opus/          # Full PRD + product specs + integration docs
  hourhive-buddy/         # Time tracker requirements
  outsource-sales-portal-magic/  # Sales portal requirements
  catalyst-refresh-glow/  # Marketing site requirements
  partner-hub-40/         # Partner hub requirements
```

## Weekly Meeting Automation

Every Tuesday, three automations run to support the CO Apps weekly scrum call:

| Time (SGT) | What happens | Script |
|------------|-------------|--------|
| **3:00 PM** | Lark reminder sent to the team with Google Meet link | [`co-apps-meeting-reminder.sh`](automation/co-apps-meeting-reminder.sh) |
| **3:30 PM** | Scrum agenda posted to Lark (GitHub activity from all 5 repos) + Google Sheet updated | [`co-apps-scrum-master.sh`](automation/co-apps-scrum-master.sh) |
| **5:30 PM** | Fireflies transcript analyzed, action items become GitHub issues | [`co-apps-post-meeting.sh`](automation/co-apps-post-meeting.sh) |

### What the automation does

1. **Pre-meeting** -- Fetches commits, PRs, and issues from all 5 repos. Uses Claude CLI to generate a scrum-style agenda. Posts to Lark with clickable repo links and a Google Meet button.

2. **Meeting sheet** -- Creates a Google Sheet tab for each meeting with sections for team updates, PRD progress tracking, discussion topics, action items, and AI agent task requests.

3. **Post-meeting** -- Polls Fireflies for the meeting transcript. Analyzes it with Claude CLI to extract decisions, action items, and bugs discussed. Auto-creates GitHub issues with `meeting-action` label on the relevant repos.

### Setup

All scripts are in [`automation/`](automation/) and scheduled via macOS launchd (plists in [`automation/launchd/`](automation/launchd/)).

**Requirements:**
- `gh` CLI authenticated with repo access
- `claude` CLI (Claude Max subscription)
- `FIREFLIES_API_KEY` in `.env`
- `LARK_CO_APPS_WEBHOOK` in `.env`
- Google Sheets service account (`credentials.json`)
- macOS (launchd scheduling)

**Install:**
```bash
# Copy scripts
cp automation/*.sh automation/*.js automation/*.py ~/.local/bin/
chmod +x ~/.local/bin/co-apps-*

# Load launchd agents
cp automation/launchd/*.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.leo.co-apps-*.plist
```

**Manual run:**
```bash
# Send reminder now
~/.local/bin/co-apps-meeting-reminder.sh

# Generate agenda now
~/.local/bin/co-apps-scrum-master.sh

# Analyze transcript (skip polling)
~/.local/bin/co-apps-post-meeting.sh --now
```

### Meeting Google Sheet

The shared meeting sheet is updated each Tuesday with a new tab:

**[Open Meeting Sheet](https://docs.google.com/spreadsheets/d/1HaT_811PWs-4p-uc4VUM-i6PYLRbwV0YHjt8DjWfIiM)**

Sections:
- Follow-ups from last week
- Team updates (what I did / what I'm doing / blockers)
- PRD progress (where we are vs where we want to be)
- Decisions to make
- Open discussion
- New action items
- AI agent tasks (the bot reads this after the meeting)

## Architecture Diagram

The [`architecture.excalidraw`](architecture.excalidraw) file contains a visual overview of the ecosystem. Updated automatically each Tuesday.

## Tech Stack (all apps)

- **Frontend:** React 18 + TypeScript + Vite + Tailwind + shadcn/ui
- **Backend:** Supabase (PostgreSQL + Edge Functions + Auth)
- **Deployment:** Vercel / Lovable Cloud
- **AI:** Claude CLI (Max plan) for meeting analysis
- **Notifications:** Lark webhooks
- **Scheduling:** macOS launchd

## Workflow SOP

Full documentation: [automation/co_apps_meeting.md](automation/co_apps_meeting.md)
