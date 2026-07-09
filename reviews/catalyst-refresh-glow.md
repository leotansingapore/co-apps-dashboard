# Catalyst Refresh Glow -- Critical Product Review

**App role (per PRD):** Public marketing website, top of funnel, lead capture
**App role (actual):** Marketing site + the "Catalyst Dashboard" auth/affiliate/commerce hub (see verdict)
**Reviewed against:** origin/main (fresh clone), PRD.md, ECOSYSTEM-PRD.md
**Date:** 2026-07-09

> **Project map discovered:** this repo's own Supabase is `lybfxzttbikispdjjijc`; Sales Portal ("Proposal Generator") is `glowmruekgeygxplguew`; HourHive (read-only VA data) is `swbupqrcrfgldibcymxz`-family; a separate external affiliate portal is `rbgfaifmvgzvyevxhdtb`. NONE of these appear in the ECOSYSTEM-PRD's project table.

---

## Ecosystem handoffs

| Handoff | Status | Evidence | Notes |
|---|---|---|---|
| Custom-quote form -> Sales Portal CRM | EXISTS | `QuoteRequestModal.tsx:319` inserts to OWN `form_submissions`, then `:354` fires `send-quote-to-proposal`, which POSTs to sales portal `receive-quote` | Fire-and-forget: bridge returns HTTP 200 even on failure. Silent data loss possible. |
| VA "Request a proposal" -> Sales Portal CRM | EXISTS | `useRequestProposalForVA.ts` inserts DIRECTLY into sales portal `quote_requests` via `salesSupabase` (`src/integrations/sales/client.ts`) | Direct client-side anon write. No affiliate code, no UTM carried. |
| Pricing "detailed proposal" -> Sales Portal CRM | EXISTS | `useRequestDetailedProposal.ts` direct insert to sales portal `quote_requests` | Same: no affiliate/UTM. |
| Contact form -> Sales Portal CRM | MISSING | `ContactUs.tsx:130` inserts to OWN `form_submissions` only | Lead sits in marketing site's own DB, visible only via in-app Dashboard LeadsTab. |
| Free Consultation -> Sales Portal CRM | MISSING | `FreeConsultation.tsx:183` -> OWN `form_submissions` only | Never reaches CRM. |
| Industry contact form -> Sales Portal CRM | MISSING | `IndustryContactForm.tsx:85` -> OWN `form_submissions` only | Never reaches CRM. |
| Booking / consultation slots -> Sales Portal CRM | MISSING | `Booking.tsx:183` -> OWN `bookings` + `:207` `form_submissions` | Booked discovery calls never sync to the sales pipeline. |
| "Get Started" paid checkout -> Sales Portal | PARTIAL | `GetStarted.tsx:270/299` -> `create-order`/`create-checkout` (own project); no forward to sales portal in `create-order`; sync deferred to `verify-payment` | Pre-payment abandoners never reach CRM. |
| Financial-advisors landing page leads | MISSING (goes elsewhere) | `src/pages/landing/new-lp/lib/lead.ts:11` POSTs to a GOHIGHLEVEL webhook, not the Sales Portal | Entire `/financial-advisors-v3` funnel bypasses the CO ecosystem into a different CRM. |
| UTM preservation (ER-04) | MISSING | Zero inbound UTM capture repo-wide; only `fbclid` is captured (`src/utils/metaCapi.ts:18`); `BookingForm.tsx:34` HARDCODES `utm_source:'landing-page'` outbound to Calendly | ER-04 not met. Ad attribution is dropped at the door. |
| Referral/affiliate persistence (ER-05) | PARTIAL | `useAffiliateTracking.ts` stores `?ref=` in cookie+localStorage (100 days), gated on cookie consent. Carried by QuoteModal (288), ContactUs (136), GetStarted (293) | The two direct proposal hooks (VA + pricing) drop it; consent-pending/rejected visitors never persist the ref. |
| Cross-project affiliate handoff token | MISSING (dead code) | `useAffiliateHandoff.ts` + `create-affiliate-handoff` + `affiliate_handoff_tokens` table -- zero callers of `navigateWithHandoff`/`createHandoffUrl` | Entire secure handoff mechanism built and unused. |
| CTAs to Sales Portal/Opus carry context | MISSING | No hardcoded outbound links to the sales portal domain in `src` (only server-to-server edge calls) | The PRD's "marketing site links to Sales Portal with UTM" model does not exist as navigation. |
| CD_SUPABASE / auth-hub question | CONFIRMED -- NOT just a marketing site | Own project has full auth (`Auth.tsx:89` signInWithPassword, `:102` signUp, `:32` user_roles), admin `Dashboard.tsx` with Leads/Payouts/Commissions/Users/VATeam/Blog CMS tabs, Stripe Connect (`create-stripe-connect-onboarding`, `stripe-connect-webhook`), ~90 edge functions. 110 code refs to its URL | This project's Supabase doubles as the Catalyst Dashboard / auth+affiliate+commerce hub ("CD_SUPABASE") that Talent Spotter bridges auth into. The "marketing site" label is wrong. |

## Top bugs & edge cases

1. **Hardcoded webhook secret shipped in the browser bundle** -- `QuoteRequestModal.tsx:386` posts to the external affiliate portal's `conversion-webhook` with `'x-webhook-secret': 'aff_whsec_7kX9...'` in client-side code. Anyone can read it in devtools and forge affiliate conversions. Rotate + move server-side.
2. **Silent CRM data loss on the main quote path** -- `send-quote-to-proposal/index.ts` is fire-and-forget and returns HTTP 200 even when the sales portal call fails. A down/renamed endpoint drops leads with no alert; the user still sees "success."
3. **Broken GoHighLevel webhook URL** -- `lead.ts:11` default ends in `/webhook-trigger/undefined`. Unless `VITE_LEAD_WEBHOOK_URL` is set in Vercel, financial-advisor LP leads POST to a dead endpoint -- and `sendLead` swallows the error and proceeds to Calendly, failing invisibly.
4. **Consent-gated referral loss (ER-05 hole)** -- consent `pending`: ref only in sessionStorage, lost on tab close; consent `rejected`: ref discarded. Partners lose attribution for privacy-conscious visitors.
5. **Two proposal hooks strip affiliate + UTM context** -- `useRequestProposalForVA.ts` / `useRequestDetailedProposal.ts` payloads have no affiliate/utm fields even when a `?ref=` cookie exists.
6. **Whole affiliate-handoff subsystem is dead code** -- no callers. Wire it in or delete it; right now it is untested attack surface.
7. **Anon key hard-writes to a foreign project** -- VA/pricing proposals insert into the sales portal's `quote_requests` from the browser. Security rests entirely on that project's RLS.
8. **Duplicate/parallel lead writes for one submission** -- QuoteModal fires three independent fire-and-forget calls (`send-quote-notification`, `send-quote-to-proposal`, external `conversion-webhook`). Partial success yields inconsistent state with no reconciliation.
9. **Referral auto-create side effects on read path** -- `send-quote-to-proposal` auto-creates `affiliate_links`/`affiliate_referrals` during quote submission; retried submissions create duplicates (no idempotency key on `quoteId`).
10. **`fbclid` captured but UTM ignored** -- `metaCapi.ts` proves URL-param capture exists, yet Google/email campaign UTMs are silently dropped, breaking multi-channel attribution.

## UX friction / conversion issues

1. **Fragmented lead destinations** -- five forms land in three systems (own `form_submissions`, sales portal `quote_requests`, GoHighLevel). Sales has no single inbox.
2. **No attribution = no optimization** -- with UTMs dropped, marketing cannot tell which campaign produced a quote.
3. **"Success" toasts on failed handoffs** -- users are told they succeeded when the lead may have gone nowhere; sales never follows up, prospect churns.
4. **Manual referral-code entry duplicates auto-tracking** -- typed code overrides the `?ref=` cookie (QuoteModal:288), creating conflicting attribution.
5. **Consent banner silently suppresses partner credit** -- partners experience it as "the site doesn't track my leads."
6. **Two separate proposal flows, inconsistent SLA copy** ("within 1 business day" variants + a third success screen).
7. **Financial-advisor LP is an ecosystem island** -- own quiz, own GHL CRM, own Calendly; invisible to the rest of CO.
8. **A booked discovery call -- the hottest lead -- never reaches the sales portal**; reps must live in two dashboards.

## Challenged design decisions

1. **"Marketing site" is actually the platform's auth/commerce/affiliate hub.** Stripe Connect payouts, commission ledgers, admin roles, and a blog CMS inside the top-of-funnel SEO site couples the highest-traffic public surface to the most sensitive money/auth logic. A public-page XSS now touches payouts. Split it.
2. **Client-side anon writes into a foreign Supabase project** (VA/pricing proposals) instead of routing through the existing `send-quote-to-proposal` edge function. Two handoff patterns for the same job; the direct-write one is weaker, unattributed, and harder to secure.
3. **Fire-and-forget everywhere with HTTP 200 on failure.** No queue, retry, or dead-letter -- "non-blocking" silently means "lossy." A lightweight outbox/retry fixes the biggest funnel leak.
4. **A full secure cross-project handoff-token system built and never called** -- signals an unfinished migration; one of the two architectures should be deleted.
5. **Hardcoded project URLs + anon key + webhook secret in source** rather than env-driven. Rotations require code deploys and leak secrets.

## PRD vs reality gaps

- **App PRD is fundamentally wrong about the architecture.** PRD.md:120 "Static site, no Supabase backend"; :122 "No database"; :110 "No user accounts or login"; :111 "No CMS or admin panel"; :112 "No payment processing"; :113 "No blog platform." Reality: full Supabase backend, auth/signup, admin Dashboard, TipTap blog CMS with prerendering, Stripe + Stripe Connect payouts, affiliate/commission engine. Every Non-Goal is violated.
- **Ecosystem PRD equally stale:** lists this app as "(static site) -- no Supabase". None of the four real project IDs this repo uses appear anywhere in the ecosystem PRD. The documented project inventory cannot be trusted.
- **US-002/FR-13 "Quote form submits to Sales Portal receive-quote":** only the custom-quote modal does; contact/consultation/booking/industry forms never reach the CRM.
- **US-002/FR-15 "UTM parameters preserved":** not implemented (ER-04 unmet).
- **ER-05 referral persistence:** only on some paths; broken for consent-pending/rejected and the two direct proposal hooks.
- **PRD Open Question #3 ("quote form here or redirect to Sales Portal?"):** the shipped answer is "both, inconsistently."

## Verdict

Partially, and leakily. The site feeds the funnel for exactly one first-class path -- the custom-quote modal (and post-payment Get Started) reach the Sales Portal with affiliate attribution -- but contact, free-consultation, industry, booking, and the entire financial-advisors landing page either sit in this project's own database or divert to GoHighLevel, and inbound UTM attribution is dropped everywhere. The two most important ecosystem findings: this "marketing site" is actually the Catalyst Dashboard auth/affiliate/commerce hub (contradicting both PRDs), and its cross-project handoffs are fire-and-forget with swallowed errors plus a client-exposed webhook secret -- so leads and partner commissions can vanish silently while the visitor is told "success."
