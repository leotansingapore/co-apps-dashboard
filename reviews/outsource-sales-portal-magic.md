# Sales Portal (outsource-sales-portal-magic) -- Critical Product Review

**App role:** Sales dashboard -- CRM, lead management, proposals, Stripe payments, entry point for new clients
**Reviewed against:** origin/main (fresh clone), PRD.md, PROJECT-DOCS.md, ECOSYSTEM-PRD.md
**Date:** 2026-07-09

---

## Ecosystem handoffs

| Handoff | Status | Evidence | Notes |
|---|---|---|---|
| Lead intake from marketing site | EXISTS (auth MISSING) | `receive-quote/index.ts:211-354` inserts into `quote_requests` with affiliate capture (316-347); `config.toml` sets `verify_jwt = false` | NO shared secret at all. Anyone who finds the URL can inject fake leads, spam round-robin assignment emails (544-567), and flood the admin Lark group. Every other receiver checks `x-webhook-secret`. |
| UTM capture (ER-04) | MISSING | Repo-wide grep for `utm_*`: zero hits in `src/` or `supabase/functions/`; only `source_page`/`submitted_at` stashed (`receive-quote:296-297`) | ER-04 has no landing zone in the sales portal. |
| CRM: salesperson sees THEIR leads | EXISTS (with an RLS hole) | `AssignedQuotes.tsx:82` `.eq('assigned_to', effectiveUserId)`; `SalespersonProposals.tsx:238` `.eq('salesperson_id', targetUserId)`. Quote RLS: `migrations/20260105015704...sql:42-48` | Quotes scoped in query AND RLS. Proposals scoped ONLY in the query -- `migrations/20251110083406...sql:3-7` `USING (true)` means any anon user can read every proposal via PostgREST. |
| Lead lifecycle stages | PARTIAL | Statuses in code: `new` -> `assigned` -> `proposal_created` -> `archived` | PRD US-004 promises New -> Contacted -> Proposal Sent -> Negotiation -> Won/Lost. No contacted/negotiation/won/lost exists; the funnel the PRD sells cannot be reported. |
| Proposal acceptance -> talent alignment brief | PARTIAL (fully manual, not event-driven) | Brief form: `VAAlignmentFormModal.tsx` + `TalentAlignmentBriefStudio.tsx`, on the public proposal "regardless of signature state" (`PublicProposal.tsx:1089-1107`) and salesperson-editable. Sender: `send-va-alignment/index.ts` -- upserts `va_alignment_submissions` (141-200), forwards to Talent Spotter `receive-new-client` (`x-sync-secret`, 456-471) AND Opus `receive-va-alignment` (`x-webhook-secret`, 477-491), plus Lark (259-283) and Resend email (371-376) | Nothing fires on "client agrees"/signs/pays -- the brief fires whenever someone submits the form (client OR salesperson, any time, even pre-acceptance). Both cross-app forwards are fire-and-forget `.catch(console.warn)`. Also ZERO auth: `verify_jwt=false`, no secret check -- anyone can POST forged briefs that propagate into Talent Spotter and Opus. |
| Pre-payment recruiter push ("preview") | EXISTS | `send-to-recruitment/index.ts:114-146` posts with `paid_at: null` to Talent Spotter; manual button (`SalespersonProposals.tsx:351-384`); idempotency stamp `recruitment_triggered_at` (88-100) | Good ownership check + idempotency, but the stamp lives inside the `ai_content` JSON blob -- regenerating proposal content can erase it and allow duplicate pushes. |
| Stripe payment -> Opus client account | EXISTS | `stripe-webhook/index.ts:21-23` hardcodes `CLIENT_DASHBOARD_SYNC_URL = https://qouycamixsggwkwdotku...functions/v1/receive-client-account`; 3-attempt retry (155-206), strict `password_applied` validation (176-186); credentials email withheld on sync failure (610-611) | Best-engineered handoff in the app. But the URL is hardcoded and disagrees with the ecosystem PRD's Opus project id. Belongs in an env var. |
| Stripe payment -> recruiter notification (ER-03, <5 min) | EXISTS | `stripe-webhook/index.ts:954-1005` posts to Talent Spotter `receive-new-client` (`x-sync-secret`) synchronously; also on `invoice.paid` (1286-1302) | Meets the SLA when it works -- single attempt, failure only logged (1000). A recruiter never learns a paid client silently failed to arrive. |
| Opus -> sales portal (returning flows) | EXISTS | `receive-job-request/index.ts:61-68` (secret-checked, idempotent 84-100, routes to original salesperson 102-168); `receive-client-sync/index.ts:22-30` upserts `synced_clients` | Solid. But "no salesperson found" returns 200 to Opus, so the request evaporates with nobody assigned to chase it. |
| Referral/affiliate codes (ER-05) | EXISTS | Capture: `receive-quote:316-347`. Payment attribution: `stripe-webhook:786-804` resolves code from session metadata -> proposal -> linked quote; payload sent to main-site conversion webhook | Attribution chain is real end-to-end. Weakness: the shared secret is sent in the request BODY (881) instead of a header. |
| Lark vs ecosystem mapping | Clarified | `lark_notifications` = new-quote alerts (`receive-quote:369-399`); `talent_brief_webhook` = every brief; `proposal_created_webhook` via `save-proposal` | All three admin webhook settings are human-notification feeds into Lark. The actual app-to-app sync is separate env-var plumbing with no admin UI, no health indicator, no logs surface. |

## Top bugs & edge cases

1. **CRITICAL -- One-query admin takeover via `profiles`.** `migrations/20250726060323...sql:25-33`: latest `profiles` UPDATE policy allows `auth.uid() = user_id` with no WITH CHECK and no column restriction -- any salesperson can `UPDATE profiles SET role='admin'` on themselves. `get_current_user_role()` (8-14) reads `profiles.role` and backs nearly every admin gate. The hardened `user_roles`/`has_role()` system (migrations/20260330052329) is bypassed because the live authority is `profiles.role`.
2. **CRITICAL -- Whole `proposals` table world-readable.** Repeatedly re-added `USING (true)` SELECT policies plus `GRANT SELECT TO anon` (`migrations/20250925075324:9-21`, `20251110083406:3-7`, `20250929113008:5-9`). Client names, emails, phones, pricing for every deal, enumerable anonymously. Same pattern on `va_alignment_submissions` (`20260608164112:121-128` -- policy named "single submission by id" but predicate is `true`).
3. **CRITICAL -- Unauthenticated brief injection into three systems.** `send-va-alignment`: `verify_jwt=false`, no secret/ownership check (76-94); forged briefs for any proposalId upsert over the real one and forward to Talent Spotter, Opus, Lark, email. `get-va-alignment` (also unauthenticated) leaks brief PII by guessable proposalId.
4. **HIGH -- No idempotency on `checkout.session.completed`.** Stripe redelivers webhooks; the `invoice.paid` branch guards (1072-1075) but the checkout branch does not -- a redelivery RESETS an existing client's password (352-357) and re-fires onboarding email, recruiter notification, and Opus sync.
5. **HIGH -- "Service role" policies that are actually public.** `FOR ALL USING (true)` without `TO service_role` grants anon full CRUD: `app_settings` (`20260203075506:26-29` -- anyone can rewrite the Lark webhook URLs and exfiltrate every lead notification), `email_reminders`, `subscribers` UPDATE, `va_alignment_submissions` UPDATE, `cross_portal_messages`.
6. **HIGH -- Cross-app forwards have zero failure visibility.** `.catch(console.warn)` fire-and-forget; recruiter notify logs and moves on. No outbox, no retry (except Opus account sync), no admin surface showing "handoff failed."
7. **MEDIUM -- Weak temp passwords from `Math.random()`.** `stripe-webhook:328,355` and `reset-user-password:19-38` use non-cryptographic randomness for real account credentials.
8. **MEDIUM -- `listUsers({perPage:1000})` breaks at scale.** `stripe-webhook:345-348` finds existing clients by scanning the first 1000 auth users; user #1001 gets a failed provisioning path on repeat purchase.
9. **MEDIUM -- Handoff state buried in `ai_content` JSON.** `recruitment_triggered_at` and `_variant` live in the blob proposal generators rewrite -- regeneration wipes the idempotency stamp and studio/classic routing.
10. **LOW -- `save-proposal` accepts `userId = null`.** `verify_jwt=false`, auth header optional (41-48); unauthenticated calls write `user_id: null` (207-208) -- orphan proposals no salesperson dashboard will ever show.

## UX friction

1. **The pipeline can't answer "where is this deal?"** Statuses stop at `proposal_created`; won/lost/negotiation don't exist -- salespeople track outcomes in their heads.
2. **The brief prompt has no moment.** After payment, nothing nudges anyone to complete the Talent Alignment Brief; if never filled, the recruiter receives only the thin proposal-services payload with none of the rich brief fields.
3. **Client-facing 7-section brief (A-G) on the public proposal** is a big ask of an unsigned prospect; no save-draft -- abandon halfway and you lose everything.
4. **`window.confirm()` for the highest-stakes salesperson action** (pushing an unpaid client to recruitment) in an app full of shadcn modals.
5. **No integration health anywhere in admin.** Three Lark webhooks are configurable and testable, but the business-critical Opus/Talent-Spotter syncs have no status page, no last-success timestamp, no failed-handoff list.
6. **Two parallel proposal surfaces** (classic `PublicProposal.tsx` vs `PublicProposalStudio.tsx`, routed by `ai_content._variant`) double every fix and confuse "which link did the client get?"
7. **62 pages, many off-mission** -- `FitnessTracker.tsx`, `SavingsTimeline.tsx`, multiple calculators bloat nav and bundle for a sales tool.
8. **Payment with a missing email quietly dead-ends** -- only a Lark card tells the salesperson to "add their email to finish onboarding"; nothing in-app tracks the dangling state.

## Challenged design decisions

1. **Reusing `va_alignment_submissions` with column-remapping hacks** (`clientDetails -> company_name`, `outcomes -> success_vision`) to avoid a migration; the dual legacy+new payload doubles the contract every downstream app must parse forever.
2. **Hardcoded cross-project URLs in code** -- `stripe-webhook:21` (Opus, conflicting with the ecosystem PRD), `send-va-alignment:92`, `VAAlignmentFormModal.tsx:12`, `PublicProposal.tsx:160`. Landmines on any project migration.
3. **Two role systems:** hardened `user_roles`+`has_role()` exists but the live authority is the self-updatable `profiles.role` -- the worst of both.
4. **Point-to-point fire-and-forget webhooks as the ecosystem bus.** Five apps, no outbox/queue, no delivery ledger; ER-08 "apps function independently" is achieved by silently dropping data instead of buffering it.
5. **Making the client the brief author on an unsigned public proposal** while the stated flow is "after client agrees, the salesperson submits the brief" -- the code inverts both the actor and the timing (deliberately, per `PublicProposal.tsx:1089-1093` comment).

## PRD vs reality gaps

- **Wrong Supabase project in the PRD:** PRD.md:174 says `nkvmvtndwgmkwcabqojb`; the app is `glowmruekgeygxplguew` (`src/integrations/supabase/client.ts:5`).
- **US-004 pipeline stages** (Contacted/Negotiation/Won/Lost) don't exist.
- **ER-04 UTM preservation:** no UTM handling anywhere.
- **FR-09 proposal versioning:** no versions table or history UI; edits overwrite in place.
- **PRD "Recruitment (Tavus) FR-20..23 Done":** recruitment actually lives in tavus-talent-spotter; this repo only has `create-tavus-conversation` and the handoff senders.
- **G-03 "zero manual steps between payment and VA assignment trigger":** genuinely met by `stripe-webhook` -- but only on the happy path; every failure mode is a silent log line.
- **Undocumented reality the PRD misses:** pre-payment "preview" recruitment pushes, the Opus->sales `receive-job-request` re-engagement loop, the three-Lark-webhook notification layer.

## Verdict

The sales portal's ecosystem plumbing is more built-out than the PRD admits -- lead intake, Opus account provisioning with retries, recruiter notification, affiliate attribution, and a two-lane (preview/paid) recruitment handoff all exist and are wired to the right endpoints. But it is not safe to stand behind today: an anonymous visitor can read every proposal and brief, a salesperson can grant themselves admin with one UPDATE, the lead-intake and brief endpoints accept unauthenticated writes that propagate into two sibling apps, and Stripe webhook redelivery resets real client passwords. Fix the four security criticals and add failure visibility (an outbox or at least a failed-handoffs admin view) before treating this as the ecosystem's front door; the funnel-stage and brief-timing gaps are next.
