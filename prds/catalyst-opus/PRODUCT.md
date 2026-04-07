# Catalyst Opus - Product Specification

> **What this app does**: Catalyst Opus is a virtual assistant management platform where **Clients** hire and manage Virtual Assistants (VAs), **VAs** complete tasks and collaborate with clients, and **Admins** oversee the entire platform.

---

## Table of Contents

1. [Roles & Access](#1-roles--access)
2. [Authentication & Onboarding](#2-authentication--onboarding)
3. [Messaging](#3-messaging)
4. [Tasks](#4-tasks)
5. [Projects](#5-projects)
6. [Routines](#6-routines)
7. [Documents & Files](#7-documents--files)
8. [Rich Text Editor](#8-rich-text-editor)
9. [Spreadsheets](#9-spreadsheets)
10. [Flowcharts](#10-flowcharts)
11. [SOPs](#11-sops-standard-operating-procedures)
12. [Wiki](#12-wiki)
13. [Knowledge Base](#13-knowledge-base)
14. [Calendar](#14-calendar)
15. [Voice & Video Calls](#15-voice--video-calls)
16. [Password Vault](#16-password-vault)
17. [Screen Recording](#17-screen-recording)
18. [AI Assistant](#18-ai-assistant)
19. [Support Tickets](#19-support-tickets)
20. [Job Pipeline & Recruitment](#20-job-pipeline--recruitment)
21. [Admin Dashboard & Analytics](#21-admin-dashboard--analytics)
22. [People Management (Admin)](#22-people-management-admin)
23. [Audit & Compliance (Admin)](#23-audit--compliance-admin)
24. [Settings](#24-settings)
25. [Themes & Appearance](#25-themes--appearance)
26. [Public Sharing](#26-public-sharing)
27. [Mobile Experience](#27-mobile-experience)
28. [Change Suggestions](#change-suggestions)

---

## 1. Roles & Access

| Role | Description | Route Prefix |
|------|-------------|--------------|
| **Client** | Hires VAs, creates tasks, manages projects | `/client/*` |
| **Virtual Assistant (VA)** | Completes tasks, collaborates with clients | `/va/*` |
| **Admin** | Manages platform, users, billing, compliance | `/admin/*` |

Each role has its own layout, sidebar navigation, and dashboard. Users can only access routes for their assigned role. Sidebar navigation items are stored in the database and customizable per user.

---

## 2. Authentication & Onboarding

### Authentication
- Email/password login and registration
- OAuth callback support (SSO)
- Password reset and update flows
- Session management via Supabase Auth

### Onboarding (Clients)
A 5-step wizard guiding new clients through:
1. Complete profile (name, organization, avatar)
2. Assign a Virtual Assistant
3. Create their first task
4. Upload documents
5. Watch a tutorial

Progress is tracked and resumable. Clients can restart onboarding from Settings.

---

## 3. Messaging

The messaging system supports three conversation types and a rich set of features.

### Conversation Types

| Type | Description |
|------|-------------|
| **Direct Messages (DMs)** | 1-on-1 chats between any two users |
| **Group Chats** | Multi-member private conversations |
| **Channels** | Workspace-wide or space-specific broadcast channels |

### Core Features
- **Rich text input** with TipTap editor (bold, italic, links, lists, code)
- **@ mentions** with autocomplete for users and channels
- **Threaded replies** - nested conversations under any message
- **Emoji reactions** on messages
- **Read receipts** - per-user tracking showing who read what and when
- **Typing indicators** - real-time "is typing..." display
- **Unread counts** - per-conversation badges with new message separators

### Message Actions
- **Edit** messages (shows "edited" indicator)
- **Delete** messages (soft delete)
- **Forward** messages or entire threads to other conversations
- **Pin** important messages to the top of a conversation
- **Clip** message excerpts for reference
- **Save/Bookmark** messages for later
- **Flag** messages for follow-up
- **Create task** from a message
- **Copy link** to a specific message

### Media & Attachments
- **File uploads** (images, documents, videos, etc.)
- **Voice messages** - record, send, and play audio clips with transcription
- **Link previews** - automatic rich cards for URLs, YouTube, and platform documents
- **Image previews** - inline thumbnails

### Organization
- **Labels** - custom color-coded tags for conversations
- **Starring** - favorite conversations for quick access
- **Muting** - suppress notifications per conversation
- **Pinned conversations** - stick conversations to top of sidebar
- **Search** - global and per-conversation search with highlighting
- **Drafts** - auto-saved with 2-second debounce, per conversation type

### Advanced Features
- **Scheduled messages** - compose now, send later
- **Polls** - single/multiple choice, anonymous, time-limited
- **Message translation** - translate messages to other languages
- **AI summarization** - summarize conversation threads
- **Channel canvas** - collaborative whiteboard within channels
- **Directory** - browse all contacts and start new conversations
- **Task Assistant** - AI-powered task management via chat

### Real-time
All messaging is real-time via Supabase Postgres change subscriptions. Messages, reactions, read receipts, and typing indicators update instantly.

---

## 4. Tasks

### Views
| View | Description |
|------|-------------|
| **Kanban** | Drag-and-drop columns: To Do, In Progress, Review, Completed. Group by status, VA, or priority. |
| **List** | Spreadsheet-style with customizable columns, sorting, grouping, and inline editing. |
| **Gantt** | Timeline bars showing start-to-deadline with drag-to-reschedule and dependency lines. |
| **Activity** | Historical timeline of all task changes. |

### Task Fields
- **Title** and **Description** (rich text)
- **Status**: To Do (assigned), In Progress, Review, Completed
- **Priority**: None, Low, Medium, High, Urgent
- **Assignee** (VA)
- **Deadline** and **Start Date**
- **Estimated Hours** and **Actual Hours**
- **Project** assignment (multiple projects supported)
- **Task Group** (custom groupings per client)
- **Parent Task** (for subtask relationships)
- **Compulsory** flag and **Milestone** flag

### Sub-features
- **Subtasks** - child tasks with completion progress bar
- **Checklists** - itemized to-do lists within a task, drag-to-reorder
- **Attachments** - file uploads, external links, platform document links
- **Comments** - threaded discussion with @mentions
- **Subscribers** - users notified of task changes
- **Dependencies** - "blocked by" relationships, visualized in Gantt
- **Linked SOPs** - attach Standard Operating Procedures with acknowledgment tracking
- **Time tracking** - clock in/out with break tracking and approval workflow
- **Sharing** - share tasks via chat with optional message
- **Templates** - reusable task templates
- **Reminders** - 1-day and 3-day deadline reminders

### Bulk Operations
- Select multiple tasks
- Bulk change: status, priority, assignee, archive/unarchive

### Filtering & Search
- Filter by: status, priority, assignee, project, compulsory flag
- Full-text search across title and description
- Persistent filter state per view
- Space-aware project filtering

---

## 5. Projects

- **Create projects** with name, description, color, status, start/end dates
- **Statuses**: Active, On Hold, Completed, Cancelled
- **Views**: Grid (cards), List (table), Kanban (by status)
- **Members** - assign users to projects with roles
- **Space grouping** - projects belong to optional "spaces" (workspace groupings)
- Tasks link to projects via `project_id`; a task can belong to multiple projects

---

## 6. Routines

Recurring tasks with a weekly grid view:

- **Frequency**: Daily, Weekly, Biweekly, Monthly
- **Weekly grid** showing day-of-week columns with completion status
- **Customizable columns**: Assignee, Priority, Status, Completion
- **Skill level tracking**: Confident, Getting There, Learning, No Idea
- **Inline editing** for quick updates
- **Drag-and-drop reordering**
- **Comments** on individual routines
- **Templates** - browse and apply routine templates
- **Sharing** - share routine lists with team members

---

## 7. Documents & Files

### File Management
- **Upload** files (drag-and-drop supported): PDFs, images, videos, Office docs, etc.
- **Folder system** - hierarchical with nesting, rename, move, delete
- **View modes**: Grid (cards) and List (table)
- **Search** by title/description
- **Filter** by document type, status, date range
- **Sort** by name, date, size, type

### Document Actions
- View, download, delete
- Share with VAs (permission levels: view, download, edit, full access)
- Set share expiry (1hr, 24hr, 7 days, 30 days, custom, never)
- Generate public shareable links
- Bulk operations: delete, download, move, share

### Content Types
| Type | Description |
|------|-------------|
| **Files** | Uploaded documents, images, videos |
| **Rich Documents** | TipTap-based collaborative documents |
| **Spreadsheets** | Univerjs-based workbooks |
| **Flowcharts** | React Flow-based diagrams |
| **SOPs** | Structured step-by-step procedures |
| **Articles** | Knowledge base entries |

---

## 8. Rich Text Editor

A full-featured TipTap-based editor used for documents, wiki pages, and articles.

### Formatting
- Headings (H1-H3), bold, italic, underline, strikethrough
- Text color, highlight, superscript, subscript
- Alignment (left, center, right, justify)
- Bullet lists, numbered lists, task lists (checkboxes)
- Code blocks, blockquotes, horizontal dividers

### Blocks & Embeds
- **Tables** with full row/column editing
- **Multi-column layouts** (2 or 3 columns)
- **Callouts** - info, warning, success, error styled blocks
- **Toggle/collapsible sections**
- **Mermaid diagrams** - flowcharts, sequence, state diagrams
- **YouTube embeds**
- **PDF embeds**
- **File attachments** with metadata
- **Link previews** - rich cards for URLs
- **Images** - drag-and-drop, resize

### Collaboration
- **Slash commands** (`/`) - 30+ commands organized by category
- **@ mentions** for users
- **[[ wiki links ]]** to other wiki pages
- **Inline comments** on text selections
- **Real-time cursors** showing other editors
- **Auto-save** with visual status indicator
- **Version history** with restore
- **Cover images** for documents

### Navigation
- **Document outline** - auto-generated table of contents from headings
- **Search bar** - find and replace within document
- **Focus/read mode**

---

## 9. Spreadsheets

Built on the Univerjs engine:
- Multiple sheets per workbook
- 26+ columns, 100+ rows default
- Full spreadsheet functionality (formulas, formatting, cell editing)
- Auto-save with debounced change tracking
- Shareable via public links

---

## 10. Flowcharts

Built on React Flow:
- **Node types**: Process, Decision (diamond), Start/End (rounded), Cylinder, Parallelogram, Hexagon, Document, Group, Sticky Notes
- **Drag-and-drop** interface with node palette
- **Custom edges** with styling
- **Auto-layout** with DAG support
- **Alignment toolbar**
- **History** (undo/redo)
- **Theme presets** for colors
- **Export** to image/PDF
- **Inline editing** of node content
- **Copy/paste** support
- **Public sharing** with tokens

---

## 11. SOPs (Standard Operating Procedures)

Structured step-by-step procedural documents:
- **Steps** with numbering, titles, and rich content
- **Critical step** marking
- **Estimated time** per step
- **Media attachments** per step (videos, documents, flowcharts, templates)
- **Categories**: General, Onboarding, Process, Policy, Training, Safety
- **Difficulty levels**: Beginner, Intermediate, Advanced
- **Version control** with full version history
- **Mandatory flag** for required SOPs
- **Acknowledgment tracking** with configurable frequency (once, monthly, quarterly, yearly, on update)
- **Quiz scoring** for step acknowledgments
- **Status**: Draft, Published, Archived
- **Folder organization**
- **Linkable to tasks** with acknowledgment tracking per VA

---

## 12. Wiki

A collaborative knowledge base with hierarchical page structure:
- **Page tree** - parent-child hierarchy with collapsible sidebar
- **Rich page editor** (TipTap-based, same as documents)
- **Templates** - browse built-in or create custom page templates
- **Full-text search** with Cmd+K shortcut
- **Bulk operations** - delete, move, export multiple pages
- **Import/export** - markdown format
- **Page rename** with inline editing
- **Version history** per page

### File Attachments

Each wiki page has a collapsible **Attachments** panel below the editor body (hidden in focus mode). Three ways to attach files:

| Button | Behaviour |
|--------|-----------|
| **Upload** | Picks any file(s) from disk; uploads to the `documents` storage bucket under `wiki-attachments/{userId}/{pageId}/`; records the row in `wiki_page_attachments` |
| **From library** | Opens a searchable dialog listing all documents in the Files library (RLS-filtered); selecting one or more inserts a reference row — no re-upload; `document_id` is set for provenance |
| **From wiki** | Opens a two-panel dialog: left panel shows other wiki spaces → pages (only pages that already have attachments); right panel shows that page's files with checkboxes; selected files are copied as new attachment rows on the current page with `source_page_id` set for provenance |

Each attachment row shows: file-type emoji icon, file name, size, relative timestamp, and a provenance badge ("From library" / "From wiki") where applicable. Hovering a row reveals **Download**, **Open in new tab**, and **Delete** (edit mode only). Download and Open use signed URLs (1-hour expiry via `getSignedDocumentUrl()`). Storage files are only deleted on the upload path — library and cross-wiki references just remove the DB row.

The panel is **read-only** when the editor is in Reading mode (no add or delete buttons shown).

#### Database

Table: `wiki_page_attachments`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `page_id` | UUID | FK → `wiki_pages(id)` ON DELETE CASCADE |
| `file_name` | TEXT | |
| `file_url` | TEXT | Storage path or public URL |
| `file_size` | BIGINT | Bytes; nullable |
| `mime_type` | TEXT | |
| `document_id` | UUID | FK → `documents(id)` ON DELETE SET NULL — set when sourced from library |
| `source_page_id` | UUID | FK → `wiki_pages(id)` ON DELETE SET NULL — set when sourced from another wiki |
| `uploaded_by` | UUID | FK → `auth.users(id)` |
| `created_at` | TIMESTAMPTZ | |

RLS policies: space members (via `space_members` join) can SELECT and INSERT; uploader can DELETE.

#### Pending migration (apply manually)

> **IMPORTANT:** Lovable does not auto-apply migrations from GitHub pushes. Run the SQL below in the [Supabase SQL Editor](https://supabase.com/dashboard/project/qouycamixsggwkwdotku/sql/new) to activate this feature.

Migration file: `supabase/migrations/20260224000005_wiki_page_attachments.sql`

```sql
CREATE TABLE IF NOT EXISTS wiki_page_attachments (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  page_id        UUID REFERENCES wiki_pages(id) ON DELETE CASCADE NOT NULL,
  file_name      TEXT NOT NULL,
  file_url       TEXT NOT NULL,
  file_size      BIGINT,
  mime_type      TEXT,
  document_id    UUID REFERENCES documents(id) ON DELETE SET NULL,
  source_page_id UUID REFERENCES wiki_pages(id) ON DELETE SET NULL,
  uploaded_by    UUID REFERENCES auth.users(id),
  created_at     TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE wiki_page_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Space members can read wiki attachments"
  ON wiki_page_attachments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM wiki_pages wp
      JOIN wiki_spaces ws ON ws.id = wp.wiki_id
      JOIN space_members sm ON sm.space_id = ws.space_id
      WHERE wp.id = wiki_page_attachments.page_id
        AND sm.user_id = auth.uid()
    )
  );

CREATE POLICY "Space members can insert wiki attachments"
  ON wiki_page_attachments FOR INSERT
  WITH CHECK (
    auth.uid() = uploaded_by AND
    EXISTS (
      SELECT 1 FROM wiki_pages wp
      JOIN wiki_spaces ws ON ws.id = wp.wiki_id
      JOIN space_members sm ON sm.space_id = ws.space_id
      WHERE wp.id = page_id AND sm.user_id = auth.uid()
    )
  );

CREATE POLICY "Uploader can delete wiki attachments"
  ON wiki_page_attachments FOR DELETE
  USING (uploaded_by = auth.uid());
```

---

## 13. Knowledge Base

A separate article-based system (distinct from Wiki):
- **Articles** with markdown content
- **Categories**: General, Processes, Guidelines, Templates, FAQ, Reference
- **Status**: Draft, Published
- **Folder-based organization** with breadcrumb navigation
- **Pinning and bookmarking** articles
- **Version history** tracking
- **Tags** for cross-cutting organization
- **View count** tracking
- **Related articles** linking and backlinks
- **Article sharing**
- **Search** across articles, tags, and folders

---

## 14. Calendar

### Calendar View
- **Month, week, day** views with navigation
- **Events** with color coding
- **Create/edit events** via dialog
- **Event selection** and detail view

### Deadline Calendar
- **Task deadline visualization** on calendar
- **Stats**: total deadlines, upcoming, overdue
- **Priority-based color coding**
- **Filters** by space and project
- **Upcoming deadlines list** with alerts

---

## 15. Voice & Video Calls

### Call Types
- **Voice calls** - audio-only between users
- **Video calls** - with camera feeds

### During a Call
- **Multiple participants** with video grid layout
- **Mute/unmute** microphone
- **Camera on/off**
- **Screen sharing**
- **Call duration timer**
- **Minimize/maximize** call window

### Call Flow
- **Initiate** from any DM or group chat
- **Incoming call modal** with accept/decline
- **WebRTC peer-to-peer** connections with ICE candidate exchange
- **Call activity markers** in chat history showing call events
- **Hidden audio element** for voice-only remote stream playback

---

## 16. Password Vault

### Client Vault
- **AES-256 encryption** with per-entry salts and IVs
- **Master password** protection
- **Add/edit/delete** credential entries
- **Categories** for organization
- **Favorites** marking
- **Password strength indicator**
- **Breach checking** (HaveIBeenPwned integration)
- **Password generator** for secure random passwords
- **Copy to clipboard** with notifications
- **Show/hide** password toggles
- **Search and filter**
- **Access history** tracking

### VA Shared Vault
- View credentials shared by clients
- **Unlock with master password** (one-time per session)
- **Auto-lock** after 5 minutes of inactivity (configurable)
- **Permission levels**: view, download, edit
- **Expiry dates** on shares
- **Organized by client** (accordion layout)

### Sharing
- Share vault entries with specific VAs
- End-to-end encryption with share keys
- Permission controls and revocation

---

## 17. Screen Recording

### Capture Modes
- Full screen, window/tab selection, or custom area
- Picture-in-Picture fallback

### Audio Options
- System audio only, microphone only, or both
- Audio source selector

### Recording Features
- 3-second countdown before recording
- Floating controls (pause/resume/stop)
- Duration timer and real-time preview
- Save to documents folder with title/description
- Auto-thumbnail generation
- Video format: MP4, WebM
- Background recording persistence
- Wake lock to prevent sleep

---

## 18. AI Assistant

- **Floating orb button** for quick access (Cmd/Ctrl + /)
- **Chat interface** with conversation history
- **Context awareness** - knows current page, task counts, pending approvals
- **Quick actions** - pre-made prompts for common queries
- **Streaming responses** with stop generation
- **Save/load conversations**
- Available to all roles (Admin has additional admin-specific queries)

---

## 19. Support Tickets

### Client/VA Side
- **Create tickets** with: title, description, category, priority
- **Categories**: Technical, Billing, General, Feature Request
- **Priority**: Low, Medium, High, Urgent
- **Status tracking**: Open, In Progress, Resolved, Closed
- **Comment thread** for ongoing conversation

### Admin Side
- **View all tickets** from all users
- **Filter** by status, priority, search
- **Respond** to tickets with messages
- **Internal notes** (not visible to the user)
- **Change ticket status** via dropdown
- **Real-time updates**

---

## 20. Job Pipeline & Recruitment

- **Create job listings** with descriptions and requirements
- **Kanban pipeline** with customizable stages
- **Candidate cards** with profiles and status
- **Interview scheduling**
- **Offer management**
- **Internal VA pool** - match existing VAs to openings
- **Pipeline analytics** - conversion rates, time-to-hire
- **Assign VA to job** with skill-based matching

---

## 21. Admin Dashboard & Analytics

### Dashboard
- **Real-time stat cards**: Total Clients, Total VAs, Pending Approvals, Revenue
- **Trend indicators** (up/down arrows with percentages)
- **Quick action cards**: Manage Clients, Manage VAs, Review Tasks, View Billing
- **Live activity feed**

### Analytics Tabs
| Tab | Content |
|-----|---------|
| **Activity** | User engagement, task completion rates, system metrics |
| **Payroll** | VA hourly breakdowns, month/week summaries |
| **Reports** | Custom report builder with scheduling and export |
| **Performance** | VA performance reviews, quality metrics, client satisfaction |

### Alerts
- System health warnings
- VA capacity alerts (overloaded, at capacity)
- Historical capacity trends

---

## 22. People Management (Admin)

### Client Management
- Search and filter clients
- **Health status**: Green (healthy), Yellow (at risk), Red (inactive)
- Health metrics: active/overdue tasks, last activity, unpaid invoices
- Assign/manage VAs per client

### VA Management
- **Capacity monitoring**: weekly hours (40hr limit), monthly hours (160hr limit)
- **Capacity status**: Available (<80%), Moderate (80-90%), At Capacity (90%+), Overloaded (100%+)
- Table and chart views
- Workload distribution visualization

### Admin Management
- Promote users to admin role
- Revoke admin privileges (with safety checks)
- Invite new admins

### Organization
- **Org chart** - visual hierarchy with departments
- **Department management** - create/edit departments, assign managers
- **Client profiling** and **VA profiling** tabs
- **Bulk import** from Lark platform

---

## 23. Audit & Compliance (Admin)

### Audit Logs
- Complete activity log with search and filters
- Filter by: action (create/update/delete/login/logout), entity type, user
- Columns: timestamp, action, entity, user, IP address, metadata

### Compliance Dashboard
- Regulatory requirements tracking
- Data protection certifications
- Policy adherence metrics

### SLA Management
- Create/edit Service Level Agreements
- Track performance against SLA targets
- Breach alerts and notifications

---

## 24. Settings

### Profile
- Avatar upload (2MB max, images only)
- Full name, phone, bio
- Organization name (clients only)

### Notifications
- Toggle: email, in-app, sound notifications
- Per-type toggles: tasks, time logs, reports, messages
- Test notification button

### Language
- Interface language selector (i18next)
- Separate chat translation language

### Privacy & GDPR
- **Export all data** as JSON download
- **Delete account** permanently (with confirmation and data warnings)
- GDPR/CCPA compliance info

### Role Management (Admin only)
- View all users and roles
- Change user roles (admin, client, VA)

### Developers (Admin only)
- API key management
- Webhook configuration

### Connected Apps
- Third-party integrations and OAuth connections

---

## 25. Themes & Appearance

Seven built-in color themes, applied globally:

| Theme | Primary Color |
|-------|--------------|
| **Catalyst Teal** (default) | Teal/green |
| **Ocean Blue** | Professional blue |
| **Violet Dream** | Purple |
| **Sunset Orange** | Warm orange |
| **Forest Green** | Earthy green |
| **Rose Pink** | Soft pink |
| **Slate Gray** | Neutral gray |

Each theme sets 25+ CSS custom properties (primary, accent, borders, gradients, charts, status colors). Themes persist per user in the database and apply instantly via localStorage.

Dark mode is also supported via the system's light/dark toggle.

Sidebar customization: configurable number of recent items (3-15).

---

## 26. Public Sharing

Content can be shared via public token-based URLs (no login required):

| Content Type | URL Pattern |
|-------------|-------------|
| Document | `/doc/:token` |
| Flowchart | `/flowchart/:token` |
| Rich Document | `/rich-doc/:token` |
| Spreadsheet | `/sheet/:token` |
| Article | `/article/:token` |
| Folder | `/folder/:token` |
| SOP | `/sop/:token` |

Shares can have: expiry dates, password protection, and permission levels.

### First-View Notifications

When a shared link is opened for the **first time** (view count 0→1), the link creator receives an in-app notification: _"[Document title] was accessed via your shared link for the first time."_

Implemented via DB triggers (`trigger_notify_first_document_link_view` on `document_links`, `trigger_notify_first_rich_document_link_view` on `rich_document_links`). Includes dedup logic — no duplicate notification if the link is opened again or if the edge function also fires.

---

## 27. Mobile Experience

- Fully responsive design across all features
- **Bottom navigation bar** with role-specific primary items (3-4 items)
- **"More" drawer** for additional navigation items
- **Mobile-optimized components**: action sheets instead of context menus, drawer-based panels, touch-friendly buttons
- **Mobile keyboard toolbar** for rich text editing
- **Mobile filter drawers** for task filtering

---

## Change Suggestions

To propose a change to Catalyst Opus, add an entry below using this format. Mark its status as you progress.

### Template

```
### [SHORT TITLE]
- **Status**: Proposed | Approved | In Progress | Done | Rejected
- **Priority**: Low | Medium | High | Urgent
- **Affects**: Client | VA | Admin | All
- **Category**: New Feature | Enhancement | Bug Fix | UI/UX | Performance | Removal
- **Description**: What should change and why.
- **Current behavior** (if applicable): How it works now.
- **Desired behavior**: How it should work after the change.
- **Notes**: Any additional context, trade-offs, or dependencies.
```

### Suggestions

<!-- Add your change suggestions below this line -->

<!--
Example:

### Add dark mode toggle to sidebar
- **Status**: Proposed
- **Priority**: Medium
- **Affects**: All
- **Category**: UI/UX
- **Description**: Users should be able to toggle dark mode from the sidebar instead of only from Settings > Appearance.
- **Current behavior**: Dark mode toggle is only in Settings.
- **Desired behavior**: A moon/sun icon in the sidebar footer toggles dark mode instantly.
- **Notes**: Should respect system preference on first visit.
-->
