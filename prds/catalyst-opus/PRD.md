# CO Sales Hub (Catalyst Opus) -- Product Requirements Document

Version: 1.0
Date: 2026-02-07
Status: Draft for PM Review

---

## Table of Contents

1. [Product Goals](#1-product-goals)
2. [In-Scope vs Out-of-Scope](#2-in-scope-vs-out-of-scope)
3. [Functional Requirements](#3-functional-requirements)
4. [Non-Functional Requirements](#4-non-functional-requirements)
5. [Edge Cases and Constraints](#5-edge-cases-and-constraints)

---

## 1. Product Goals

### 1.1 Primary Goals

| ID | Goal | Success Metric |
|----|------|----------------|
| G-01 | Provide a single platform that replaces fragmented tooling for Client-VA collaboration. | Clients use fewer than 2 external tools for daily VA management. |
| G-02 | Ensure full accountability for VA work through time tracking, daily reports, and audit trails. | 100% of billable hours are logged with task associations. |
| G-03 | Reduce VA hiring and onboarding time through an integrated job pipeline. | Time from job request to VA assignment decreases by 50%. |
| G-04 | Enable secure credential sharing between Clients and VAs without exposing passwords in plaintext over chat. | Zero credential leaks via messaging channels. |
| G-05 | Support external application integration via standards-compliant OAuth 2.0 SSO. | External apps (e.g., CO Time Tracker) authenticate without separate credentials. |

### 1.2 Secondary Goals

| ID | Goal |
|----|------|
| G-06 | Improve VA performance visibility through analytics dashboards and gamification. |
| G-07 | Support enterprise deployments with multi-tenancy, compliance tracking, and SLA management. |
| G-08 | Reduce admin overhead through automated task assignment, recurring routines, and smart notifications. |

---

## 2. In-Scope vs Out-of-Scope

### 2.1 In-Scope

- Email/password authentication with role-based access control (Admin, Client, VA).
- OAuth 2.0 Authorization Code + PKCE for external application SSO.
- Real-time messaging with threads, reactions, file attachments, voice messages, polls, and scheduled messages.
- Peer-to-peer audio/video calls with WebRTC signaling.
- Kanban-based task management with subtasks, checklists, dependencies, and SOP linking.
- Project and space-based workspace organization.
- Document management (file uploads, rich documents, flowcharts, spreadsheets, screen recordings).
- Standard Operating Procedures with versioning and acknowledgment tracking.
- Wiki/knowledge base with AI-assisted Q&A.
- Time logging, daily reports, and analytics.
- Job pipeline with applicant tracking and interview scheduling.
- Hour-based billing with packages, custom rates, and invoicing.
- Password vault with access logging.
- Calendar with event management and recurrence.
- Notification system (in-app and email).
- Support ticket system.
- Audit logging for all significant actions.
- Webhook integrations.
- Public content sharing via token-based links.
- Settings management (profile, language, GDPR, developer tools).

### 2.2 Out-of-Scope

- Native mobile applications (iOS, Android). The platform is web-only.
- Third-party calendar sync (Google Calendar, Outlook). Calendar is internal only.
- Payment processing (Stripe, PayPal). Invoices are generated but payment collection is external.
- Video conferencing server infrastructure. Calls are peer-to-peer WebRTC only; no SFU/MCU.
- CRM functionality. The platform manages VA work, not sales pipelines or customer relationships.
- White-label reselling.
- Self-hosted deployments. The platform runs exclusively on Lovable Cloud.
- SMS or push notifications. Notifications are in-app and email only.
- Advanced BI or data warehouse integrations.

---

## 3. Functional Requirements

### 3.1 Authentication and Authorization

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| AUTH-01 | Users shall sign up with email and password. | A new user can register, receive a confirmation email, verify, and sign in. |
| AUTH-02 | Users shall sign in with email and password. | Valid credentials produce a session; invalid credentials produce an error message. |
| AUTH-03 | Users shall reset their password via email. | A reset link is sent; clicking it allows the user to set a new password. |
| AUTH-04 | The system shall enforce role-based routing: Clients to `/client/*`, VAs to `/va/*`, Admins to `/admin/*`. | A Client accessing `/admin/` is redirected to `/auth` or `/`. |
| AUTH-05 | The system shall persist the user's last role in localStorage to render a matching skeleton on page load. | Returning users see a role-appropriate loading state before auth completes. |
| AUTH-06 | OAuth 2.0 external apps shall authenticate via the `/oauth/consent` endpoint using PKCE. | An external app receives a valid access token after the consent flow. |
| AUTH-07 | Access tokens shall expire; refresh tokens shall issue new access tokens. | An expired access token returns 401; a refresh request returns a new access token. |
| AUTH-08 | Token revocation shall invalidate access and refresh tokens immediately. | A revoked token returns `active: false` on introspection. |
| AUTH-09 | Logout shall clear all local session data, revoke tokens, and redirect to `/logged-out`. | After logout, no session data remains in localStorage; re-accessing a protected route redirects to `/auth`. |
| AUTH-10 | The system shall support cross-tab logout. | Logging out in Tab A causes Tab B to clear its auth state within 5 seconds. |

### 3.2 Messaging

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| MSG-01 | Users shall send and receive text messages in real time. | A message sent by User A appears in User B's chat window within 2 seconds without page refresh. |
| MSG-02 | Users shall create group channels scoped to a space. | A channel created under Space X is visible only to members of Space X. |
| MSG-03 | Users shall reply to messages in threads. | A thread reply appears under the parent message; it does not appear in the main channel feed. |
| MSG-04 | Users shall react to messages with emoji. | A reaction badge appears on the message; clicking it shows who reacted. |
| MSG-05 | Users shall attach files to messages. | An attached file is uploadable, stored, and downloadable by the recipient. |
| MSG-06 | Users shall record and send voice messages. | A voice message is playable in the chat window with duration displayed. |
| MSG-07 | Users shall schedule messages for future delivery. | A scheduled message is not visible until the scheduled time; it appears automatically at that time. |
| MSG-08 | Users shall pin, star, flag, and label conversations. | Pinned conversations appear at the top of the sidebar; starred items are filterable. |
| MSG-09 | Users shall search messages globally. | A search query returns matching messages across all accessible conversations. |
| MSG-10 | Users shall create polls within channels. | A poll renders with options; users can vote; results update in real time. |
| MSG-11 | Messages shall display read receipts. | A sent message shows delivery and read status per recipient. |
| MSG-12 | Users shall see typing indicators. | When User A types, User B sees a typing indicator within 1 second. |
| MSG-13 | Messages shall render link previews. | A URL in a message generates a preview card with title, description, and image. |
| MSG-14 | Users shall summarize message history via AI. | The summarize action produces a text summary of the selected message range. |

### 3.3 Task Management

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| TASK-01 | Clients shall create tasks with title, description, assignee, priority, due date, and project. | A created task appears on the assignee's task board. |
| TASK-02 | Tasks shall be displayed in a Kanban board with drag-and-drop status changes. | Dragging a task from "To Do" to "In Progress" updates its status in the database. |
| TASK-03 | Tasks shall support checklists with completion tracking. | Checking a checklist item updates the completion percentage. |
| TASK-04 | Tasks shall support subtasks. | A subtask inherits the parent task's project; completing all subtasks is reflected on the parent. |
| TASK-05 | Tasks shall support file attachments. | An attachment is uploadable and downloadable from the task detail view. |
| TASK-06 | Tasks shall support comments with mentions. | A comment mentioning @user sends a notification to that user. |
| TASK-07 | Tasks shall support dependencies. | A task marked as blocked by another task displays the dependency visually. |
| TASK-08 | Tasks shall link to SOPs. | A task's linked SOPs are navigable from the task detail view. |
| TASK-09 | Clients shall perform bulk actions on tasks (assign, change status, delete). | Selecting multiple tasks and applying a bulk action updates all selected tasks. |
| TASK-10 | Recurring tasks shall generate new task instances on schedule. | A weekly recurring task creates a new instance every Monday. |
| TASK-11 | Users shall filter and search tasks by status, priority, assignee, and date range. | Applying filters narrows the displayed tasks; clearing filters restores the full view. |

### 3.4 Projects and Spaces

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| PROJ-01 | Clients shall create projects with a name, description, and members. | A created project is visible to its members. |
| PROJ-02 | Projects shall contain tasks and documents. | Tasks created under a project are filterable by project. |
| PROJ-03 | Clients shall create spaces to group projects. | A space contains one or more projects; switching spaces filters the visible data. |
| PROJ-04 | Spaces shall support custom branding (color, icon). | A space's branding is reflected in the sidebar and header. |
| PROJ-05 | Space membership shall control data visibility. | A user not in a space cannot see its projects, tasks, or documents. |

### 3.5 Document Management

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| DOC-01 | Users shall upload files (images, PDFs, office documents). | An uploaded file is stored and retrievable. |
| DOC-02 | Users shall create rich documents with the TipTap editor. | A rich document supports headings, lists, tables, images, links, and code blocks. |
| DOC-03 | Users shall create flowcharts with the visual editor. | A flowchart with nodes and edges is saveable and re-editable. |
| DOC-04 | Users shall create spreadsheets. | A spreadsheet with cell data is saveable and re-editable. |
| DOC-05 | Users shall organize documents in a folder tree with drag-and-drop. | Moving a document to a different folder updates its path. |
| DOC-06 | Users shall share documents with specific VAs (view or edit permission). | A shared document appears in the VA's document list with the correct permission. |
| DOC-07 | Users shall generate public share links with optional password, expiry, and view limit. | A public link is accessible without authentication; an expired link returns an error. |
| DOC-08 | Documents shall support a trash and restore workflow. | A deleted document moves to trash; restoring it returns it to its original location. |
| DOC-09 | Rich documents shall support real-time collaboration with cursor presence. | Two users editing the same document see each other's cursors. |
| DOC-10 | Users shall record and attach screen recordings to the document system. | A screen recording is captured, uploaded, and playable within the document manager. |

### 3.6 SOPs

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| SOP-01 | Clients shall create SOPs with ordered steps. | An SOP with steps is saveable and viewable. |
| SOP-02 | SOPs shall support versioning. | Editing an SOP creates a new version; previous versions are viewable. |
| SOP-03 | SOPs shall track VA acknowledgments. | After a VA acknowledges an SOP, their acknowledgment is recorded with a timestamp. |
| SOP-04 | SOPs shall be linkable to tasks. | A task references an SOP; navigating the link opens the SOP. |
| SOP-05 | SOPs shall be shareable via public links. | A public SOP link renders the SOP content without authentication. |

### 3.7 Wiki / Knowledge Base

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| WIKI-01 | Users shall create wiki pages with rich text content. | A wiki page is saveable and renderable with formatted content. |
| WIKI-02 | Wiki pages shall support hierarchical organization (parent-child). | A child page is nested under its parent in the page tree. |
| WIKI-03 | Wiki pages shall display backlinks. | If Page A links to Page B, Page B's backlinks section lists Page A. |
| WIKI-04 | Wiki pages shall support version history. | Previous versions of a wiki page are viewable and restorable. |
| WIKI-05 | Users shall search wiki content. | A search query returns matching pages with highlighted excerpts. |
| WIKI-06 | Users shall ask questions against wiki content via AI chat. | An AI response is grounded in wiki page content and cites sources. |
| WIKI-07 | Wiki pages shall support verification badges. | An admin or designated user can mark a page as verified; the badge is visible. |

### 3.8 Calendar

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| CAL-01 | Users shall create calendar events with title, start/end time, description, and location. | A created event appears on the calendar at the correct date and time. |
| CAL-02 | Events shall support attendees. | An attendee receives a notification when added to an event. |
| CAL-03 | Events shall support recurrence rules. | A weekly recurring event generates instances on the correct days. |
| CAL-04 | Events shall be scoped to projects or spaces. | Filtering by project shows only events associated with that project. |
| CAL-05 | Events shall support meeting links. | A meeting link is clickable from the event detail view. |

### 3.9 Job Pipeline

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| JOB-01 | Clients shall create job requests with role requirements. | A job request is visible to Admins in the pipeline. |
| JOB-02 | Admins shall configure pipeline stages per job. | Stages are ordered and renamable; applicants can be moved between stages. |
| JOB-03 | Applicants shall submit applications with cover letter and resume. | An application is recorded and visible in the pipeline. |
| JOB-04 | Admins shall schedule interviews for applicants. | An interview is associated with an applicant and has a scheduled date/time. |
| JOB-05 | Stage transitions shall be logged in history. | Moving an applicant from "Screening" to "Interview" creates a history record. |
| JOB-06 | Admins shall assign hired VAs to Clients. | A hired VA appears in the Client's VA list; the `va_assignments` table reflects the assignment. |

### 3.10 Time Tracking and Reporting

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| TIME-01 | VAs shall log time entries against tasks with start time, end time, and notes. | A time entry is recorded and visible to the assigned Client. |
| TIME-02 | Clients shall review and approve or reject time entries. | An approved entry changes status; a rejected entry returns to the VA for correction. |
| TIME-03 | VAs shall submit daily reports summarizing work completed. | A daily report is viewable by the assigned Client and Admin. |
| TIME-04 | The system shall compute analytics snapshots (hours worked, task completion rates). | Dashboard KPIs reflect accurate aggregations of time and task data. |
| TIME-05 | Users shall generate and export PDF reports. | A generated report downloads as a valid PDF file. |
| TIME-06 | Users shall schedule recurring reports. | A scheduled weekly report is generated and accessible on the specified day. |

### 3.11 Billing

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| BILL-01 | Clients shall purchase hour packages. | A purchased package credits hours to the Client's balance. |
| BILL-02 | Time logged by VAs shall debit hours from the Client's balance. | After a VA logs 2 hours, the Client's balance decreases by 2 (adjusted for custom rate if applicable). |
| BILL-03 | Admins shall set custom hourly rates per VA-Client pair. | A custom rate is applied when computing billing for that pair. |
| BILL-04 | Auto-purchase settings shall trigger package purchases when balance falls below a threshold. | When balance drops below the threshold, a new package is automatically created. |
| BILL-05 | The system shall generate invoices with line items. | An invoice lists time entries with hours, rates, and totals. |

### 3.12 Password Vault

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| VAULT-01 | Clients shall store credentials (service name, username, password, URL, notes). | A stored credential is retrievable by the Client. |
| VAULT-02 | Clients shall share specific credentials with specific VAs. | A shared credential is visible to the VA; an unshared credential is not. |
| VAULT-03 | The vault shall auto-lock after configurable inactivity. | After 5 minutes of inactivity, the vault requires re-authentication to access. |
| VAULT-04 | All vault access shall be logged. | Opening a credential creates an access log entry with user, timestamp, and IP. |

### 3.13 Notifications

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| NOTIF-01 | The system shall generate in-app notifications for relevant events (task assignment, message mention, etc.). | A notification appears in the notification center within 5 seconds of the triggering event. |
| NOTIF-02 | The system shall send email notifications based on user preferences. | A user with email notifications enabled receives an email for a new task assignment. |
| NOTIF-03 | Users shall configure notification preferences per event type. | Disabling "task assignment" notifications prevents both in-app and email notifications for that event. |
| NOTIF-04 | Users shall snooze notifications. | A snoozed notification reappears after the snooze period. |
| NOTIF-05 | The system shall batch notifications into digests. | A digest email aggregates multiple events into a single email. |

### 3.14 Support Tickets

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| SUP-01 | Users shall create support tickets with subject, description, and category. | A ticket is created and visible in the Admin support view. |
| SUP-02 | Admins shall respond to tickets with threaded comments. | A response comment is visible to the ticket creator. |
| SUP-03 | Tickets shall have status (open, in-progress, resolved, closed). | Changing status updates the ticket and is reflected in filters. |

### 3.15 Admin Management

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| ADM-01 | Admins shall view a dashboard with system-wide KPIs (total users, active VAs, open tasks). | Dashboard metrics are accurate relative to database state. |
| ADM-02 | Admins shall create and deactivate user accounts. | A created user can sign in; a deactivated user cannot. |
| ADM-03 | Admins shall assign and revoke roles. | Changing a user's role immediately affects their routing and data access. |
| ADM-04 | Admins shall view the full audit log. | All auditable events are present with correct metadata. |
| ADM-05 | Admins shall view VA capacity and workload. | VA workload charts display hours logged and tasks assigned per VA. |
| ADM-06 | Admins shall send notifications to specific users or broadcast to all. | A sent notification is received by the targeted user(s). |

### 3.16 OAuth SSO and API Gateway

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| SSO-01 | The OAuth server shall issue access tokens, refresh tokens, and ID tokens via the Authorization Code + PKCE flow. | A compliant client application receives all three tokens after consent. |
| SSO-02 | The API gateway shall validate access tokens and enforce scope-based authorization. | A request with scope `tasks:read` can access `/v1/tasks`; a request without that scope receives 403. |
| SSO-03 | API requests shall be logged in `api_request_logs`. | Each API call creates a log entry with endpoint, method, status code, and response time. |
| SSO-04 | The OAuth server shall support client registration with redirect URIs and allowed scopes. | A registered client can only redirect to its registered URIs. |
| SSO-05 | The consent page shall display requested scopes and allow the user to approve or deny. | Denying consent redirects to the client with an `access_denied` error. |

### 3.17 Webhooks

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| HOOK-01 | Users shall register webhook endpoints with event subscriptions. | A registered webhook receives a POST request when the subscribed event occurs. |
| HOOK-02 | Webhook deliveries shall be logged with status and response. | A failed delivery is logged with the HTTP status code and retry count. |

### 3.18 Calls

| ID | Requirement | Testable Criteria |
|----|-------------|-------------------|
| CALL-01 | Users shall initiate peer-to-peer audio calls. | An audio call connects both parties with bidirectional audio. |
| CALL-02 | Users shall initiate peer-to-peer video calls. | A video call connects both parties with bidirectional video and audio. |
| CALL-03 | Users shall share their screen during a call. | The remote participant sees the shared screen content. |
| CALL-04 | Call sessions shall be logged with duration and participants. | A completed call has a recorded start time, end time, and participant list. |

---

## 4. Non-Functional Requirements

### 4.1 Performance

| ID | Requirement |
|----|-------------|
| PERF-01 | Pages shall achieve First Contentful Paint (FCP) under 1.5 seconds on a broadband connection. |
| PERF-02 | Real-time messages shall be delivered to recipients within 2 seconds of sending. |
| PERF-03 | The task Kanban board shall render up to 500 tasks without perceptible lag (< 100ms interaction delay). |
| PERF-04 | Document uploads up to 50 MB shall complete within 30 seconds on a 10 Mbps connection. |
| PERF-05 | API gateway responses shall complete within 500ms at the 95th percentile. |
| PERF-06 | All pages shall be lazy-loaded with automatic retry on chunk loading failures. |

### 4.2 Security

| ID | Requirement |
|----|-------------|
| SEC-01 | All user-facing database tables shall have Row-Level Security (RLS) policies enabled. |
| SEC-02 | RLS policies shall use the `has_role()` helper function for consistent role verification. |
| SEC-03 | Password vault entries shall be encrypted at rest. |
| SEC-04 | OAuth tokens shall be hashed before storage; plaintext tokens shall never be persisted. |
| SEC-05 | PKCE `code_verifier` and `state` parameters shall be validated on every token exchange. |
| SEC-06 | Public document links shall enforce expiry, view limits, and optional password protection. |
| SEC-07 | All destructive admin actions shall be recorded in the audit log. |
| SEC-08 | AI rate limiting shall prevent abuse (configurable requests per time window per user). |
| SEC-09 | CORS headers on edge functions shall restrict origins to registered domains. |
| SEC-10 | Session tokens shall not be accessible via JavaScript in contexts where HttpOnly cookies are feasible. |

### 4.3 Permissions and Data Isolation

| ID | Requirement |
|----|-------------|
| PERM-01 | A Client shall never see another Client's data (tasks, documents, time logs, messages). |
| PERM-02 | A VA shall only access data for Clients they are actively assigned to. |
| PERM-03 | Deactivating a VA assignment shall immediately revoke the VA's access to that Client's data. |
| PERM-04 | Admin access shall not grant the ability to impersonate or act as another user. |
| PERM-05 | OAuth scopes shall be the sole determinant of API gateway data access for external apps. |
| PERM-06 | Public share links shall not expose data beyond the specific shared document or content. |

### 4.4 Data Integrity

| ID | Requirement |
|----|-------------|
| DATA-01 | All tables with user-modifiable data shall have `created_at` and `updated_at` timestamps. |
| DATA-02 | `updated_at` shall be automatically set via database triggers on UPDATE operations. |
| DATA-03 | Deleting a parent entity (e.g., project) shall cascade or restrict based on defined foreign key constraints; orphaned records shall not exist. |
| DATA-04 | Time log entries shall not overlap for the same VA (same time range). |
| DATA-05 | OAuth authorization codes shall be single-use; a second exchange attempt shall fail. |
| DATA-06 | SOP version history shall be immutable; previous versions shall not be editable. |

---

## 5. Edge Cases and Constraints

### 5.1 Role Conflicts

| Scenario | Expected Behavior |
|----------|-------------------|
| A user is assigned multiple roles in `user_roles`. | The system supports this at the data layer, but the UI routes to the first matching role in priority order: Admin > Client > VA. The `AuthContext` exposes `isAdmin`, `isClient`, `isVA` booleans; if multiple are true, routing logic selects the highest-priority role. |
| A VA is assigned to zero Clients. | The VA can sign in and access their dashboard, but all Client-scoped data (tasks, documents, messages) is empty. The `vaClientData` in `AuthContext` returns `null`. |
| An Admin also wants to manage tasks as a Client. | Not supported. Admins must have a separate Client account. Role separation is strictly enforced in routing and RLS. |
| A user's role is changed while they have an active session. | The change takes effect on the next `refreshAuth()` call or page reload. The stale session may briefly show incorrect routing until the cache TTL (5 minutes) expires or the user refreshes. |

### 5.2 Multi-Tenant Concerns

| Scenario | Expected Behavior |
|----------|-------------------|
| Two Clients belong to different tenants. | Tenant-scoped data (channels, branding) is isolated via `tenant_id` foreign keys. Cross-tenant data leakage is prevented by RLS policies on `tenants` and `tenant_members`. |
| A VA is assigned to Clients in different tenants. | The VA sees data from both Clients but scoped per Client. Messaging channels are tenant-scoped, so the VA may belong to channels in multiple tenants. |
| Tenant branding is not configured. | The platform falls back to default branding (colors, logo). No errors are thrown. |
| A tenant is deleted or deactivated. | Assumption: Tenant deactivation is not currently implemented. All tenant members would need to be individually deactivated. This is a known gap. |

### 5.3 Data Visibility Rules

| Scenario | Expected Behavior |
|----------|-------------------|
| A Client searches for messages. | Search results include only messages in conversations the Client is a participant of. Messages from other Clients' channels are excluded by RLS. |
| A VA accesses documents. | The VA sees: (a) documents explicitly shared with them via `document_shares`, (b) documents in projects they are a member of, and (c) documents accessible via public links. Documents owned by Clients they are not assigned to are invisible. |
| An Admin queries time logs. | Admins see all time logs across all Clients and VAs. No Client or VA filter is applied by default; the Admin UI provides filters for narrowing results. |
| A public link user accesses a document. | The user sees only the specific document or folder targeted by the link token. No navigation to other documents or platform features is possible. Password, expiry, and view limits are enforced at the edge function level. |
| A VA is unassigned from a Client. | The VA's `va_assignments` record is set to `status = 'inactive'`. All subsequent queries filtering on `status = 'active'` exclude this assignment. The VA loses access to the Client's tasks, documents, and messages immediately (on next query). Cached data in React Query may persist until stale time expires. |

### 5.4 Concurrency and Race Conditions

| Scenario | Expected Behavior |
|----------|-------------------|
| Two users edit the same rich document simultaneously. | Real-time collaboration via `document_collaborators` tracks cursor positions. Conflict resolution depends on the TipTap collaboration implementation. Assumption: last-write-wins at the block level; true CRDT is not implemented. |
| Two users move the same task on the Kanban board simultaneously. | The second update overwrites the first. No optimistic locking is implemented. The UI reflects the latest database state on the next query refresh. |
| A scheduled message fires while the user is editing it. | The scheduled message is dispatched based on the version stored in `scheduled_messages` at dispatch time. Edits after dispatch do not affect the already-sent message. |
| Multiple OAuth authorization codes are issued for the same user-client pair. | Each code is independent and single-use. Exchanging one does not invalidate the other unless it has already expired. |

### 5.5 Capacity and Limits

| Constraint | Detail |
|------------|--------|
| Supabase query limit | Default 1000 rows per query. Pagination must be implemented for lists exceeding this. |
| File upload size | Dependent on Supabase Storage configuration. Assumed maximum: 50 MB per file. |
| AI rate limiting | Configured per user via `ai_rate_limits`. Default assumed: 20 requests per 15-minute window. |
| OAuth token lifetime | Access tokens: 1 hour. Refresh tokens: 30 days. Authorization codes: 5 minutes. |
| WebRTC calls | Peer-to-peer only. Group calls with more than 2 participants require a mesh topology, which degrades beyond 4 participants. |
| Realtime subscriptions | Subject to Supabase concurrent connection limits. |

### 5.6 Known Assumptions

1. The "salesperson" and "candidate" roles referenced in historical code have been fully removed from the database and codebase. Only Admin, Client, and VA roles exist.
2. Payment collection (credit card processing) is handled externally. The platform generates invoices but does not process payments.
3. Email delivery depends on the SMTP configuration of the `send-email` and `send-notification-email` edge functions. Delivery failures are logged but not retried.
4. The CO Time Tracker desktop agent is the primary external OAuth client. The SSO system is designed to support additional external apps but none are currently registered beyond the time tracker.
5. Multi-tenant features (tenant branding, departments, SLAs) are implemented at the schema level but may not be fully exposed in the UI for all roles.

---

*End of Product Requirements Document.*
