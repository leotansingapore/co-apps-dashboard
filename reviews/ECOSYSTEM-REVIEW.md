# CO Apps Ecosystem -- Critical Product Review (Synthesis)

**Date:** 2026-07-09
**Scope:** catalyst-opus, hourhive-buddy, outsource-sales-portal-magic, catalyst-refresh-glow, tavus-talent-spotter (partner-hub-40 excluded per owner)
**Method:** 5 parallel code reviews of fresh origin/main clones, verified against the PRDs in this repo and the owner's target flow.
**Per-app detail:** [catalyst-opus](catalyst-opus.md) | [hourhive-buddy](hourhive-buddy.md) | [outsource-sales-portal-magic](outsource-sales-portal-magic.md) | [catalyst-refresh-glow](catalyst-refresh-glow.md) | [tavus-talent-spotter](tavus-talent-spotter.md)

---

## Executive verdict

**The ecosystem is far more built than the PRDs admit -- and far less safe than the PRDs claim.** Almost every handoff in the target flow exists in code: lead capture -> CRM, brief -> Talent Spotter + Opus, payment -> Opus account with retries, hire -> VA provisioning, VA hours -> client view inside Opus. The plumbing is real. What breaks the ecosystem is (1) a trust model that is bypassable at nearly every seam, (2) three handoffs that silently drop data with the user told "success", (3) three parallel identity systems where the PRD promises one, and (4) documentation so stale that not a single Supabase project ID in the ecosystem PRD matches the code.

The target flow (lead -> proposal -> brief -> job -> interviews -> onboard-during-interviews -> chat -> time tracking) is roughly **70% plumbed, 40% reliable, and 0% observable**. No one can currently answer "did the brief for client X reach the recruiter?" without checking three databases.

---

## The target flow vs reality

| # | Stage (owner's ideal) | Reality | Status |
|---|---|---|---|
| 1 | Salesperson sees all their leads in the CRM | Quotes are salesperson-scoped in query + RLS. But leads fragment across 3 systems: only the quote modal reaches the CRM; contact/consultation/booking/industry forms sit in the marketing site's own DB; the financial-advisors LP goes to GoHighLevel. Lifecycle stops at `proposal_created` -- no contacted/negotiation/won/lost. UTM attribution dropped everywhere (ER-04 unmet). | PARTIAL |
| 2 | Client agrees to proposal -> salesperson submits talent alignment brief | Brief form + sender exist and forward to BOTH Talent Spotter and Opus. But nothing is event-driven: the brief can be filed by anyone (client or salesperson) at any time, even pre-acceptance, and there is no post-payment nudge. The endpoint is unauthenticated -- forged briefs propagate into three systems. | PARTIAL |
| 3 | Job posted on hiring portal (Talent Spotter) | The brief lands as a `new_client_notifications` row, NOT a job. A recruiter manually retypes it into a blank job form. No brief->job button, no prefill, no linkage; `jobs.notification_id` is never written, so progress-back notifications silently no-op. The single highest-value missing automation in the ecosystem. | BROKEN SEAM |
| 4 | Recruiter + client + salesperson see hiring progress | Client portal: correctly scoped, works. Salesperson portal: returns ALL clients' jobs, candidates, AI scores, transcripts and red flags to any token holder (no scoping column). Opus's client-facing recruitment update deep-links to `/job-requests`, a route that does not exist (404). | PARTIAL + LEAK |
| 5 | Interview coordination | Token-based client booking, calendar email, reminders all exist in Talent Spotter. No timezone-aware picker; Tavus webhook unauthenticated (scores forgeable); scoring deadlocks if Tavus never sends perception analysis. | MOSTLY EXISTS |
| 6 | Client onboarded into workspace during interviews | `receive-client-account` supports pre-payment "preview" accounts; `send-to-recruitment` pushes previews to hiring. The two-lane design matches the ideal. But Stripe webhook redelivery resets real client passwords, and Opus drops the client into a 119-route admin-grade app with an 18-item sidebar. | EXISTS, ROUGH |
| 7 | Client preps for VA, learns how to use VA | Generic onboarding wizard + generic "Success Academy" course library. No bespoke "your VA arrives Tuesday, here is how to brief them" flow tied to the hire event. The single biggest product gap for the client experience. | MISSING |
| 8 | Client chats with VA | Opus chat/channels/WebRTC exist and are mature. | EXISTS |
| 9 | Client tracks VA time | Client sees VA hours inside Opus (no app switch) and full EOD/screenshot feeds in HourHive. But the bridge that powers it accepts caller-asserted role/email with no token -- the ecosystem's single worst vulnerability. Payroll recomputes live in the browser rather than from immutable snapshots. | EXISTS, INSECURE |

---

## Cross-cutting findings

### 1. The trust model is broken at every seam (P0)

Each app individually contains a critical auth bypass, and the seams between them are worse:

- **HourHive `sso-data-access`** (192 actions, service-role key, `verify_jwt=false`) trusts `role`/`email` from the request body. Anyone with the public anon key reads all tenants' payroll, invoices, and screenshot URLs. Opus itself calls it unauthenticated (`tracker-api.ts` -- browser supplies the role).
- **Sales Portal:** any salesperson can self-promote to admin via one UPDATE (`profiles` policy, no WITH CHECK); the entire `proposals` table + briefs are anon-readable (`USING (true)` + `GRANT TO anon`); `receive-quote` and `send-va-alignment` accept unauthenticated writes that propagate into sibling apps.
- **Opus:** invite tokens + the roles they grant are world-readable, and `apply_public_invite_role` lets any authenticated user overwrite their own role -- admin takeover if any elevated link is active.
- **Talent Spotter:** salesperson tokens are unscoped (every client's candidates/transcripts/red-flags leak); Tavus webhook has no signature check (scores forgeable); interview creation is un-gated (paid Tavus credit abuse).
- **Marketing site:** a webhook secret is hardcoded in the shipped JS bundle; live credentials are committed to git in Opus (`credentials.txt`).

The pattern is identical everywhere: RLS/OAuth machinery was built (and is often good), then bypassed by service-role edge functions that re-implement authorization by hand and fail open. **The fix is one principle applied ecosystem-wide: derive identity from a verified token, never from the request body; secret-check every cross-app receiver; kill every `USING (true)`.**

### 2. Three identity systems where the PRD promises one

The ecosystem PRD says Opus is the OAuth PKCE authority and "no app has its own login screen." Reality:

- HourHive defaults to a **password form that relays Catalyst credentials through a proxy** (`grant_type=password`); the working PKCE redirect is hidden behind "Forgot your password?".
- Talent Spotter runs **its own full Supabase auth** (password + Google) and bridges to a third system.
- That third system: **catalyst-refresh-glow is not a static marketing site.** Its Supabase (`lybfxzttbikispdjjijc`) is a full auth + affiliate + Stripe Connect + blog CMS hub ("CD_SUPABASE") with ~90 edge functions -- the highest-traffic public surface coupled to the most sensitive payout logic, and undocumented in every PRD.

### 3. The ecosystem bus is fire-and-forget with zero observability

Every cross-app forward except the Stripe->Opus account sync is a single attempt with `.catch(console.warn)`. Quote->CRM sync returns HTTP 200 to the user even on failure. Recruiter-notify failure after payment is a silent log line. The brief forward can drop with no trace. The financial-advisors LP posts to a GHL webhook URL that defaults to `/undefined`. There is no outbox, no retry, no dead-letter, no admin "integration health" page anywhere in the ecosystem. Meanwhile admins CAN configure and test the three Lark notification webhooks -- the human-notification layer is more observable than the system-of-record layer.

### 4. Three competing hiring surfaces

(a) Talent Spotter (the intended hiring dashboard), (b) an internal Opus job pipeline (`AdminJobPipeline` + applicants), (c) Opus `emit-job-request` routing client job requests back to the **sales portal**. Source of truth is undefined; the client's recruitment-status link 404s. Pick one owner (Talent Spotter), demote the others to views.

### 5. The CRM of record is actually Lark

The repos notify Lark groups at every step (new quote, brief, proposal created, EOD cards), and the operative client base lives in the "CO Sales and Client Base" Lark Base -- outside all six repos. The sales portal's CRM is a workflow tool, not the system of record. Owner's stated direction: move toward a repo-hosted CRM (engage-crm style). Until then, every "is the data in the CRM?" question has two answers.

### 6. Documentation cannot be trusted

Not one Supabase project ID in the ecosystem PRD matches the code (Opus, HourHive, Sales Portal, Talent Spotter all differ; Refresh Glow is listed as "static site -- no Supabase" while hosting the CD hub). The Talent Spotter PRD is a 64-line stub whose non-goals ("not an ATS", "no job board") describe the opposite of what was built and of what the owner wants it to be. The ecosystem PRD's client lifecycle has **no hiring step at all** (payment -> "admin assigns VA" -- a bench model, while the business runs hire-to-order). The PRDs are not guiding development; they are trailing it badly.

---

## Ecosystem scorecard

| App | Role | Built | Biggest blocker | Ready? |
|---|---|---|---|---|
| Sales Portal | Sales dashboard / front door | High -- CRM, proposals, Stripe, both handoffs | Anon-readable proposals; self-serve admin escalation; unauthenticated intake/brief endpoints | NO -- fix 4 security criticals first |
| Tavus Talent Spotter | Hiring dashboard | High -- effectively a full ATS with client+salesperson portals | Unscoped salesperson tokens (cross-tenant leak); brief->job manual re-keying; own auth | NO -- scoping + brief->job first |
| Catalyst Opus | Client workspace + SSO authority | Very high -- likely overbuilt | Invite-token role escalation; unauthenticated Tracker bridge; broken credential-share crypto; client UX overload | NO -- security + client-surface slimming |
| HourHive Buddy | Time tracker / payroll | Very high -- real payroll, desktop agent, client feeds | `sso-data-access` trusts caller-asserted role (all-tenant read/write); dead RLS | NO -- worst single vuln in the ecosystem |
| Catalyst Refresh Glow | Marketing site (actually: CD hub) | High -- plus an undocumented auth/affiliate/commerce hub | Leaky funnel (4 of 5 form types never reach CRM); secret in bundle; hub coupled to public site | PARTIAL -- funnel fixes are quick wins |

---

## Prioritized roadmap

### P0 -- Security criticals (do before anything else; ~days, not weeks)

1. HourHive `sso-data-access`: validate the SSO token server-side (pattern already exists in `timer-session`), derive role/email from it, reject body-asserted identity. Update Opus `tracker-api.ts` to send the token.
2. Sales Portal: fix `profiles` UPDATE policy (WITH CHECK, no role column self-write; make `user_roles`+`has_role()` the single authority); drop every `USING (true)` policy on `proposals`, `va_alignment_submissions`, `app_settings`, etc.; add secret checks to `receive-quote`, `send-va-alignment`, `get-va-alignment`; add idempotency to `checkout.session.completed` (stop password resets on redelivery).
3. Opus: fix invite-token RLS (`USING (true)` -> token-holder-only lookup via RPC) and `apply_public_invite_role` escalation; remove `credentials.txt` from the repo and rotate those accounts; tighten the OAuth wildcard redirect.
4. Talent Spotter: add `salesperson_id` scoping to `salesperson_access_tokens` + filter the portal query; verify Tavus webhook signatures; require a valid access token on `tavus-interview-v2`.
5. Refresh Glow: rotate + server-side the hardcoded affiliate webhook secret.

### P1 -- Make the target flow actually flow (the system-integrator work)

6. **Brief -> draft job:** on `receive-new-client`, auto-create a draft `jobs` row prefilled from the brief, linked via `notification_id`. One recruiter click to publish. This unlocks the whole progress-notification chain for free.
7. **Event-driven brief timing:** trigger the brief flow on proposal signature/payment (salesperson-authored per the intended flow), with a post-payment nudge if missing; add save-draft.
8. **Delivery ledger / outbox:** one `handoff_events` table per sender + a retry loop + an admin "Integration Health" panel (last success, failed handoffs, replay button). Turns silent data loss into a visible queue.
9. **Fix the funnel:** route ALL marketing-site forms (contact, consultation, booking, industry) into the sales portal CRM; capture UTMs at the door and carry them through; decide GHL-or-CRM for the financial-advisors LP.
10. **Fix the 404:** Opus `receive-recruiter-update` deep-link `/job-requests` -> `/client/jobs`; unify hiring status into one client-visible surface.
11. **One identity:** make HourHive's PKCE redirect the only login path (delete the password proxy); migrate Talent Spotter onto Opus SSO; document the CD hub or split it out of the marketing site.

### P2 -- Product/UX polish for clients

12. Slim the Opus client surface: a client-mode sidebar of ~6 items (Dashboard, My VA, Chat, Tasks, Hours & Billing, Help); collapse the four document systems into one.
13. Build the missing "Prep for your VA" experience: hire-event-triggered checklist (brief your VA, share credentials via vault, set first-week routines, book kickoff call) replacing the generic academy as the onboarding spine.
14. Lead lifecycle stages (contacted/negotiation/won/lost) + a real funnel report in the sales portal.
15. HourHive: fix overnight manual segments; snapshot payroll at approval; currency by VA; unstick the desktop-agent update manifest (v0.6.7 -> v1.1.5).
16. Talent Spotter: fix the `/candidate` stub landing; scoring timeout/fallback; token self-renew for clients.

### P3 -- Strategic decisions (owner calls)

17. **CRM of record:** commit to moving the Lark "CO Sales and Client Base" into a repo-hosted CRM (engage-crm-style or the sales portal itself). Two sources of truth is the root cause of half the sync complexity.
18. **One hiring surface:** Talent Spotter owns hiring; Opus renders read-only status; the internal Opus pipeline and sales-portal job routing become views/events, not stores.
19. **Split the CD hub** out of the marketing site (or formally rename the app and PRD to what it actually is).
20. **Rewrite the PRDs from code** (project IDs, actual architecture, the hire-to-order lifecycle with stages 2-5 above) so the docs lead instead of trail.

---

## Bottom line

Nothing here needs to be rebuilt; nearly everything needs to be **finished and locked down**. The team has already built 70% of the owner's ideal flow -- including pieces the PRDs don't know about. The three moves that change everything: (1) one week of ruthless P0 security fixes across the five seams, (2) the brief->draft-job automation plus a delivery ledger so handoffs are visible and retryable, and (3) one identity + one hiring surface + one CRM of record so the ecosystem stops competing with itself.
