# CO Sales Hub (Catalyst Opus) -- Project Documentation

Version: 1.0
Date: 2026-02-07
Status: Living Document

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [User Roles](#2-user-roles)
3. [System Architecture](#3-system-architecture)
4. [Key Modules](#4-key-modules)

---

## 1. Project Overview

### 1.1 Purpose

CO Sales Hub (internally "Catalyst Opus") is a virtual-assistant management platform. It provides the operational backbone for businesses that delegate work to remote Virtual Assistants (VAs). The platform unifies task management, real-time communication, document collaboration, time tracking, hiring pipelines, and administrative oversight into a single web application.

### 1.2 Target Users

| Persona | Description |
|---------|-------------|
| **Client** | A business owner or team lead who hires one or more VAs to perform delegated work. Clients create tasks, manage projects, review time logs, and communicate with their assigned VAs. |
| **Virtual Assistant (VA)** | A remote worker assigned to one or more Clients. VAs execute tasks, log time, submit daily reports, and collaborate on documents. |
| **Admin** | A platform operator responsible for user onboarding, role assignment, VA-to-Client matching, audit trails, compliance, and system health monitoring. |

### 1.3 Core Problems Solved

1. **Fragmented tooling.** Clients typically juggle Slack, Trello, Google Drive, and spreadsheets. CO Sales Hub consolidates messaging, tasks, documents, SOPs, and time tracking.
2. **Accountability gaps.** Time logs, daily reports, and approval workflows give Clients verifiable proof of work. Admins can audit any activity.
3. **Hiring and assignment overhead.** The built-in job pipeline lets Clients post job requests, and Admins manage applicant screening, interviews, and VA assignment without leaving the platform.
4. **Security and credential sharing.** A password vault with access logging and auto-lock replaces insecure credential sharing over chat.
5. **Cross-platform integration.** An OAuth 2.0 SSO server and API gateway allow external tools (e.g., the CO Time Tracker desktop agent) to authenticate against the same user base and access scoped data.

---

## 2. User Roles

The platform enforces three roles stored in the `user_roles` table. A user may hold exactly one role. Role assignment is managed exclusively by Admins.

### 2.1 Admin

**Goal:** Ensure platform health, enforce policies, manage users, and provide operational oversight.

**Permissions:**
- Create, deactivate, and re-assign any user account.
- View all audit logs, time logs, and support tickets across every Client and VA.
- Manage VA-to-Client assignments (`va_assignments` table).
- Access the job pipeline across all Clients; move applicants between stages.
- View system health indicators, VA capacity alerts, and workload charts.
- Send platform-wide notifications.
- Configure webhooks and external integrations.
- Manage compliance certifications and SLA agreements.
- Access the Admin Messages channel for platform-level discussions.

**Access Limitations:**
- Cannot act as a Client or VA (e.g., cannot create tasks or log time on behalf of another user).
- Cannot modify Supabase-reserved schemas directly.

### 2.2 Client

**Goal:** Delegate and manage work performed by assigned VAs.

**Permissions:**
- Create, assign, and manage tasks and projects within their own scope.
- Create and manage routines (recurring task templates).
- Post job requests; view and interact with their own job pipelines.
- Communicate with assigned VAs via direct messages and group channels.
- Create, upload, and share documents, SOPs, wiki pages, flowcharts, spreadsheets, and rich documents.
- View time logs and daily reports submitted by their assigned VAs.
- Manage a password vault scoped to their account.
- Schedule and manage calendar events.
- Define approval rules for time-log or task workflows.
- Set budgets and goals (`client_budgets`, `client_goals`).
- Configure spaces (project groupings) for workspace organization.
- Invite workspace members (other users under their tenant).

**Access Limitations:**
- Cannot see data belonging to other Clients.
- Cannot assign or unassign VAs (Admin-only).
- Cannot view platform-wide audit logs.
- Cannot access Admin dashboard or people management screens.

### 2.3 Virtual Assistant (VA)

**Goal:** Execute assigned work, report progress, and maintain accountability.

**Permissions:**
- View and update tasks, projects, and routines assigned by their Clients.
- Log time against tasks and submit daily reports.
- Communicate with assigned Clients via direct messages and group channels.
- Access shared documents, SOPs, and wiki pages for Clients they are assigned to.
- View their own analytics dashboard (task completion rates, time distribution).
- Access the shared credential vault for credentials shared by their Clients.
- Manage their own profile, portfolio, and availability schedule.
- View goal trackers set by Admins or themselves.

**Access Limitations:**
- Cannot see other VAs' data (tasks, time logs, reports) unless explicitly shared.
- Cannot access Client-side management screens (budgets, job requests, approval rules).
- Cannot create or delete users.
- Scoped to data for Clients they are actively assigned to (`va_assignments` with `status = 'active'`).

---

## 3. System Architecture

### 3.1 High-Level Diagram

```
+---------------------------+
|        Frontend           |
|  React 18 + TypeScript    |
|  Vite, Tailwind CSS       |
|  React Router v6          |
|  TanStack React Query     |
+------------+--------------+
             |
             | HTTPS / WebSocket
             v
+---------------------------+
|     Backend Services      |
|  Supabase (Lovable Cloud) |
|                           |
|  - Auth (email/password)  |
|  - PostgreSQL Database    |
|  - Realtime (WebSocket)   |
|  - Edge Functions (Deno)  |
|  - Storage (file uploads) |
+---------------------------+
             |
             v
+---------------------------+
|   External Integrations   |
|  - OAuth 2.0 SSO Server   |
|  - API Gateway (REST)     |
|  - Webhook Dispatch       |
|  - Email (SMTP via Edge)  |
+---------------------------+
```

### 3.2 Frontend

| Aspect | Detail |
|--------|--------|
| **Framework** | React 18 with TypeScript |
| **Build tool** | Vite (dev port 8080) |
| **Styling** | Tailwind CSS with shadcn/ui component library |
| **Routing** | React Router v6 with lazy-loaded pages (`lazyWithRetry`) and three persistent layout wrappers (`ClientLayoutWrapper`, `VALayoutWrapper`, `AdminLayoutWrapper`) |
| **State management** | TanStack React Query for server state; React Context for global UI state (`AuthContext`, `SpaceContext`, `LayoutContext`, `SidebarItemsContext`, `RecordingContext`, `WorkspaceContext`) |
| **Rich text** | TipTap editor with 15+ extensions |
| **Diagrams** | React Flow for flowcharts |
| **Animations** | Framer Motion |
| **Internationalization** | i18next with react-i18next |

### 3.3 Backend Services

| Service | Purpose |
|---------|---------|
| **Authentication** | Email/password sign-up and sign-in via Supabase Auth. Session tokens are stored in localStorage. Role information is fetched from `user_roles` on session init. |
| **Database** | PostgreSQL with 150+ tables. Row-Level Security (RLS) enforced on all user-facing tables using the `has_role()` helper function. |
| **Realtime** | Supabase Realtime channels for live message delivery, presence indicators, typing indicators, and call signaling (`call_signals` table). |
| **Edge Functions** | 30 Deno-based serverless functions handling AI chat, email sending, webhook dispatch, analytics computation, link metadata fetching, OAuth token exchange, and more. |
| **Storage** | Supabase Storage buckets for document uploads, message attachments, profile avatars, and screen recordings. |

### 3.4 Authentication Architecture

The platform supports two authentication modes:

1. **Internal authentication.** Users navigate to `/auth`, sign up or sign in with email/password, and are redirected to their role-specific dashboard (`/client/*`, `/va/*`, `/admin/*`). A `catalyst_last_role` localStorage key enables instant skeleton rendering on subsequent visits.

2. **OAuth 2.0 / SSO.** External applications authenticate via the `/oauth/consent` authorization endpoint. The flow uses Authorization Code + PKCE. Tokens are issued by the `oauth-server` edge function and validated by the `api-gateway` edge function. The SSO client library (`src/lib/sso-client/`) provides a framework-agnostic SDK with React hooks.

### 3.5 Database (Conceptual)

The database is organized into the following logical domains:

| Domain | Representative Tables |
|--------|----------------------|
| **Identity and access** | `profiles`, `user_roles`, `va_assignments`, `tenant_members`, `tenants` |
| **Task management** | `tasks`, `task_comments`, `task_attachments`, `task_checklist_items`, `task_dependencies`, `task_templates`, `recurring_task_config` |
| **Projects and spaces** | `projects`, `project_members`, `spaces`, `space_members`, `space_branding` |
| **Messaging** | `messages`, `message_attachments`, `message_reactions`, `message_read_receipts`, `message_drafts`, `chat_groups`, `chat_group_members`, `chat_labels`, `chat_polls`, `poll_votes`, `scheduled_messages`, `recurring_message_config` |
| **Calls** | `call_sessions`, `call_participants`, `call_signals` |
| **Documents** | `documents`, `document_folders`, `document_shares`, `document_links`, `document_comments`, `document_collaborators`, `document_signatures`, `rich_documents`, `flowcharts`, `spreadsheets`, `sops`, `sop_steps`, `sop_versions`, `sop_acknowledgments` |
| **Knowledge base** | `knowledge_articles`, `knowledge_article_versions`, `article_attachments`, `article_bookmarks`, `article_comments`, `article_shares`, `article_links`, `article_view_history` |
| **Wiki** | `wiki_pages` (managed via hooks, content in knowledge_articles or dedicated wiki storage) |
| **Time and reporting** | `time_logs`, `daily_reports`, `analytics_snapshots`, `productivity_insights`, `report_history`, `report_schedules`, `report_templates`, `scheduled_reports` |
| **Hiring pipeline** | `jobs`, `job_pipeline_stages`, `applications`, `application_stage_history`, `job_va_assignments`, `interviews` |
| **Billing and payments** | `hour_packages`, `hour_transactions`, `invoices`, `invoice_line_items`, `invoice_payments`, `payment_plans`, `custom_rates`, `auto_purchase_settings` |
| **Notifications** | `notifications`, `notification_preferences`, `notification_digest`, `notification_snooze`, `admin_notifications_sent` |
| **Calendar** | `calendar_events`, `event_attendees`, `meetings`, `meeting_attendees` |
| **Password vault** | `password_vault`, `password_vault_shares`, `password_vault_access_logs` |
| **Security and credentials** | `password_vault`, `password_vault_shares`, `password_vault_access_logs` |
| **Gamification** | `achievements`, `va_goals` |
| **Compliance and enterprise** | `compliance_certifications`, `sla_agreements`, `tenant_branding`, `departments` |
| **OAuth** | `oauth_clients`, `oauth_tokens`, `oauth_authorizations`, `oauth_user_consents`, `oauth_scopes`, `api_request_logs` |
| **Audit** | `audit_logs` |
| **Support** | `support_tickets`, `support_ticket_comments` |
| **Integrations** | `webhooks`, `webhook_deliveries` |

---

## 4. Key Modules

### 4.1 Authentication and Authorization

Handles user sign-up, sign-in, password reset, session management, and role-based routing. The `AuthContext` provides `isAdmin`, `isClient`, and `isVA` booleans consumed by layout wrappers and route guards. OAuth 2.0 SSO extends authentication to external applications via PKCE.

### 4.2 Messaging

A full-featured real-time messaging system supporting direct messages, group channels, threads, reactions, read receipts, file attachments, voice messages, polls, scheduled messages, recurring messages, message pinning, starring, flagging, labeling, link previews, YouTube embeds, and message summarization (via AI). Channels can be scoped to spaces. Typing indicators and presence are delivered over Supabase Realtime.

### 4.3 Task Management

Kanban-based task boards with drag-and-drop (via dnd-kit). Tasks support assignees, priorities, due dates, checklists, subtasks, comments, attachments, dependencies, SOP links, recurring schedules, and bulk actions. Clients create tasks; VAs update status. Smart search and saved filters allow efficient navigation across large task volumes.

### 4.4 Projects and Spaces

Projects are organizational containers for tasks, documents, and team members. Spaces are higher-level groupings that allow Clients to partition their workspace (e.g., by department or business unit). Space branding customization is supported.

### 4.5 Document Management

A unified document hub supporting five content types: file uploads, rich documents (TipTap editor with real-time collaboration), flowcharts (React Flow), spreadsheets, and screen recordings. Documents are organized in a folder tree with drag-and-drop. Sharing is supported via direct VA shares, public link tokens (with optional password protection and expiry), and bulk operations. A trash/restore system and version history are available.

### 4.6 Standard Operating Procedures (SOPs)

Structured step-by-step procedure documents with versioning, acknowledgment tracking, and task linking. SOPs can be shared with VAs and published via public links. The acknowledgment tracker verifies that all relevant VAs have reviewed and confirmed each SOP version.

### 4.7 Knowledge Base (Wiki)

A wiki system with hierarchical page trees, backlinks, version history, verification badges, AI-powered chat for Q&A against wiki content, search, and templates. Both Clients and VAs can access the wiki scoped to their workspace.

### 4.8 Calendar and Scheduling

A calendar view with event creation, attendees, meeting links, project/space scoping, recurrence rules, reminders, and color coding. Integrates with VA availability slots for scheduling awareness.

### 4.9 Job Pipeline (Hiring)

Clients post job requests specifying role requirements. Admins manage a Kanban-style pipeline with configurable stages. Applications track applicants through screening, interviews, and hiring. Interview scheduling and stage history provide a full audit trail. Job-VA assignments link hired candidates to client accounts.

### 4.10 Time Tracking and Reporting

VAs log time against tasks. Clients and Admins review time logs, daily reports, and analytics snapshots. A report builder supports scheduled report generation and export (PDF via jsPDF). Productivity insights are computed by an edge function and surfaced on dashboards. Approval rules allow Clients to auto-approve or require manual review of time entries.

### 4.11 Billing and Hour Packages

Clients purchase hour packages. Transactions debit hours as VAs log time. Custom hourly rates can be set per VA-Client pair. Invoices, line items, and payment tracking are supported. Auto-purchase settings allow automatic replenishment when hours fall below a threshold.

### 4.12 Password Vault

An encrypted credential storage system. Clients store credentials and share them with specific VAs. Access is logged for audit purposes. An auto-lock feature secures the vault after inactivity.

### 4.13 Routines

Recurring task templates that generate task instances on a defined schedule. Both Clients and VAs can view routines. A template browser provides pre-built routine configurations.

### 4.14 AI Assistant

An AI-powered chat assistant available to all roles. Conversations are persisted in `ai_conversations` and `ai_messages`. Rate limiting is enforced via `ai_rate_limits`. The assistant uses supported Lovable AI models (no user-provided API keys required). A separate wiki-specific AI chat answers questions grounded in knowledge base content.

### 4.15 Notifications

A multi-channel notification system. In-app notifications are stored in the `notifications` table and displayed via a notification center. Email notifications are dispatched by the `send-notification-email` edge function. Users can configure notification preferences, snooze notifications, and receive digest summaries. A smart notification engine prioritizes and batches notifications.

### 4.16 Support Tickets

Users submit support tickets categorized by type. Admins view and respond to tickets. Threaded comments support back-and-forth resolution. Ticket status tracking (open, in-progress, resolved, closed) is enforced.

### 4.17 Admin Dashboard and People Management

Admins access a dashboard with system health indicators, VA capacity alerts, workload charts, and a live activity feed. People management includes user creation, role assignment, profile editing, invitation sending, and VA-Client assignment management. A profiling module provides detailed user analytics.

### 4.18 Audit Logging

All significant actions are recorded in the `audit_logs` table with actor, action, entity type, entity ID, IP address, and user agent. The Admin audit viewer provides searchable, filterable access to the full audit trail.

### 4.19 OAuth SSO Server

A standards-compliant OAuth 2.0 Authorization Server implementing the Authorization Code + PKCE flow. The server issues access tokens, refresh tokens, and ID tokens (JWT). Supported grant types: `authorization_code` and `refresh_token`. Token introspection and revocation endpoints are available. Registered clients and scopes are managed in `oauth_clients` and `oauth_scopes`.

### 4.20 API Gateway

A RESTful API gateway (`api-gateway` edge function) that validates OAuth access tokens and enforces scope-based authorization. Endpoints expose tasks, projects, time logs, VAs, jobs, and assignments to external applications. Request logging is recorded in `api_request_logs`.

### 4.21 Webhooks

Clients and Admins can register webhook endpoints to receive event notifications (e.g., task created, time logged). The `webhook-handler` edge function dispatches payloads and logs delivery attempts.

### 4.22 Calls (Audio and Video)

Peer-to-peer audio and video calls using WebRTC with signaling over Supabase Realtime (`call_signals`). Features include mute, video toggle, and screen sharing. Call sessions and participant metadata are persisted for history and analytics.

### 4.23 Gamification and Goals

VA achievements are tracked in the `achievements` table. Goal trackers allow VAs and Admins to set measurable targets with deadlines and progress tracking. Performance reviews provide periodic assessment records.

### 4.24 Enterprise Features

Multi-tenant support via `tenants`, `tenant_members`, and `tenant_branding`. Compliance certifications, SLA agreements, department management, and a report builder are available for enterprise deployments.

### 4.25 Settings

A unified settings page accessible to all roles. Includes profile management, language selection, chat translation preferences, GDPR compliance tools, onboarding restart, and developer settings (OAuth client management, connected apps).

### 4.26 Public Content Views

Documents, flowcharts, rich documents, spreadsheets, articles, folders, and SOPs can be shared via public token-based URLs. Optional password protection, expiry dates, and view limits are enforced at the edge function level.

---

*End of Project Documentation.*
