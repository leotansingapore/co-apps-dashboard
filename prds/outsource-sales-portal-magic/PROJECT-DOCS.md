# Catalyst Outsourcing — Sales Portal Platform Documentation

> **Last Updated:** March 2026  
> **Tech Stack:** React 18 + Vite + TypeScript + Tailwind CSS + shadcn/ui + Supabase  
> **Live URL:** https://outsource-sales-portal-magic.lovable.app

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture & Tech Stack](#2-architecture--tech-stack)
3. [User Roles & Access Control](#3-user-roles--access-control)
4. [Authentication & Authorization](#4-authentication--authorization)
5. [Routing & Navigation](#5-routing--navigation)
6. [Admin Dashboard](#6-admin-dashboard)
7. [Salesperson / Partner Dashboard](#7-salesperson--partner-dashboard)
8. [Client (Customer) Dashboard](#8-client-customer-dashboard)
9. [Proposal System](#9-proposal-system)
10. [Contract Management](#10-contract-management)
11. [Quote Request Pipeline](#11-quote-request-pipeline)
12. [Affiliate & Referral System](#12-affiliate--referral-system)
13. [Sales Tools & Resources](#13-sales-tools--resources)
14. [VA (Virtual Assistant) Management](#14-va-virtual-assistant-management)
15. [Messaging & Communication](#15-messaging--communication)
16. [Payment & Billing (Stripe)](#16-payment--billing-stripe)
17. [Email & Notification System](#17-email--notification-system)
18. [Operations Dashboard](#18-operations-dashboard)
19. [Edge Functions](#19-edge-functions)
20. [Database Schema Overview](#20-database-schema-overview)
21. [Service Rates & Pricing](#21-service-rates--pricing)
22. [PDF Generation](#22-pdf-generation)
23. [Performance & Optimization](#23-performance--optimization)
24. [Currency Support](#24-currency-support)
25. [Design System](#25-design-system)
26. [Security Considerations](#26-security-considerations)

---

## 1. Project Overview

**Catalyst Outsourcing Sales Portal** is a comprehensive B2B sales enablement and CRM platform for a Virtual Assistant (VA) outsourcing company based in Singapore. The platform connects businesses with skilled Filipino Virtual Assistants across multiple specializations.

### Core Purpose
- Enable salespeople and referral partners to generate proposals, manage leads, and close deals
- Provide an admin dashboard for full platform governance
- Offer self-service contract signing and billing management for clients
- Track the full sales pipeline from quote request → proposal → payment → contract → onboarding

### Key Business Flows
1. **Lead Acquisition:** Quote requests arrive from the main website via edge functions (`receive-quote`) or are manually created
2. **Lead Assignment:** Quotes are assigned to salespeople (auto or manual)
3. **Proposal Generation:** Salespeople create customized proposals with service configurations
4. **Client Review:** Clients view public proposals, select packages, and pay via Stripe
5. **Contract Signing:** Digital contracts are generated and signed electronically
6. **Onboarding:** Automated email sequences guide new clients through onboarding

---

## 2. Architecture & Tech Stack

### Frontend
| Technology | Purpose |
|---|---|
| **React 18** | UI framework with Suspense & lazy loading |
| **Vite** | Build tool & dev server |
| **TypeScript** | Type safety |
| **Tailwind CSS** | Utility-first styling with custom design tokens |
| **shadcn/ui** | Component library (Radix UI primitives) |
| **React Router v6** | Client-side routing |
| **TanStack React Query** | Server state management with 5-min stale time |
| **Recharts** | Data visualization / charts |
| **Framer Motion** | Animations (used in select components) |

### Backend (Supabase)
| Feature | Purpose |
|---|---|
| **Supabase Auth** | User authentication (email/password) |
| **PostgreSQL** | Primary database with RLS policies |
| **Edge Functions (Deno)** | Serverless backend logic (36 functions) |
| **Realtime** | Live subscriptions for dashboards |
| **Storage** | File storage for attachments |

### External Integrations
| Service | Purpose |
|---|---|
| **Stripe** | Payment processing & subscription management |
| **Resend** | Transactional email delivery |
| **Tavus** | AI video conversations (recruitment) |

### Context Providers (Wrapper Hierarchy)
```
QueryClientProvider
  └── BrowserRouter
        └── AuthProvider
              └── CurrencyProvider
                    └── AdminModeProvider
                          └── ViewModeProvider
                                └── TooltipProvider
                                      └── AffiliateHandoffProvider
                                            └── Routes
```

---

## 3. User Roles & Access Control

The platform uses **5 primary roles** stored in the `profiles.role` column:

| Role | Description | Default Landing Page |
|---|---|---|
| **Admin** | Full platform governance, user management, impersonation | `/sales-resources` |
| **Manager** | Operational visibility into users and sales pipeline; restricted from financial/system settings | `/sales-resources` |
| **Sales** | CRM tools, proposals, customers — scoped to personal records | `/sales-resources` |
| **Partner** | Same as Sales plus white-label proposal generation and referral tools | `/sales-resources` |
| **Client** | Self-service contract signing, billing management via Stripe | `/customer-dashboard` |

### Role-Based Access Matrix

| Feature | Admin | Manager | Sales | Partner | Client |
|---|---|---|---|---|---|
| Admin Dashboard | ✅ | ✅ | ❌ | ❌ | ❌ |
| Proposal Generator | ✅ | ✅ | ✅ | ✅ | ❌ |
| Sales Resources Hub | ✅ | ✅ | ✅ | ✅ | ❌ |
| My Dashboard (CRM) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Assigned Quotes/Leads | ✅ | ✅ | ✅ | ✅ | ❌ |
| Customer Management | ✅ | ✅ | ✅ | ✅ | ❌ |
| VA Catalogue | ✅ | ✅ | ✅ | ✅ | ❌ |
| White-Label Proposals | ✅ | ✅ | ✅ | ✅ | ❌ |
| Contract Review & Sign | ❌ | ❌ | ❌ | ❌ | ✅ |
| Customer Dashboard | ❌ | ❌ | ❌ | ❌ | ✅ |
| User Management | ✅ | ✅ (view) | ❌ | ❌ | ❌ |
| Activity Log | ✅ | ❌ | ❌ | ❌ | ❌ |
| Roles & Permissions | ✅ | ❌ | ❌ | ❌ | ❌ |
| Service Rates Config | ✅ | ❌ | ❌ | ❌ | ❌ |

### Role Guards
- **`AuthGuard`** (`src/components/AuthGuard.tsx`): Ensures user is authenticated; redirects to `/auth` if not
- **`RoleGuard`** (`src/components/RoleGuard.tsx`): Accepts `allowedRoles` prop; redirects users to their role-appropriate dashboard if unauthorized
- **`RoleBasedRedirect`** (`src/components/RoleBasedRedirect.tsx`): Root `/` route handler; redirects users based on their role

---

## 4. Authentication & Authorization

### Authentication Flow
- **Provider:** Supabase Auth (email/password)
- **Context:** `AuthContext` (`src/contexts/AuthContext.tsx`)
- **State:** `user`, `session`, `profile`, `isAdmin`, `subscribed`, `subscriptionTier`

### Key Behaviors
1. On `SIGNED_IN` event: fetches user profile from `profiles` table, checks subscription status
2. On `SIGNED_OUT`: clears all auth state, removes Supabase localStorage keys, redirects to `/auth`
3. Profile is fetched via `profiles.user_id` match to `auth.uid()`
4. Admin status: `profile.role === 'admin' || profile.role === 'manager'`

### Account Status
Profiles have an `account_status` enum: `pending`, `approved`, `suspended`. Pending users require admin approval before gaining full access.

### View Mode & Impersonation (Admin Only)
- **ViewModeContext** (`src/contexts/ViewModeContext.tsx`): Allows admins to toggle between admin view and salesperson view
- **Impersonation:** Admins can impersonate specific salespeople to see the platform from their perspective
- State persisted in `sessionStorage` (`admin_view_mode`, `admin_impersonated_user`)
- `effectiveUserId`: Returns impersonated user's ID when impersonating, otherwise the actual user's ID

---

## 5. Routing & Navigation

### Public Routes (No Auth Required)
| Route | Page | Description |
|---|---|---|
| `/public-proposal/:id` | PublicProposal | Client-facing proposal view (completely outside AuthProvider) |
| `/unsubscribe/contract/:token` | ContractUnsubscribe | Email unsubscribe for contract reminders |
| `/auth` | AuthPage | Login/signup |
| `/landing` | Landing | Public landing page |
| `/calculator` | Calculator | Public cost calculator |
| `/roi` | ROI | Public ROI calculator |
| `/virtual-assistants` | VirtualAssistants | VA showcase page |
| `/contact` | Contact | Contact form |
| `/referral-partners` | ReferralPartnerProgram | Referral program info page |
| `/va-skills-matcher` | VASkillsMatcher | Public VA matching tool |
| `/industry-roi-templates` | IndustryROITemplates | Industry-specific ROI templates |
| `/client-needs-assessment` | ClientNeedsAssessment | Assessment questionnaire |
| `/savings-timeline` | SavingsTimeline | Savings projection tool |

### Authenticated Routes
| Route | Allowed Roles | Description |
|---|---|---|
| `/sales-resources` | sales, partner, admin, manager | Sales resources hub / main dashboard |
| `/salesperson-dashboard` | sales, partner, admin, manager | Personal CRM dashboard |
| `/assigned-quotes` | sales, partner, admin, manager | Assigned lead management |
| `/salesperson-proposals` | sales, partner, admin, manager | Personal proposals list |
| `/salesperson-customers` | sales, partner, admin, manager | Customer management |
| `/salesperson-messages` | sales, partner, admin, manager | Cross-portal messaging |
| `/salesperson-profile` | sales, partner, admin, manager | Profile settings |
| `/customer/:id` | sales, partner, admin, manager | Customer detail view |
| `/proposal` | sales, partner, admin, manager | Proposal generator |
| `/va-catalogue` | sales, partner, admin, manager | VA catalogue browser |
| `/va-profile/:slug` | sales, partner, admin, manager | Individual VA profile |
| `/sales-presentation-decks` | sales, partner, admin, manager | Presentation deck library |
| `/competitive-analysis` | authenticated | Competitive analysis tool |
| `/white-label-proposal` | authenticated | White-label proposal generator |
| `/customer-dashboard` | client | Client self-service dashboard |
| `/contract/review/:contractId` | client | Contract review & signature |
| `/admin` | admin, manager | Admin dashboard |
| `/admin/:tab` | admin, manager | Admin sub-tabs |
| `/admin/:tab/:subTab` | admin, manager | Admin nested sub-tabs |
| `/admin/proposal/edit/:id` | admin, manager | Admin proposal editing |

### Navigation Components
- **`AppSidebar`** (`src/components/AppSidebar.tsx`): Sales/Partner sidebar with collapsible CRM group
- **`AdminSidebar`** (`src/components/admin/AdminSidebar.tsx`): Admin panel sidebar with 5 sections
- **`Layout`** (`src/components/Layout.tsx`): Conditional rendering — shows `AdminSidebar` when in admin mode (not impersonating), otherwise `AppSidebar`
- **`MobileBottomNav`** (`src/components/MobileBottomNav.tsx`): Mobile navigation bar
- **`ScrollToTop`**: Scrolls to top on route change

### Layout Logic
The `Layout` component determines what to render based on:
1. `isAdminMode` (from `AdminContext`) — persisted in `sessionStorage`
2. `isViewingAsSalesperson` (from `ViewModeContext`) — overrides admin sidebar
3. Route path — certain pages (admin, dashboards) manage their own sidebar

---

## 6. Admin Dashboard

**Route:** `/admin`, `/admin/:tab`, `/admin/:tab/:subTab`  
**Component:** `src/pages/Admin.tsx` → `AdminDashboardWithSidebar.tsx`

### Admin Tab Registry
Defined in `src/config/adminTabRegistry.ts`, tabs are lazy-loaded components organized into sections:

#### Platform Management
| Tab ID | Label | Description |
|---|---|---|
| `overview` | Platform Overview | High-level metrics, charts, recent activity |
| `operations` | Operations | Pipeline health, SLA tracking, attention-required items |
| `activity-log` | Activity Log | Audit trail of all platform actions |

#### All Sales Data (Sales Pipeline)
| Tab ID | Label | Description |
|---|---|---|
| `sales-pipeline/proposals` | All Proposals | View/edit all proposals across salespeople |
| `sales-pipeline/quote-requests` | Quote Requests | Incoming leads from main website |
| `sales-pipeline/contracts` | Contracts | All contracts with status tracking |
| `sales-pipeline/va-alignments` | VA Alignments | VA-client matching submissions |

#### Catalog & Partners
| Tab ID | Label | Description |
|---|---|---|
| `site-content/va-profiles` | VA Profiles | Manage VA catalogue profiles |
| `site-content/service-rates` | Service Rates | Configure hourly rates per service |
| `affiliates` | Affiliates | Affiliate partner management |

#### Team & Settings
| Tab ID | Label | Description |
|---|---|---|
| `users/all` | All Users | User list with role badges, status management |
| `users/invitations` | Invitations | Pending user invitations |
| `users/approvals` | Approvals | Pending account approvals |
| `users/roles` | Roles & Permissions | Custom roles and page-level permissions |
| `sales-resources-management` | Manage Resources | Sales resource content management |

### Admin Features
- **User Creation:** Direct user creation via `CreateUserDialog` with role assignment
- **User Deletion:** Idempotent deletion via `delete-user` edge function (auth + profile cleanup)
- **Password Reset:** Admin-triggered password resets via `reset-user-password` edge function
- **Impersonation:** View platform as any salesperson via `ImpersonationSelector`
- **Notification Bell:** Real-time admin notifications with tab-specific badge counts
- **Bulk Actions:** Multi-select operations on user lists
- **Affiliate Sync:** Bulk sync utility for external Affiliate Portal
- **Legacy Route Mapping:** Old routes (e.g., `/admin/proposals`) redirect to new nested structure

### Admin Proposal Editing
- **Route:** `/admin/proposal/edit/:id`
- Preserves original `user_id` and `salesperson_id` for commission attribution
- Uses `isAdminEdit` flag in `save-proposal` edge function

---

## 7. Salesperson / Partner Dashboard

### My Dashboard (`/salesperson-dashboard`)
- **Component:** `SalespersonDashboardWithSidebar.tsx`
- Personal performance metrics (proposals, revenue, conversion rate)
- Quick actions panel
- Recent activity feed
- Leaderboard position

### My Leads (`/assigned-quotes`)
- View and manage assigned quote requests
- Convert quotes to proposals
- Status tracking: new → assigned → proposal_created
- Badge count shows unacted leads

### My Proposals (`/salesperson-proposals`)
- List of all proposals created by the salesperson
- Status filtering: pending, paid, signed
- Quick actions: view, edit, copy link

### My Customers (`/salesperson-customers`)
- Customer CRM with contact details
- Industry, business size tracking
- Notes and activity history
- **Customer Detail** (`/customer/:id`): Full customer profile with proposal/contract history

### Messages (`/salesperson-messages`)
- Cross-portal messaging with affiliate partners
- Real-time message delivery via Supabase Realtime
- File attachments support
- Message reactions (emoji)
- Pin important messages
- Archive conversations
- Read receipts

### Profile (`/salesperson-profile`)
- Personal profile management
- Avatar, display name, timezone settings

### Sales CRM Sidebar Items
```
├── Sales Resources Hub
├── Sales CRM (collapsible)
│   ├── My Dashboard
│   ├── My Leads (badge: count)
│   ├── My Proposals
│   ├── My Customers
│   └── Messages
├── Proposal Generator (admin only when in admin mode)
├── Virtual Assistants (admin only when in admin mode)
├── Referral Program
├── Profile
└── Contact
```

---

## 8. Client (Customer) Dashboard

**Route:** `/customer-dashboard`  
**Component:** `src/pages/CustomerDashboard.tsx`

### Features
- View active contracts and their status
- Sign pending contracts digitally
- Manage subscription via Stripe Customer Portal
- View proposal details
- Contact support

### Contract Review & Signing (`/contract/review/:contractId`)
- Digital signature capture via `SignatureCanvas` component
- IP address and user agent recording for audit trail
- Client signer name and email capture
- Signature image storage
- Status transitions: `sent` → `signed`

---

## 9. Proposal System

### Proposal Generator (`/proposal`)
- **Component:** `src/pages/Proposal.tsx`
- Multi-step wizard for creating client proposals

#### Steps:
1. **Client Information:** Name, company, email, phone, industry, business size
2. **Service Selection:** Choose VA types and configure hours (20hr or 40hr packages)
3. **Salesperson Controls:** Contract length, currency, customer-facing options toggles
4. **AI Content Generation:** Generate persuasive proposal content via `generate-proposal-content` edge function
5. **Preview & Save:** Review and save to database via `save-proposal` edge function

### Service Configuration
- **Single Role:** One VA type with fixed hours package
- **Multi-Role:** Multiple VAs with split-hour configurations
- Flexible monthly hours option
- Customer-selectable contract lengths and hours

### Proposal Viewing
- **ProposalPreview** (`/proposal/preview`): Internal preview for salespeople
- **PublicProposal** (`/public-proposal/:id`): Client-facing view (no auth required)
  - Package selector with pricing breakdown
  - Stripe checkout integration
  - Signature capture
  - Currency switching

### White-Label Proposals (`/white-label-proposal`)
- Partners can generate proposals with custom branding
- Company logo and color customization
- Custom terms and conditions

### Referral Proposal Generator (`/referral-proposal-generator`)
- Specialized generator for referral partners
- Automatic affiliate code tracking

---

## 10. Contract Management

### Contract Generation
- **Edge Function:** `generate-contract`
- Auto-generates contract from paid proposal data
- Unique contract numbers
- Configurable contract terms, services, and pricing
- Special clauses support
- PDF URL storage

### Contract Lifecycle
```
draft → sent → signed (by client) → active
```

### Contract Features
- **Digital Signatures:** Canvas-based signature capture
- **Provider Signatures:** Admin/manager counter-signing
- **Amendments:** Version-controlled contract changes via `contract_amendments` table
- **Follow-up Emails:** Automated reminder sequences for unsigned contracts (3, 7, 14 days)
- **Unsubscribe:** Token-based email opt-out via `/unsubscribe/contract/:token`

### Database Tables
- `contracts`: Primary contract records
- `contract_amendments`: Change history
- `contract_email_preferences`: Email opt-out tracking
- `proposal_signatures`: Signature audit trail

---

## 11. Quote Request Pipeline

### Flow
```
Main Website → receive-quote Edge Function → quote_requests table → Admin Assignment → Salesperson Action
```

### Quote Request Statuses
| Status | Description |
|---|---|
| `new` | Just received, unassigned |
| `assigned` | Assigned to a salesperson |
| `proposal_created` | Proposal has been generated |

### Features
- **Auto-Assignment:** Configurable via `AutoAssignQuotesToggle` in admin
- **Manual Assignment:** Admin can assign to any salesperson
- **Email Notifications:** `notify-quote-assignment` edge function sends assignment emails
- **Affiliate Tracking:** Quote requests carry `affiliate_link_code`, `affiliate_referral_id`, `affiliate_commission_rate`
- **Service Configs:** Pre-selected services and configurations from the main website

### Admin Quote Management (`QuoteRequestsTab`)
- Filter by status, salesperson, date range
- Bulk assignment
- Import to proposal
- View source affiliate data

---

## 12. Affiliate & Referral System

### Affiliate Management
- **Table:** `affiliates` — stores partner profiles with unique `affiliate_code`
- **Commission Tracking:** Configurable `commission_rate` per affiliate (default 10%)
- **Earnings:** `total_earnings`, `total_referrals` counters

### Referral Tracking (`src/hooks/useReferralTracking.ts`)
- URL parameter-based tracking (`?ref=CODE`)
- Cookie/localStorage persistence
- Automatic linking to proposals and quote requests

### Affiliate Portal Integration
- **Cross-portal messaging:** `cross_portal_messages` table
- **Sync functions:** `sync-affiliate-to-proposal`, `push-message-to-affiliate`, `receive-affiliate-message`
- **Affiliate Handoff:** `AffiliateHandoffProvider` manages cross-portal state

### Referral Dashboard (`/referral-dashboard`)
- Referral link management
- Commission tracking and history
- Payout status via `affiliate_payments` table

### Referral Partner Program (`/referral-partners`)
- Public-facing program information
- Sign-up flow
- Commission structure display

### Conversion Tracking
- **Edge Function:** `track-conversion`
- Tracks affiliate referral → proposal → payment conversions
- **Edge Function:** `process-payouts` — processes affiliate commission payouts

---

## 13. Sales Tools & Resources

### Sales Resources Hub (`/sales-resources`)
- **Component:** `src/pages/Dashboard.tsx`
- Centralized access to all sales tools
- Role-filtered resource visibility
- Quick-launch cards for common workflows

### Sales Presentation Decks (`/sales-presentation-decks`)
- **Database:** `presentation_decks` table
- Categorized deck library (Sales, Onboarding, Training, etc.)
- Canva integration for editing
- PDF viewing and download
- **Admin Features:**
  - Add new decks with category, description, URLs
  - Edit existing deck metadata inline
  - Activate/deactivate decks (inactive hidden from non-admins)
  - Dynamic category filtering

### Cost Calculator (`/calculator`)
- Interactive pricing calculator
- Service selection with hour configuration
- Contract length comparison
- Currency conversion
- Preview mode (`/calculator/preview`)

### ROI Calculator (`/roi`)
- Return on investment projections
- Industry-specific templates (`/industry-roi-templates`)
- Time and cost savings visualization
- Preview mode (`/roi/preview`)

### Competitive Analysis (`/competitive-analysis`)
- Side-by-side comparison tool
- PDF export via `CompetitiveAnalysisPDFDocument`

### Client Needs Assessment (`/client-needs-assessment`)
- Guided questionnaire for understanding client requirements
- Service recommendation engine

### Savings Timeline (`/savings-timeline`)
- Visual projection of cost savings over time
- Configurable parameters

### VA Skills Matcher (`/va-skills-matcher`)
- AI-powered matching of client needs to VA capabilities
- Skill assessment questionnaire

### VA Pitch Deck (`/va-pitch-deck`)
- Pre-built pitch presentation for VA services

### Earnings Calculators
- **Salesperson:** `/salesperson-earnings-calculator` — commission projections
- **Referral Partner:** `/referral-earnings-calculator` — referral income projections

---

## 14. VA (Virtual Assistant) Management

### VA Profiles
- **Database:** `va_profiles` table (managed via admin)
- Individual VA pages with skills, experience, portfolio
- **VA Catalogue** (`/va-catalogue`): Browsable directory for salespeople
- **VA Profile** (`/va-profile/:slug`): Detailed individual profile
- **VA Candidate** (`/va-candidate/:id`): Candidate evaluation view

### VA Alignment Form
- **Component:** `VAAlignmentFormModal`
- Client-VA matching questionnaire
- **Edge Function:** `send-va-alignment` — processes and stores alignment submissions
- Admin review via `VAAlignmentSubmissionsTab`

### Recruitment (Tavus Integration)
- AI video interview system
- **Tables:** `interview_candidates`, `interview_results`, `interview_summary_notes`, `conversation_transcripts`
- **Campaigns:** `recruitment_campaigns`, `campaign_invitations`
- Automated scoring with weighted criteria
- **Edge Function:** `create-tavus-conversation`

### Service Types & Rates
| VA Position | 3-Month (SGD/hr) | 6-Month (SGD/hr) | 12-Month (SGD/hr) |
|---|---|---|---|
| General/Admin VA | 11 | 9 | 8 |
| Social Media VA | 14 | 12 | 10 |
| Automation VA | 17 | 15 | 13 |
| Executive VA | 11 | 9 | 8 |
| Bookkeeping VA | 11 | 9 | 8 |
| Sales VA | 10 | 9 | 7 |
| Telemarketer VA (Malaysia) | 14 | 12 | 9 |
| Telemarketer VA (Philippines) | 10 | 9 | 7 |
| LinkedIn VA | 14 | 12 | 9 |
| Graphic Design VA | 13 | 10 | 9 |
| Video Editing VA | 13 | 10 | 9 |

---

## 15. Messaging & Communication

### Cross-Portal Messaging
- **Tables:** `cross_portal_messages`, `cross_portal_attachments`, `cross_portal_reactions`
- Real-time message delivery between salespeople and affiliate partners
- Features: file attachments, emoji reactions, pinning, read receipts, archiving

### Salesperson Messages (`/salesperson-messages`)
- **Components:** `SalesConversationList`, `SalesChatWindow`
- Conversation list with unread indicators
- Real-time chat with typing indicators
- Message seen status via `mark-salesperson-message-seen` edge function

### Internal Messaging (Team Chat)
- **Tables:** `channels`, `channel_members`, `messages`, `message_reactions`, `message_mentions`, `read_receipts`
- Project-based channels
- Thread support (`thread_parent_id`)
- File attachments (`file_attachments` table)
- @mentions (`message_mentions` table)

### Edge Functions for Messaging
- `send-salesperson-message`: Send messages from salesperson portal
- `push-message-to-affiliate`: Push messages to external affiliate portal
- `receive-affiliate-message`: Receive messages from affiliate portal
- `toggle-salesperson-reaction`: Add/remove message reactions
- `mark-salesperson-message-seen`: Update read status

---

## 16. Payment & Billing (Stripe)

### Checkout Flow
1. Client views public proposal
2. Selects package and clicks "Pay Now"
3. **Edge Function:** `create-checkout` creates Stripe Checkout Session
4. Client completes payment on Stripe
5. **Edge Function:** `stripe-webhook` processes `checkout.session.completed`
6. Proposal `payment_status` updated to `paid`
7. Contract auto-generated
8. Onboarding emails triggered

### Stripe Integration
- **Edge Function:** `create-checkout` — Creates Stripe payment sessions
- **Edge Function:** `stripe-webhook` — Handles payment events
- **Edge Function:** `customer-portal` — Opens Stripe Customer Portal for subscription management
- **Edge Function:** `check-subscription` — Verifies subscription status
- **Edge Function:** `get-subscription-details` — Retrieves subscription details

### Email Templates (Stripe Webhook)
- `customer-onboarding.tsx`: Welcome email to new clients after payment
- `internal-notification.tsx`: Notifies admin team of new payments

---

## 17. Email & Notification System

### Email Delivery
- **Provider:** Resend
- **Edge Function:** `send-email` — Generic email sending
- **Edge Function:** `send-reminder-emails` — Automated reminder sequences
- **Edge Function:** `trigger-reminders` — Cron trigger for scheduled reminders

### Reminder Email Templates
| Template | Trigger |
|---|---|
| `day-2-checkin` | 2 days after signup |
| `day-5-progress` | 5 days after signup |
| `day-7-followup` | 7 days after signup |
| `day-14-checkin` | 14 days after signup |
| `contract-followup-day-3` | 3 days after contract sent |
| `contract-followup-day-7` | 7 days after contract sent |
| `contract-followup-day-14` | 14 days after contract sent |
| `subscription-renewal` | Before subscription renewal |

### Admin Notifications
- **Hook:** `useAdminNotifications` — Real-time notification tracking
- **Component:** `NotificationBell` — In-sidebar notification indicator
- **Database:** `notifications` table
- Notification types: new quotes, proposals, contracts, user registrations
- Tab-aware read status tracking (`useAdminTabReadStatus`)

### Activity Logging
- **Utility:** `src/lib/auditLogger.ts`
- **Table:** `activity_logs`
- Tracks: action type, description, performer, target, metadata, IP, user agent
- Viewable in admin Activity Log tab

---

## 18. Operations Dashboard

**Component:** `src/components/admin/OperationsDashboard.tsx`

### Pipeline Health Monitoring
- **Stale Quotes:** Quotes >7 days old with status `new` or `assigned`
- **Aging Proposals:** Proposals pending >14 days
- **Unsigned Contracts:** Contracts with status `sent` and `is_signed_by_client = false`
- **Conversion Rate:** Paid proposals / total proposals

### Sub-Components
| Component | Purpose |
|---|---|
| `PipelineHealthCards` | Summary cards with alert indicators |
| `AttentionRequiredList` | Prioritized list of items needing action |
| `ConversionFunnel` | Visual funnel: Quotes → Assigned → Proposals → Paid |
| `SLATracker` | Average times: quote-to-assignment, assignment-to-proposal, proposal-to-payment, contract signature |
| `LiveIndicator` | Real-time connection status |

### Real-Time Updates
- **Hook:** `useOperationsDashboardRealtime`
- Subscribes to `quote_requests`, `proposals`, `contracts` tables
- Live INSERT/UPDATE handling without page refresh

### SLA Metrics
| Metric | Description |
|---|---|
| Quote → Assignment | Average hours from quote creation to salesperson assignment |
| Assignment → Proposal | Average hours from assignment to proposal creation |
| Proposal → Payment | Average days from proposal creation to payment |
| Contract Signature | Average days from contract creation to client signature |

---

## 19. Edge Functions

All edge functions are deployed as Supabase Edge Functions (Deno runtime).

| Function | Purpose |
|---|---|
| `check-subscription` | Verify user's Stripe subscription status |
| `contract-unsubscribe` | Process contract email opt-outs |
| `create-checkout` | Create Stripe Checkout sessions |
| `create-tavus-conversation` | Initialize Tavus AI video interviews |
| `customer-portal` | Generate Stripe Customer Portal URLs |
| `delete-user` | Idempotent user deletion (auth + profile) |
| `generate-contract` | Auto-generate contracts from proposals |
| `generate-proposal-content` | AI content generation for proposals |
| `get-service-rates` | Retrieve current service hourly rates |
| `get-subscription-details` | Fetch Stripe subscription details |
| `invite-user` | Send user invitations with role assignment |
| `mark-salesperson-message-seen` | Update message read status |
| `notify-quote-assignment` | Email notification for quote assignments |
| `process-payouts` | Process affiliate commission payouts |
| `push-message-to-affiliate` | Push messages to affiliate portal |
| `push-salesperson-to-affiliate` | Sync salesperson data to affiliate portal |
| `receive-affiliate-message` | Receive messages from affiliate portal |
| `receive-affiliate-sync` | Receive affiliate data sync |
| `receive-order` | Process incoming orders |
| `receive-quote` | Receive quote requests from main website |
| `resend-invitation` | Re-send pending invitations |
| `reset-user-password` | Admin-triggered password resets |
| `save-proposal` | Save/update proposal data |
| `send-email` | Generic email sending via Resend |
| `send-reminder-emails` | Automated email reminder sequences |
| `send-salesperson-message` | Send cross-portal messages |
| `send-va-alignment` | Process VA alignment form submissions |
| `sign-contract` | Process digital contract signatures |
| `stripe-webhook` | Handle Stripe payment events |
| `submit-signature` | Process proposal signature submissions |
| `sync-affiliate-to-proposal` | Link affiliate data to proposals |
| `sync-salesperson-trigger` | Trigger salesperson data sync |
| `toggle-salesperson-reaction` | Add/remove message reactions |
| `track-conversion` | Track affiliate referral conversions |
| `trigger-reminders` | Cron-triggered reminder processing |

---

## 20. Database Schema Overview

### Core Business Tables
| Table | Purpose |
|---|---|
| `profiles` | User profiles (extends auth.users) |
| `proposals` | Sales proposals with service configs |
| `contracts` | Service agreements |
| `contract_amendments` | Contract change history |
| `quote_requests` | Inbound leads from main website |
| `customers` | Salesperson CRM contacts |
| `proposal_signatures` | Digital signature records |

### Affiliate & Referral Tables
| Table | Purpose |
|---|---|
| `affiliates` | Affiliate partner profiles |
| `affiliate_payments` | Commission payment records |

### Messaging Tables
| Table | Purpose |
|---|---|
| `cross_portal_messages` | Salesperson ↔ Affiliate messages |
| `cross_portal_attachments` | Message file attachments |
| `cross_portal_reactions` | Message emoji reactions |
| `archived_conversations` | Archived message threads |
| `channels` | Team chat channels |
| `channel_members` | Channel membership |
| `messages` | Team chat messages |
| `message_reactions` | Chat message reactions |
| `message_mentions` | @mention tracking |
| `read_receipts` | Message read status |
| `file_attachments` | Chat file uploads |

### VA & Recruitment Tables
| Table | Purpose |
|---|---|
| `interview_candidates` | VA interview candidates |
| `interview_results` | AI-scored interview results |
| `interview_summary_notes` | Reviewer notes on interviews |
| `conversation_transcripts` | Interview transcripts |
| `recruitment_campaigns` | Hiring campaigns |
| `campaign_invitations` | Campaign invite tracking |
| `recruitment_agencies` | Agency profiles |

### Platform Management Tables
| Table | Purpose |
|---|---|
| `activity_logs` | Audit trail |
| `notifications` | User notifications |
| `email_reminders` | Scheduled email tracking |
| `app_settings` | Platform configuration key-value store |
| `app_pages` | Page-level access control |
| `custom_roles` | Custom role definitions |
| `presentation_decks` | Sales deck metadata |
| `achievements` | Gamification achievements |
| `contract_email_preferences` | Email opt-out tracking |

### Collaboration Tables
| Table | Purpose |
|---|---|
| `projects` | Client projects |
| `project_members` | Project team assignments |
| `notion_pages` | Internal knowledge base pages |
| `eod_reports` | VA end-of-day reports |

### Row-Level Security (RLS)
All tables have RLS enabled with policies based on:
- `auth.uid()` — match against user_id columns
- `get_current_user_role()` — database function returning the user's role from profiles
- `is_channel_member()` — database function for channel access checks
- Role-based policies: admin/manager get broad access; sales/partner get scoped access; clients get self-only access

---

## 21. Service Rates & Pricing

### Rate Management
- **Utility:** `src/utils/serviceCalculations.ts`
- **Edge Function:** `get-service-rates` — fetches rates from database
- **Hook:** `useServiceRates` — client-side rate fetching with caching
- **Admin Config:** Service Rates tab in admin dashboard

### Calculation Functions
```typescript
calculateServiceCost(service, hours, contractLength, rates, currency)
calculateMultiRoleCost(vas, contractLength, rates, currency)
calculateTotalMonthlyCost(services, configs, contractLength, rates, currency)
```

### Package Types
- **20-Hour Package:** Part-time VA allocation
- **40-Hour Package:** Full-time VA allocation
- **Multi-Role:** Multiple VAs with split hours within a package

### Currency Support
- **Default:** SGD (Singapore Dollar)
- **Supported:** USD, GBP, EUR, AUD, NZD, MYR, PHP
- **Context:** `CurrencyContext` with `CurrencySelector` component
- **Service:** `src/services/currencyService.ts` — exchange rate conversion

---

## 22. PDF Generation

### Libraries
- **@react-pdf/renderer:** React-based PDF components
- **jspdf:** Direct PDF generation
- **html2canvas:** HTML-to-image conversion for PDF content

### PDF Document Components
| Component | Purpose |
|---|---|
| `ProposalPDFDocument` | Full proposal PDF with branding |
| `ROIPDFDocument` | ROI analysis report |
| `CompetitiveAnalysisPDFDocument` | Competitive comparison report |

### Utilities
- `src/utils/pdfGenerator.ts` — Core PDF generation logic
- `src/utils/enhancedPdfGenerator.ts` — Enhanced formatting and styling
- `src/utils/htmlToPdf.ts` — HTML to PDF conversion
- `src/utils/printUtils.ts` — Browser print utilities

---

## 23. Performance & Optimization

### Code Splitting
- **Lazy Loading:** All non-critical pages use `React.lazy()` with `Suspense`
- **Fast-loaded pages:** `PublicProposal`, `ProposalPreview`, `AuthPage`, `Landing`, `Success`
- **PageLoader:** Spinner component shown during lazy load

### Query Optimization
- **React Query:** 5-minute stale time, 1 retry
- **Hook:** `useOptimizedQuery` — Custom query wrapper with caching strategies
- **Hook:** `useInfiniteScroll` — Paginated data loading

### Component Optimization
- **`FastLoadWrapper`:** Priority loading wrapper
- **`PerformanceWrapper`:** Performance monitoring wrapper
- **`OptimizedImage`:** Lazy-loaded images with placeholder
- **`SkeletonLoader`:** Content placeholder during loading
- **`LazyPageWrapper`:** Standardized lazy page container

### Hooks
- `usePerformanceOptimized` — Performance monitoring utilities

---

## 24. Currency Support

### CurrencyContext (`src/contexts/CurrencyContext.tsx`)
- Global currency state management
- Persisted preference
- Real-time conversion rates

### Supported Currencies
| Code | Currency |
|---|---|
| SGD | Singapore Dollar (default) |
| USD | US Dollar |
| GBP | British Pound |
| EUR | Euro |
| AUD | Australian Dollar |
| NZD | New Zealand Dollar |
| MYR | Malaysian Ringgit |
| PHP | Philippine Peso |

### CurrencySelector Component
- Dropdown selector available throughout the platform
- Updates all pricing displays in real-time

---

## 25. Design System

### Theming
- **CSS Variables:** Defined in `src/index.css` using HSL values
- **Tailwind Config:** Extended in `tailwind.config.ts`
- **Dark/Light Mode:** Supported via `next-themes`

### Semantic Tokens
```css
--background, --foreground
--primary, --primary-foreground
--secondary, --secondary-foreground
--muted, --muted-foreground
--accent, --accent-foreground
--destructive, --destructive-foreground
--card, --card-foreground
--popover, --popover-foreground
--border, --input, --ring
```

### Custom Brand Colors
- `catalyst-teal`: Primary brand color for active states
- Used extensively in sidebar active indicators and CTA buttons

### Component Library (shadcn/ui)
Full set of Radix UI-based components including:
- Accordion, Alert Dialog, Avatar, Badge, Button, Calendar, Card, Carousel
- Checkbox, Collapsible, Command, Context Menu, Dialog, Drawer
- Dropdown Menu, Form, Hover Card, Input, Label, Menubar
- Navigation Menu, Pagination, Popover, Progress, Radio Group
- Resizable, Scroll Area, Select, Separator, Sheet, Sidebar
- Skeleton, Slider, Switch, Table, Tabs, Textarea, Toast
- Toggle, Tooltip, Typing Textarea

---

## 26. Security Considerations

### Row-Level Security (RLS)
- All database tables have RLS enabled
- Policies enforce role-based data access at the database level
- `SECURITY DEFINER` functions bypass RLS for internal operations

### Authentication
- Supabase Auth handles all authentication
- Session tokens managed by Supabase client library
- Global sign-out clears all local storage auth keys

### API Security
- Edge functions validate `Authorization` headers
- Service role key used only in server-side edge functions
- Anon key used in client-side code (publishable)

### Known Security Notes
- Roles are currently stored in `profiles` table (identified as refactoring target)
- Admin status checked server-side via `get_current_user_role()` database function
- View mode/impersonation is UI-only — all data access still governed by the actual authenticated user's RLS policies

### Audit Trail
- `activity_logs` table records all significant platform actions
- Includes performer identity, target, action type, metadata, IP address, user agent

### Contract Security
- Digital signatures include IP address, user agent, and timestamp
- Signature images stored securely
- Audit trail JSON maintained per signature

---

## Appendix: File Structure Overview

```
src/
├── App.tsx                          # Root component with routing
├── main.tsx                         # Entry point
├── index.css                        # Global styles & design tokens
├── components/
│   ├── admin/                       # Admin dashboard components (30+ files)
│   │   ├── AdminSidebar.tsx         # Admin navigation sidebar
│   │   ├── OperationsDashboard.tsx  # Operations monitoring
│   │   ├── tabs/                    # Tab content components
│   │   └── ...
│   ├── pdf/                         # PDF generation components
│   ├── salesperson/                 # Sales CRM components
│   ├── ui/                          # shadcn/ui component library
│   ├── va/                          # VA management components
│   ├── Layout.tsx                   # Main layout wrapper
│   ├── AppSidebar.tsx               # Sales/Partner sidebar
│   ├── AuthGuard.tsx                # Authentication guard
│   ├── RoleGuard.tsx                # Role-based access guard
│   └── ...
├── config/
│   └── adminTabRegistry.ts          # Admin tab configuration
├── contexts/
│   ├── AuthContext.tsx               # Authentication state
│   ├── AdminContext.tsx              # Admin mode state
│   ├── CurrencyContext.tsx           # Currency preferences
│   └── ViewModeContext.tsx           # Admin view switching
├── hooks/                           # Custom React hooks (20+ files)
├── pages/                           # Page components (40+ files)
├── services/
│   └── currencyService.ts           # Currency conversion
├── utils/                           # Utility functions
│   ├── serviceCalculations.ts       # Pricing calculations
│   ├── pdfGenerator.ts              # PDF generation
│   ├── affiliateTracking.ts         # Affiliate tracking
│   └── ...
└── integrations/
    └── supabase/
        ├── client.ts                # Supabase client instance
        └── types.ts                 # Auto-generated DB types

supabase/
└── functions/                       # 36 Deno edge functions
    ├── check-subscription/
    ├── create-checkout/
    ├── stripe-webhook/
    ├── receive-quote/
    ├── save-proposal/
    ├── generate-contract/
    └── ...
```

---

*This documentation is auto-maintained. For the latest changes, refer to the codebase and the Lovable project at https://lovable.dev/projects/a9d0d4e2-dfac-486a-ab5f-3b401d99fee7*
