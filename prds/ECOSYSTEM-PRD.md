# PRD: Catalyst Outsourcing (CO) Apps Ecosystem

Version: 1.0
Date: 2026-04-07
Status: Active
Owner: Leo Tan

---

## 1. Introduction

Catalyst Outsourcing (CO) is a virtual assistant outsourcing business. The CO Apps ecosystem is a suite of 5 interconnected web applications that power the full lifecycle -- from marketing and sales, through client onboarding and VA management, to time tracking and partner referrals.

This document defines the ecosystem-level architecture, how the apps connect, shared infrastructure, and the product vision for the platform as a whole.

---

## 2. Vision

**One platform for the entire VA outsourcing lifecycle.** A client should be able to discover CO (marketing site), sign up and pay (sales portal), manage their VA team (client dashboard), track work output (time tracker), and refer partners (partner hub) -- all with a single identity and seamless experience.

---

## 3. Goals

| ID | Goal | Success Metric |
|----|------|----------------|
| E-01 | Single sign-on across all apps | Users log in once and move between apps without re-authenticating |
| E-02 | End-to-end client lifecycle | Lead -> payment -> VA assignment -> daily tracking -> invoicing in < 48 hours |
| E-03 | Full VA accountability | 100% of billable hours tracked with task associations and optional screenshots |
| E-04 | Self-serve client experience | Clients manage VAs, view reports, and pay invoices without contacting support |
| E-05 | Scalable partner channel | Affiliates can refer clients and track commissions independently |

---

## 4. The Five Apps

### 4.1 Catalyst Opus (Client Dashboard)
- **Purpose:** Central workspace for clients and VAs -- task management, messaging, hiring, invoicing, credential sharing
- **Role:** SSO authority (OAuth 2.0 PKCE server)
- **Users:** Admins, Clients, Virtual Assistants
- **Repo:** `leotansingapore/catalyst-opus`
- **PRD:** [catalyst-opus/PRD.md](catalyst-opus/PRD.md)

### 4.2 HourHive Buddy (Time Tracker)
- **Purpose:** Time tracking, EOD reports, screenshots, payroll, productivity analytics
- **Role:** SSO consumer (authenticates via Catalyst Opus)
- **Users:** Admins, Clients, Virtual Assistants
- **Repo:** `leotansingapore/hourhive-buddy`
- **PRD:** [hourhive-buddy/PRD.md](hourhive-buddy/PRD.md)

### 4.3 Sales Portal (Outsource Sales Portal)
- **Purpose:** CRM, lead management, proposals, Stripe payments, client onboarding
- **Role:** Entry point for new clients
- **Users:** Salespeople, Admins, Recruiters (notified on payment)
- **Repo:** `leotansingapore/outsource-sales-portal-magic`
- **PRD:** [outsource-sales-portal-magic/PRD.md](outsource-sales-portal-magic/PRD.md)

### 4.4 Catalyst Refresh Glow (Marketing Website)
- **Purpose:** Public-facing marketing site with service pages, pricing, SEO, and lead capture
- **Role:** Top of funnel -- drives traffic to Sales Portal
- **Users:** Prospective clients (public)
- **Repo:** `leotansingapore/catalyst-refresh-glow`
- **PRD:** [catalyst-refresh-glow/PRD.md](catalyst-refresh-glow/PRD.md)

### 4.5 Partner Hub
- **Purpose:** Affiliate and admin portal for referral tracking, commissions, and partner resources
- **Role:** Partner channel management
- **Users:** Affiliates, Admin
- **Repo:** `leotansingapore/partner-hub-40`
- **PRD:** [partner-hub-40/PRD.md](partner-hub-40/PRD.md)

---

## 5. Architecture

### 5.1 System Map

```
                    +---------------------------+
                    |   Catalyst Refresh Glow   |
                    |    (Marketing Website)     |
                    |   SEO, pricing, content    |
                    +-------------|-------------+
                                  | leads
                                  v
+----------------+    +---------------------------+    +----------------+
|  Partner Hub   |--->|      Sales Portal          |--->| Recruiter      |
| (Affiliates)   |ref |  CRM, proposals, Stripe   |    | (notification) |
+----------------+    +-------------|-------------+    +----------------+
                                  | new client
                                  v
                    +---------------------------+
                    |      Catalyst Opus         |
                    |    (Client Dashboard)      |
                    |  Tasks, messaging, hiring  |
                    |  Invoicing, credentials    |
                    |  === SSO Authority ===     |
                    +-------------|-------------+
                                  | OAuth PKCE
                                  v
                    +---------------------------+
                    |     HourHive Buddy         |
                    |    (Time Tracker)          |
                    |  EOD reports, screenshots  |
                    |  Payroll, analytics        |
                    |  Desktop agent (Python)    |
                    +---------------------------+
```

### 5.2 Authentication Flow

Catalyst Opus is the **SSO authority**. It runs an OAuth 2.0 server with PKCE.

1. User opens any app (e.g., HourHive Buddy)
2. App redirects to Catalyst Opus consent screen
3. User authenticates on Catalyst Opus
4. Catalyst Opus issues access token + refresh token
5. App exchanges code for tokens via secure proxy edge function
6. App auto-provisions user locally via `sso-user-sync`

**No app has its own login screen** (except Sales Portal which has a separate admin auth for salespeople).

### 5.3 Data Architecture

Each app has its **own independent Supabase instance** (separate PostgreSQL databases). There are no shared tables.

| App | Supabase Project | Tables | Edge Functions |
|-----|-----------------|--------|---------------|
| Catalyst Opus | `gouyeamixsggakvlotku` | 300+ | 22+ |
| HourHive Buddy | `sxhtuparcfyldbcymxz` | 70+ | 28 |
| Sales Portal | `nkvmvtndwgmkwcabqojb` | 100+ | 45+ |
| Catalyst Refresh Glow | (static site) | -- | -- |
| Partner Hub | (own Supabase) | TBD | TBD |

**Cross-app data sync:**
- **Common key:** User email / UUID links records across databases
- **Catalyst Opus -> HourHive:** OAuth tokens carry scopes for data access. HourHive reads routines, assignments, and client data via `sso-data-access` edge function.
- **Sales Portal -> Catalyst Opus:** New client records synced after Stripe payment via webhook to recruiter project.
- **Sales Portal -> Partner Hub:** Referral attribution tracked via affiliate codes.

### 5.4 Shared Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18 + TypeScript + Vite + Tailwind + shadcn/ui |
| Backend | Supabase (PostgreSQL + Edge Functions + Auth + Storage) |
| Payments | Stripe |
| Auth | OAuth 2.0 PKCE (Catalyst Opus as authority) |
| AI Dev | Lovable / GPT Engineer for rapid prototyping |
| Deployment | Lovable Cloud / Vercel |
| Source Control | GitHub (`leotansingapore/*`) |

---

## 6. Client Lifecycle

```
1. DISCOVER    -> Catalyst Refresh Glow (marketing site, SEO)
2. EVALUATE    -> Catalyst Refresh Glow (pricing, case studies)
3. SIGN UP     -> Sales Portal (proposal, Stripe payment)
4. ONBOARD     -> Catalyst Opus (admin assigns VA, sets up workspace)
5. DAILY WORK  -> Catalyst Opus (tasks, messaging) + HourHive (time tracking)
6. REPORTING   -> HourHive (EOD reports, screenshots, analytics)
7. BILLING     -> HourHive (payroll) + Catalyst Opus (client invoicing)
8. REFER       -> Partner Hub (affiliate link, commission tracking)
```

---

## 7. Ecosystem-Level Requirements

### 7.1 Cross-App

| ID | Requirement |
|----|-------------|
| ER-01 | SSO must work seamlessly -- user logs into one app and is authenticated in all apps |
| ER-02 | User role changes in Catalyst Opus must propagate to HourHive within 1 session |
| ER-03 | New client payment in Sales Portal must trigger notification to recruiter/admin within 5 minutes |
| ER-04 | Marketing site must link directly to Sales Portal with UTM tracking preserved |
| ER-05 | Partner referral codes must persist through the full signup flow |

### 7.2 Data Integrity

| ID | Requirement |
|----|-------------|
| ER-06 | No shared database tables -- all cross-app data flows via APIs or webhooks |
| ER-07 | User email is the canonical identifier across all apps |
| ER-08 | Each app must function independently if other apps are down |
| ER-09 | All financial data (invoices, payroll, payments) must have audit trails |

### 7.3 Operations

| ID | Requirement |
|----|-------------|
| ER-10 | Weekly meeting automation tracks progress across all 5 repos |
| ER-11 | PRDs maintained centrally in co-apps-dashboard repo |
| ER-12 | Post-meeting action items auto-created as GitHub issues |

---

## 8. Non-Goals (Ecosystem Level)

- No single monolithic app -- the 5 apps remain independent deployable units
- No shared database -- each app owns its data
- No centralized admin panel that controls all apps -- each app has its own admin
- No mobile apps (yet) -- web-first with responsive design
- No real-time cross-app data streaming -- sync is request-based

---

## 9. Milestones

| Phase | Focus | Status |
|-------|-------|--------|
| Phase 1 | Core apps built (Catalyst Opus + HourHive) | Done |
| Phase 2 | SSO integration between Opus and HourHive | Done |
| Phase 3 | Sales Portal with Stripe payments | Done |
| Phase 4 | Marketing website (Catalyst Refresh Glow) | Done |
| Phase 5 | Partner Hub (affiliates) | In Progress |
| Phase 6 | Desktop agent for HourHive (Windows/macOS/Linux) | In Progress |
| Phase 7 | Cross-app analytics dashboard | Planned |
| Phase 8 | Client self-service onboarding (no admin intervention) | Planned |

---

## 10. Open Questions

1. Should Partner Hub authenticate via Catalyst Opus SSO or maintain its own auth?
2. Should the marketing site be a separate app or a route within the Sales Portal?
3. What is the long-term plan for the desktop agent -- keep Python or move to Electron/Tauri?
4. Should there be a unified admin dashboard that shows metrics across all 5 apps?
5. How should we handle client data deletion (GDPR-style) across 4 independent databases?

---

## 11. Related Documents

- [Catalyst Opus PRD](catalyst-opus/PRD.md)
- [HourHive Buddy PRD](hourhive-buddy/PRD.md)
- [Sales Portal PRD](outsource-sales-portal-magic/PRD.md)
- [Catalyst Refresh Glow PRD](catalyst-refresh-glow/PRD.md)
- [Partner Hub PRD](partner-hub-40/PRD.md)
- [HourHive Integration Spec](catalyst-opus/HOURHIVE-INTEGRATION.md)
