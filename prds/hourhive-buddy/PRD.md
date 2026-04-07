# PRD: HourHive Buddy (Time Tracker)

Version: 1.0
Date: 2026-04-07
Status: Active
Owner: Leo Tan
Lead Developer: Jilian Garette

---

## 1. Introduction

HourHive Buddy is the time tracking and VA management platform for Catalyst Outsourcing. It provides end-to-end tracking of virtual assistant work -- from automated activity monitoring via a desktop agent, through daily reporting and productivity analytics, to payroll processing and invoicing.

It authenticates via Catalyst Opus (OAuth PKCE SSO) and syncs data bidirectionally with the client dashboard.

---

## 2. Goals

| ID | Goal | Success Metric |
|----|------|----------------|
| G-01 | Track 100% of VA billable hours with task associations | Zero unlogged billable hours per VA per month |
| G-02 | Automate EOD reporting from desktop activity data | < 5 min per VA to submit daily report |
| G-03 | Give clients real-time visibility into VA work | Clients check dashboard at least 3x/week |
| G-04 | Automate payroll calculation from tracked hours | Payroll processed in < 1 hour for all VAs |
| G-05 | Support multi-client VA assignments with separate billing | Each client billed accurately for their VA hours only |

---

## 3. User Roles

### Admin
- Manages all clients, VAs, and assignments
- Processes payroll and generates invoices
- Monitors desktop agent health and productivity metrics
- Configures platform settings, alerts, and incentive programs

### Client
- Views assigned VAs and their daily reports
- Tracks hour package consumption (allocated vs used)
- Approves leave requests
- Downloads invoices

### Virtual Assistant (VA)
- Submits daily EOD reports (hours, tasks, notes)
- Runs desktop agent for automatic time tracking
- Views work history and earnings
- Submits leave requests and incentive claims

---

## 4. User Stories

### US-001: VA submits end-of-day report
**Description:** As a VA, I want to submit my daily work report so my client and admin can see what I accomplished.

**Acceptance Criteria:**
- [ ] VA selects client, enters hours worked, billable hours, and task list
- [ ] Report saves to `daily_reports` table with VA and client IDs
- [ ] Report appears in client's Reports page
- [ ] Admin can view all reports in admin Reports dashboard
- [ ] Optional: attach screenshots from desktop agent

### US-002: Client views hour package status
**Description:** As a client, I want to see how many hours I've used vs allocated so I know my budget status.

**Acceptance Criteria:**
- [ ] Dashboard shows total hours, hours used, hours remaining, burn rate
- [ ] Visual progress bar with color thresholds (green/yellow/red)
- [ ] Alerts at 80%, 95%, 100% depletion

### US-003: Admin processes payroll
**Description:** As an admin, I want to calculate VA payroll from tracked hours so I can pay them accurately.

**Acceptance Criteria:**
- [ ] Payroll page shows each VA's hours, rate, and calculated amount
- [ ] Supports both hourly and fixed-monthly payment models
- [ ] Admin can add adjustments (bonuses, deductions) with notes
- [ ] Generates payroll record with audit trail
- [ ] VA sees payment in their Invoice Receiver page

### US-004: Desktop agent tracks activity
**Description:** As a VA, I want the desktop agent to automatically track my work activity so I don't have to log hours manually.

**Acceptance Criteria:**
- [ ] Agent captures keyboard/mouse activity every 5-30 seconds
- [ ] Agent takes screenshots at configured intervals
- [ ] Activity data syncs to Supabase when online
- [ ] Offline mode: stores data locally and syncs when reconnected
- [ ] Agent shows in system tray with timer display

### US-005: Admin assigns VA to client
**Description:** As an admin, I want to assign a VA to a client with specific billing rates.

**Acceptance Criteria:**
- [ ] Admin selects VA and client, sets payment type (hourly/fixed)
- [ ] Sets hourly rate (VA payment) and billing rate (client charge)
- [ ] Sets monthly hours cap if applicable
- [ ] Assignment appears in both client and VA dashboards

### US-006: VA submits leave request
**Description:** As a VA, I want to request time off so my client and admin are aware.

**Acceptance Criteria:**
- [ ] VA selects date range and enters reason
- [ ] Request shows as pending until admin approves/rejects
- [ ] Approved leave excluded from billable hours
- [ ] Client notified of approved leave

### US-007: Client views VA productivity
**Description:** As a client, I want to see my VA's productivity metrics so I can assess their performance.

**Acceptance Criteria:**
- [ ] Shows hours logged per day/week/month
- [ ] Activity heatmap (active vs idle time)
- [ ] Billable vs non-billable breakdown
- [ ] Optional: screenshot timeline for verification

### US-008: Public shareable report
**Description:** As a client, I want to share a VA's report summary via a public link.

**Acceptance Criteria:**
- [ ] Admin generates a token-gated public URL
- [ ] URL shows VA report calendar, hours summary
- [ ] Optional: include/exclude screenshots
- [ ] Link expires after configured duration

---

## 5. Functional Requirements

### Core Time Tracking
- FR-01: Desktop agent tracks keyboard, mouse, and window focus events
- FR-02: Agent captures screenshots at configurable intervals (5-30 seconds)
- FR-03: Agent operates offline-first with SQLite storage and 7-day backup rotation
- FR-04: Agent syncs data to Supabase in batches when online
- FR-05: Agent provides system tray UI with timer, pause/resume, and client selection

### Reporting
- FR-06: VAs submit EOD reports with hours, billable hours, tasks, and notes
- FR-07: Reports linked to client and VA via `daily_reports` table
- FR-08: Admin can view all reports with date/VA/client filtering
- FR-09: Reports exportable as PDF
- FR-10: AI-powered work summary generation (optional)

### Hour Packages
- FR-11: Clients have hour packages with total hours, used hours, and period dates
- FR-12: System auto-deducts hours from package as reports are submitted
- FR-13: Alerts triggered at 80%, 95%, 100% depletion thresholds
- FR-14: Multiple concurrent packages supported per client

### Payroll & Invoicing
- FR-15: Admin calculates payroll from tracked hours x rate per VA
- FR-16: Supports hourly and fixed-monthly payment models
- FR-17: Admin adds adjustments (bonuses, deductions) to payroll records
- FR-18: VA invoices generated with line items, deductions, net payment
- FR-19: Client invoices generated with hourly breakdown and tax

### Leave & Incentives
- FR-20: VAs submit leave requests with date range and reason
- FR-21: Admin approves/rejects leave requests
- FR-22: Incentive programs definable per VA (bonuses, commissions)
- FR-23: VAs submit incentive claims for admin review

### Monitoring
- FR-24: Admin views desktop agent presence (online/offline per VA)
- FR-25: Agent errors logged and surfaced in admin dashboard
- FR-26: Agent version management with auto-update mechanism

---

## 6. Non-Goals

- No project management features (tasks/kanban live in Catalyst Opus)
- No messaging or chat (handled by Catalyst Opus)
- No client onboarding or payment collection (handled by Sales Portal)
- No hiring pipeline (handled by Catalyst Opus)
- No mobile app for time tracking (desktop agent + web only)
- No automatic VA matching/recommendation

---

## 7. Technical Considerations

### Authentication
- SSO via Catalyst Opus OAuth PKCE -- no local login screen
- Token proxy via `oauth-token-proxy` edge function (injects client secret server-side)
- Auto-provisioning via `sso-user-sync` on first login
- Refresh tokens with 60-second pre-expiry auto-refresh

### Database
- Supabase project: `sxhtuparcfyldbcymxz`
- 70+ tables with RLS policies
- Key tables: `profiles`, `clients`, `client_va_assignments`, `daily_reports`, `hour_packages`, `payroll_records`, `va_invoices`, `activity_metrics`, `timer_screenshots`
- Never FK directly to `auth.users` (SSO tokens don't match local auth IDs)

### Desktop Agent
- Python-based, cross-platform (Windows, macOS, Linux)
- `.pyc` bytecode distribution via GitHub Actions
- Install scripts: `install.bat` (Windows), `install.sh` (macOS/Linux)
- Releases stored in Supabase Storage `agent-binaries` bucket

### API Gateway
- `sso-data-access` edge function: 50+ actions, action-based dispatch
- Bearer token auth from SSO
- 25-second timeout on SSO transitions (self-healing)

---

## 8. Integration Points

| Integration | Direction | Mechanism |
|-------------|-----------|-----------|
| Catalyst Opus SSO | HourHive <- Opus | OAuth PKCE token exchange |
| Routine completions | HourHive -> Opus | `sso-data-access` API write-back |
| VA assignments | Opus -> HourHive | Token scopes carry assignment data |
| Stripe payments | HourHive <- Stripe | Webhook for payment processing |
| Desktop agent | Agent -> HourHive | REST API batch sync |

---

## 9. Success Metrics

| Metric | Target |
|--------|--------|
| VA daily report submission rate | > 95% of working days |
| Desktop agent uptime during work hours | > 90% |
| Time from EOD to report submission | < 5 minutes |
| Payroll processing time (all VAs) | < 1 hour |
| Client dashboard visit frequency | > 3x per week |
| Hour package accuracy (tracked vs invoiced) | 100% match |

---

## 10. Current Status

| Feature | Status |
|---------|--------|
| Core dashboards (admin, client, VA) | Done |
| EOD report submission | Done |
| Hour package management | Done |
| Payroll & invoicing | Done |
| Leave management | Done |
| Incentive programs | Done |
| SSO integration with Catalyst Opus | Done |
| Public sharing (reports, dashboards) | Done |
| Desktop agent (code complete) | Done |
| Desktop agent (end-to-end tested, auto-update) | In Progress |
| Discord/Slack webhook integrations | In Progress |
| Productivity analytics AI | Planned |

---

## 11. Open Questions

1. Should the desktop agent support per-project time tracking (not just per-client)?
2. How should we handle timezone differences between clients and VAs for report dates?
3. Should VAs be able to edit submitted reports, or is it admin-only?
4. What is the data retention policy for screenshots (storage cost concern)?
5. Should HourHive have its own notification system or rely on Catalyst Opus notifications?
