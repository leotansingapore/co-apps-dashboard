# PRD: Sales Portal (Outsource Sales Portal Magic)

Version: 1.0
Date: 2026-04-07
Status: Active
Owner: Leo Tan

---

## 1. Introduction

The Sales Portal is the CRM and sales enablement platform for Catalyst Outsourcing. It manages the full sales lifecycle -- from lead capture and proposal generation, through Stripe payment collection and digital contract signing, to client onboarding and recruiter notification.

It is the **entry point** for all new clients into the CO ecosystem.

---

## 2. Goals

| ID | Goal | Success Metric |
|----|------|----------------|
| G-01 | Convert website leads into paying clients | Lead-to-payment conversion rate > 15% |
| G-02 | Enable salespeople to generate proposals in < 10 minutes | Average proposal creation time < 10 min |
| G-03 | Automate the quote-to-onboarding pipeline | Zero manual steps between payment and VA assignment trigger |
| G-04 | Support affiliate/partner referral tracking | 100% of referrals attributed with commission tracking |
| G-05 | Provide clients self-service contract and billing management | Clients sign contracts and pay without support intervention |

---

## 3. User Roles

### Admin
- Full platform governance -- manages salespeople, clients, pricing, and operations
- Views sales pipeline analytics and revenue metrics
- Configures service rates, email templates, and system settings

### Salesperson / Partner
- Generates and sends proposals to leads
- Manages assigned leads through the pipeline
- Views commissions and performance metrics
- Access to sales tools and resources

### Client (Customer)
- Views and accepts proposals
- Pays via Stripe (one-time or subscription)
- Signs digital contracts
- Manages billing and views invoices

### Candidate (Recruitment flow)
- Applies for VA positions
- Completes AI avatar interviews (Tavus integration)
- Receives feedback and offer letters

---

## 4. User Stories

### US-001: Lead submits quote request
**Description:** As a prospective client, I want to request a quote from the CO website so I can learn about pricing.

**Acceptance Criteria:**
- [ ] Quote request form captures company, services needed, budget, timeline
- [ ] Request arrives via `receive-quote` edge function
- [ ] Auto-assigned to available salesperson (or manual assignment by admin)
- [ ] Salesperson notified via email

### US-002: Salesperson creates proposal
**Description:** As a salesperson, I want to create a customized proposal so the client can review and accept it.

**Acceptance Criteria:**
- [ ] Select services, configure hours/packages, set pricing
- [ ] Multi-currency support (SGD, USD, PHP)
- [ ] Generate public proposal link for client review
- [ ] PDF export available
- [ ] Proposal tracks view count and client interactions

### US-003: Client pays via Stripe
**Description:** As a client, I want to pay for the selected package so I can start using VA services.

**Acceptance Criteria:**
- [ ] Client clicks "Accept & Pay" on public proposal
- [ ] Stripe checkout with payment method selection
- [ ] Payment confirmation triggers contract generation
- [ ] Recruiter project notified via webhook (`receive-new-client` edge function)
- [ ] Onboarding email sequence initiated

### US-004: Admin views sales pipeline
**Description:** As an admin, I want to see the full sales pipeline so I can manage team performance.

**Acceptance Criteria:**
- [ ] Pipeline stages: New Lead -> Contacted -> Proposal Sent -> Negotiation -> Won/Lost
- [ ] Revenue metrics, conversion rates, average deal size
- [ ] Per-salesperson performance breakdown
- [ ] Quote request backlog and assignment status

### US-005: Affiliate tracks referrals
**Description:** As an affiliate partner, I want to track my referrals and commissions.

**Acceptance Criteria:**
- [ ] Unique affiliate referral code/link
- [ ] Dashboard shows: referrals sent, conversions, commission earned
- [ ] Referral attribution persists through full signup flow
- [ ] Commission payable after client payment confirmed

### US-006: Client signs contract
**Description:** As a client, I want to sign my service agreement digitally.

**Acceptance Criteria:**
- [ ] Contract auto-generated from accepted proposal terms
- [ ] Digital signature capture
- [ ] Signed contract stored and accessible to both parties
- [ ] Admin notified on signature completion

---

## 5. Functional Requirements

### Lead Management
- FR-01: Quote requests captured via edge function from marketing site
- FR-02: Leads auto-assigned to salespeople based on availability rules
- FR-03: Lead status pipeline with configurable stages
- FR-04: Lead activity log (emails sent, calls made, notes added)

### Proposal System
- FR-05: Service configuration with hourly rates, packages, and custom line items
- FR-06: Multi-currency support (SGD, USD, PHP) with real-time conversion
- FR-07: Public proposal URL for client review (no login required)
- FR-08: Proposal PDF generation and download
- FR-09: Proposal versioning and revision history

### Payments & Billing
- FR-10: Stripe integration for one-time and recurring payments
- FR-11: Payment webhook processing via `stripe-webhook` edge function
- FR-12: Invoice generation with line items, tax, and payment history
- FR-13: Subscription management (upgrade, downgrade, cancel)

### Client Onboarding
- FR-14: Automated email sequence on payment completion (via Resend)
- FR-15: Recruiter notification on new client signup
- FR-16: Client self-service dashboard for billing and contract management

### Affiliate System
- FR-17: Unique referral codes with tracking
- FR-18: Commission calculation and reporting
- FR-19: Affiliate dashboard with referral metrics

### Recruitment (Tavus Integration)
- FR-20: Job posting management
- FR-21: AI avatar interviews via Tavus API
- FR-22: Candidate scoring and feedback
- FR-23: Offer letter generation and delivery

### Email Notifications
- FR-24: Role-changed notification emails
- FR-25: Account suspended notification emails
- FR-26: Onboarding sequence emails
- FR-27: Proposal viewed/accepted notifications

---

## 6. Non-Goals

- No VA time tracking (handled by HourHive Buddy)
- No task management or messaging (handled by Catalyst Opus)
- No partner commission payouts (tracked only, paid manually)
- No marketing content management (handled by Catalyst Refresh Glow)
- No SSO with Catalyst Opus (separate auth for salespeople)

---

## 7. Technical Considerations

### Database
- Supabase project: `nkvmvtndwgmkwcabqojb`
- 100+ tables with RLS policies
- 45+ edge functions

### Key Integrations
- **Stripe:** Payment processing, webhooks, subscription management
- **Resend:** Transactional email delivery
- **Tavus:** AI avatar video interviews for recruitment
- **Recruiter Project:** Webhook notification on new client payment

### Auth
- Supabase Auth (email/password) -- independent from Catalyst Opus SSO
- Role-based access: admin, salesperson, client, candidate

---

## 8. Success Metrics

| Metric | Target |
|--------|--------|
| Quote-to-proposal time | < 24 hours |
| Proposal creation time | < 10 minutes |
| Payment-to-onboarding time | < 48 hours |
| Affiliate referral attribution accuracy | 100% |
| Client self-service rate (no support needed) | > 80% |

---

## 9. Current Status

| Feature | Status |
|---------|--------|
| Lead management & pipeline | Done |
| Proposal generation & public links | Done |
| Stripe payment integration | Done |
| Contract signing | Done |
| Client dashboard | Done |
| Email notification system | In Progress |
| Affiliate/referral tracking | Done |
| Tavus AI interviews | Done |
| Recruiter notification webhook | Done |
| Operations dashboard | Done |

---

## 10. Open Questions

1. Should the Sales Portal eventually authenticate via Catalyst Opus SSO instead of separate auth?
2. How should multi-salesperson commission splits be handled?
3. Should clients be auto-provisioned in Catalyst Opus on payment, or wait for admin assignment?
4. What is the SLA for responding to quote requests?
