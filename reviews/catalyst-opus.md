# Catalyst Opus -- Critical Product Review

**App role:** Client workspace / dashboard + ecosystem SSO authority
**Reviewed against:** origin/main (fresh clone), PRD.md, HOURHIVE-INTEGRATION.md, ECOSYSTEM-PRD.md
**Date:** 2026-07-09 · **Update:** 2026-07-11 (see addendum below)

---

## 2026-07-11 addendum -- what changed since this review

**Fixed and verified (live QA as client + VA + admin, DB-checked):**

- **Bug #1 (CRITICAL, invite-token role escalation): FIXED** -- #36 replaced the `USING (true)` policies with token-scoped RPCs; policies dropped, edge fn redeployed (2026-07-10).
- **Bug #5 (credentials in git): FIXED** -- `credentials.txt` removed, all 3 accounts rotated; test-account convention now gitignored `test-accounts.local.md` + docs/TESTING.md.
- **Bug #7 (btoa "hash"): FIXED** -- #43 re-hashed legacy link passwords to bcrypt across 8 `*_links` tables.
- **Bug #8 (routine ticks untrustworthy): FIXED** -- #39/#40 RLS: clients are view-only on VA routines, can tick only their own unassigned ones; UI matches (A4).
- **NEW root-cause found + fixed -- #45 self-tenant backfill:** clients created without `role:'client'` metadata had no `tenant_members` self-tenant, so `orgRole` was null and **every** client area silently bounced to the dashboard. Idempotent backfill applied (71 tenants healed); all client areas verified loading.
- **UX #1/#3 (client sees an admin console): LARGELY FIXED** -- comms-first slim client sidebar (Messages leads; Task Inbox/Directory/Wiki cut); dashboard-first landing.
- **UX #7 (generic academy): REPLACED** -- "Success Academy" is now the CO Academy: 17 client + 8 VA (mirror-track) units where each unit **builds a real workspace object** -- inline task assign, real docs (`rich_documents`), a real SOP with ordered steps (`sops`+`sop_steps`) chaining into the routine builder, the Handoff Map worksheet converting straight into assigned tasks, simplified routine dialog, deep-links into every referenced app surface, artifact auto-verification, celebrations, Singapore-first copy, lesson/quiz/apply step pages, mobile-first layout (horizontal unit strip, resume-exactly-where-you-left-off), reviewer preview allowlist.
- **/blockers** is now a live in-app page (+ docs/BLOCKERS.md twin + CLAUDE.md upkeep rule), designed so Lovable can be told "fix all /blockers" for migration items.

**Still open (unchanged from this review):**

- **Bug #2** Tracker `sso-data-access` caller-asserted role -- stage-1 token validation deployed on the Tracker side; stage-2 migration of ~78 caller sites + strict mode still pending (tracked in hourhive-buddy /admin/blockers).
- **Bug #3** credential-share key exchange still symmetric (works only when both parties share a password).
- **Bug #6** OAuth wildcard redirect for first-party `*.lovable.app` clients.
- **Bug #9** `spreadsheet_shares` still unread by the VA documents view.
- **Challenged decision #2** three competing hiring surfaces -- unchanged.
- **Prod retest owed:** academy task-assign silently failed once on the pre-wave prod bundle; retest after the next Lovable publish (all of the above is on main, prod publish pending).

---

## Ecosystem handoffs

| Handoff | Status | Evidence | Notes |
|---|---|---|---|
| Sales portal -> Opus client intake | EXISTS | `supabase/functions/receive-client-account/index.ts:33-42` (validates `x-webhook-secret` = `SALES_PORTAL_WEBHOOK_SECRET`, 401 on mismatch), creates auth user + `profiles` + `client` role + `tenant`/`tenant_members` (93-227). Supports pre-payment "preview" status (62-75). | Authenticated via shared secret. Won't overwrite an existing user's password (107-119). |
| Recruiter/hiring status -> client visibility | PARTIAL (broken deep-link) | `receive-recruiter-update/index.ts:100-107` writes a `recruitment_update` notification + `recruitment_pipeline_stage` to `client_onboarding`. | Notification `p_link: '/job-requests'` (106) points to a route that does NOT exist -- App.tsx only defines `/client/jobs` (`src/App.tsx:189`). Client clicks the update -> 404. |
| Tavus talent-spotter -> VA provisioned into Opus | EXISTS | `supabase/functions/provision-hire/index.ts` receives `tavus_application_id`, creates `va_assignments`, `employee_profiles.position` from Tavus job title (507-517), emails VA portal access (602-608), pushes rate to Tracker (536-540). Secret-gated (`RECRUITER_SYNC_SECRET`, 178). | Real recruitment intake. Coexists with an internal Opus job pipeline -- duplication. |
| "Prep for your VA" pre-arrival onboarding | PARTIAL | `src/components/onboarding/` (OnboardingWizard, OnboardingChecklist, WelcomeModal); `src/pages/ClientAcademy.tsx` -> Infinity modules 1-6 (`src/components/academy/AcademyView.tsx:4,33`). | Onboarding = generic product tour + standalone "Success Academy" course library. No bespoke "your VA is arriving, here's how to brief them" flow tied to the hire event. |
| HourHive time visibility inside Opus | EXISTS (insecure bridge) | `src/lib/tracker-api.ts:10,36-40` POSTs to Tracker `sso-data-access`; `src/hooks/useClientVAs.ts:102-108` calls `get-va-hours-summary` -> client sees `hours_this_month` per VA without leaving Opus. | Client does NOT need to switch apps for hours. But auth is caller-asserted (see Bug #2). |
| OAuth 2.0 PKCE SSO authority | EXISTS | `supabase/functions/oauth-server/index.ts` (1,915 lines); `oauth_clients` table. HourHive registered `client_id=d2eb9a26...`, first-party/confidential/web. Tokens SHA-256-hashed, refresh rotation. | HourHive is the ONLY registered external consumer. Redirect validation has a wildcard hole (Bug #6). |
| Sales portal <- Opus (job request emit) | EXISTS | `emit-job-request/index.ts:9,132` forwards to sales portal `receive-job-request`; `sync-client-to-sales/index.ts:8`, `sync-client-to-hiring/index.ts:8`. | A client "Job Request" in Opus routes back to the SALES PORTAL, not directly to talent-spotter -- a third hiring surface. |

## Top bugs & edge cases

1. **CRITICAL -- World-readable invite tokens -> role escalation.** `migrations/20260226120000_add_public_invite_links.sql:29-32` and `migrations/20251215155026_...sql:33-36` use `CREATE POLICY ... FOR SELECT USING (true)` on tables storing `token` + `role` + invitee `email`. Anon callers can dump every active token and the role it grants; combined with SECURITY DEFINER `apply_public_invite_role` (53-94: `INSERT INTO user_roles ... ON CONFLICT DO UPDATE SET role = v_link.role`) any authenticated user can overwrite their own role from a leaked token. Admin-takeover if any elevated link is active.
2. **HIGH -- Cross-app data bridge is unauthenticated.** `src/lib/tracker-api.ts:36-40` POSTs `{action, email, role}` to the Tracker's `sso-data-access` with NO bearer token or secret; the browser supplies the role (`useClientVAs.ts:105` sends `"client"`, `provision-hire/index.ts:539` sends `"admin"`). A user can edit the body to any email + `role:"admin"` and the Tracker trusts it. Contradicts the OAuth story the PRD sells.
3. **HIGH -- Credential-share crypto is broken by design.** `CredentialSharingDialog.tsx:187-188` encrypts the per-(client,VA) share key with the CLIENT's master password, but `VAPasswordVault.tsx:215-220` decrypts with the VA's master password. No asymmetric key exchange. In production (different passwords) sharing silently fails; it only "works" because seeded test accounts share `helloworld`. Vault-at-rest crypto (`src/lib/crypto.ts`, AES-GCM-256 + PBKDF2 100k) is fine.
4. **HIGH -- Invitee email/PII enumeration.** Same `USING (true)` on `user_invitations` (`migrations/20251215155026_...sql:33`) exposes every pending invitee's email + role to anon.
5. **MEDIUM -- Live credentials committed to git.** `credentials.txt` (repo root) has real Gmail addresses for admin/client/VA and "all password: helloworld" against the live project. `.env` is tracked (anon key only -- public/acceptable, but service-role key must never join it).
6. **MEDIUM -- OAuth redirect wildcard for first-party clients.** `oauth-server/index.ts:170-179` accepts ANY `*.lovable.app`/`*.lovableproject.com` subdomain with a matching callback path -> authorization-code interception (PKCE mitigates but doesn't eliminate for auto-approved first-party flows). Violates PRD SSO-04.
7. **MEDIUM -- Reversible "hash" for legacy share-link passwords.** `verify-link-password/index.ts:131-134` and `public-document-url/index.ts:84-86` treat legacy `password_hash` as `btoa(password)` (base64 = plaintext). Dormant links never upgrade to bcrypt until next verify.
8. **MEDIUM -- Routine "done" is untrustworthy.** Anyone (client or VA) can tick a routine checkbox and `completed_by` is never rendered; the daily routine digest is dead (`send-routine-digest` reads phantom rows).
9. **MEDIUM -- Shared trackers never reach the VA.** `useVADocumentsData.ts` reads document/rich_document shares but not `spreadsheet_shares`; client shares a tracker, gets a success toast, VA sees nothing.
10. **LOW (known, OPEN in BLOCKERS.md) -- `/va/people` shows 4 of 7 profiles as "Unknown"** (missing `profiles` rows for agent-provisioned VAs); Monching rate junk `$4-$800/hr` re-pollutes Tracker on resync.

## UX friction

1. **The client sees an admin/VA tool.** 119 routes in `src/App.tsx`; client sidebar seeds ~18 items across 7 groups. For someone whose job is "delegate to one VA," this is overwhelming.
2. **Four overlapping "document" homes** -- Wiki vs Files vs Academy Library vs SOP vs Knowledge all hold documents. Users can't predict where they saved something.
3. New-client first screen was empty Messages (fixed to Dashboard via `ClientIndexGate`), but the landing is still a dense product, not an orientation.
4. **"Task Inbox" reads as a second task list** but is a notification feed; badge counts every comment, so "done" drowns.
5. **Org sub-account roles bounce on their own nav.** `RouteAreaGuard.tsx:33-39` vs `permissions.ts:119-172` mismatch -- finance/hr/viewer/team_lead click a visible sidebar item and get a toast + redirect.
6. Help Center is undiscoverable -- removed from the sidebar, only reachable via a floating button.
7. Success Academy is generic "Infinity" course content, not a pre-VA prep experience.
8. Broken template->routine->task connectors -- Library copies land unsorted at Files root; a tracker can't be attached to the routine/task it fills.

## Challenged design decisions

1. **Opus is overbuilt as a monolith** -- chat, WebRTC calls, Kanban, wiki, rich-doc/spreadsheet/flowchart editors, academy, vault, invoicing, polls, AND a job ATS -- all shown to a client who mainly needs to brief and monitor one VA.
2. **Three competing hiring surfaces:** internal Opus job pipeline (`AdminJobPipeline`), outbound emit to the sales portal (`emit-job-request`), and inbound provisioning from Tavus (`provision-hire`). Source of truth unclear; client-facing recruitment-status deep-link is broken.
3. **"Encryption" that isn't.** Locked notes are a client-side SHA-256 privacy screen the owner's API session can still read; the vault-share key handoff doesn't perform an asymmetric exchange. Security marketing outruns implementation.
4. **Cross-app trust by caller-asserted email+role** (`tracker-api.ts`) directly contradicts the OAuth-PKCE authority the same app hosts.
5. **Sidebar nav stored in DB, not code** -> recurring "seed the sidebar" blockers; features reachable only by URL until a DB seed lands.

## PRD vs reality gaps

- **Credential sharing "without exposing plaintext":** at-rest crypto is real, but the share key exchange is broken -- the guarantee isn't met in production.
- **SSO-04 "client can only redirect to its registered URIs":** reality allows any `*.lovable.app` subdomain for first-party clients.
- **Out-of-scope "No third-party calendar sync":** contradicted -- `GOOGLE_CALENDAR_SYNC.md`, `GOOGLE_CALENDAR_SETUP.md`, and `supabase/functions/google-calendar/` exist.
- **ECOSYSTEM-PRD project IDs are wrong:** Opus listed as `gouyeamixsggwkwdotku` but `.env` is `qouycamixsggwkwdotku`; HourHive listed as `sxhtuparcfyldbcymxz` but code calls `swbupqrcrfgldibcynnz`.
- **HOURHIVE-INTEGRATION.md documents HourHive pulling FROM Opus via OAuth;** the feature that renders client hours goes the OPPOSITE direction (Opus pulling FROM Tracker via unauthenticated `sso-data-access`).

## Verdict

The ecosystem seams genuinely exist and mostly work: authenticated sales->Opus intake, Tavus->Opus hire provisioning, a substantial OAuth/PKCE authority with HourHive registered, and in-app visibility of VA hours. But the app is overbuilt as an admin/VA console that the client is also dropped into (119 routes, 18-item client sidebar, four overlapping document systems, no bespoke "prep for your VA" flow), and it carries serious security holes: world-readable invite tokens enabling role escalation, an unauthenticated caller-asserts-its-own-role cross-app bridge, a credential-share scheme that only works because test accounts share one password, and live credentials committed to git. Not ready as the trusted client workspace until the invite-token RLS, the Tracker bridge auth, and the credential-share key exchange are fixed and the client surface is deliberately slimmed.
