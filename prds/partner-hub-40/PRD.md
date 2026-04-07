# PRD: Partner Hub

Version: 1.0
Date: 2026-04-07
Status: Active
Owner: Leo Tan

---

## 1. Introduction

Partner Hub is the affiliate and partner management portal for Catalyst Outsourcing. It provides referral partners with tools to track their referrals, view commissions, access marketing resources, and manage their accounts. Admins use it to manage partner relationships, configure commission structures, and monitor the partner channel.

---

## 2. Goals

| ID | Goal | Success Metric |
|----|------|----------------|
| G-01 | Enable partners to refer clients independently | Partners generate referral links without admin help |
| G-02 | Track referral attribution end-to-end | 100% of partner referrals attributed and tracked |
| G-03 | Provide transparent commission reporting | Partners can see real-time commission status |
| G-04 | Streamline partner onboarding | New partner from signup to first referral < 24 hours |
| G-05 | Support dual-role users (affiliate + admin) | Users switch between portals without re-login |

---

## 3. User Roles

### Affiliate Partner
- Views personal referral dashboard (referrals, conversions, commissions)
- Generates and shares referral links
- Accesses marketing resources and sales materials
- Manages profile and payment details

### Admin
- Manages all partners (approve, suspend, configure)
- Sets commission structures and tiers
- Views aggregate partner channel metrics
- Processes commission payouts
- Manages marketing resources library

---

## 4. User Stories

### US-001: Partner signs up
**Description:** As a potential affiliate, I want to sign up for the partner program so I can start earning referral commissions.

**Acceptance Criteria:**
- [ ] Registration form with company/individual details
- [ ] Google Sign-in and magic link auth supported
- [ ] Admin approval required before activation
- [ ] Welcome email with getting started guide

### US-002: Partner generates referral link
**Description:** As a partner, I want to get my unique referral link so I can share it with potential clients.

**Acceptance Criteria:**
- [ ] Dashboard shows personalized referral link
- [ ] Link includes partner attribution code
- [ ] Copy-to-clipboard button
- [ ] Optional: UTM parameter customization

### US-003: Partner tracks referrals
**Description:** As a partner, I want to see who I've referred and whether they converted so I can track my earnings.

**Acceptance Criteria:**
- [ ] List of referrals with status (pending, converted, expired)
- [ ] Conversion date and payment amount
- [ ] Commission earned per referral
- [ ] Total earnings dashboard with period filtering

### US-004: Admin manages partners
**Description:** As an admin, I want to approve, configure, and monitor partners.

**Acceptance Criteria:**
- [ ] Partner list with status (pending, active, suspended)
- [ ] Approve/reject pending applications
- [ ] Set commission rate per partner
- [ ] View partner performance metrics
- [ ] Suspend/reactivate partner accounts
- [ ] Email notifications on role changes and suspensions

### US-005: Partner accesses resources
**Description:** As a partner, I want to access marketing materials so I can promote CO effectively.

**Acceptance Criteria:**
- [ ] Resource library with downloadable assets (PDFs, images, templates)
- [ ] Organized by category (pitch decks, one-pagers, social media)
- [ ] Admin can upload/manage resources

### US-006: Dual-role user switches portals
**Description:** As a user with both affiliate and admin roles, I want to switch between portals without logging out.

**Acceptance Criteria:**
- [ ] "Switch to Admin" button in affiliate sidebar (visible to admin users only)
- [ ] "Switch to Affiliate" button in admin sidebar
- [ ] Instant navigation via React Router (no page reload)
- [ ] Mobile: switcher in bottom nav "More" sheet

---

## 5. Functional Requirements

### Partner Management
- FR-01: Partner registration with admin approval workflow
- FR-02: Google Sign-in and magic link authentication
- FR-03: Role-based access control (affiliate, admin)
- FR-04: Partner profile management (contact info, payment details)
- FR-05: Partner suspension and reactivation with email notification

### Referral Tracking
- FR-06: Unique referral codes per partner
- FR-07: Referral link generation with attribution tracking
- FR-08: Referral status pipeline (sent -> clicked -> signed up -> paid -> commissioned)
- FR-09: Referral attribution persists through Sales Portal signup flow
- FR-10: Commission calculation based on configurable rates

### Dashboards
- FR-11: Partner dashboard: referrals, conversions, earnings, payouts
- FR-12: Admin dashboard: total partners, active referrals, channel revenue, top performers
- FR-13: Period filtering (weekly, monthly, quarterly, custom)

### Resources
- FR-14: Downloadable marketing resource library
- FR-15: Admin upload/manage resources
- FR-16: Resource categorization and search

### Notifications
- FR-17: Email on partner approval/rejection
- FR-18: Email on role change
- FR-19: Email on account suspension
- FR-20: Email on commission payout

---

## 6. Non-Goals

- No commission payment processing (tracked only, paid manually or via separate system)
- No direct integration with Catalyst Opus SSO (independent Supabase auth)
- No client-facing features (clients don't use Partner Hub)
- No sales proposal or contract management (handled by Sales Portal)
- No multi-level/MLM commission structures

---

## 7. Technical Considerations

### Auth
- Supabase Auth with Google Sign-in and magic link
- Independent from Catalyst Opus SSO (may integrate in future)
- Dual-role detection via `useAuth()` context

### Database
- Own Supabase instance
- Key tables: partners, referrals, commissions, resources, notifications
- RLS policies per role

### Integration Points
- **Sales Portal:** Referral codes must be recognized in the Sales Portal signup flow
- **Email:** Resend for transactional emails (role changes, suspensions, approvals)

---

## 8. Success Metrics

| Metric | Target |
|--------|--------|
| Active partners | > 20 |
| Monthly referrals generated | > 50 |
| Referral-to-conversion rate | > 10% |
| Partner self-service rate (no admin help needed) | > 90% |
| Time from signup to first referral | < 24 hours |

---

## 9. Current Status

| Feature | Status |
|---------|--------|
| Partner registration (Google + magic link) | Done |
| Affiliate dashboard | In Progress |
| Admin dashboard | In Progress |
| Referral link generation | In Progress |
| Commission tracking | Planned |
| Resource library | Planned |
| Portal switcher (dual-role) | Planned |
| Email notifications (role change, suspension) | In Progress |

---

## 10. Open Questions

1. Should Partner Hub authenticate via Catalyst Opus SSO in the future?
2. How are commissions paid out -- bank transfer, PayPal, or integrated payment?
3. Should referral codes expire after a certain period?
4. Should partners have access to a subset of Sales Portal analytics (their referrals' pipeline status)?
5. Is there a multi-tier commission structure planned (partner refers another partner)?
