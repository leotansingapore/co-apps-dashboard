# HourHive Buddy -- Critical Product Review

**App role:** Time tracker (EOD reports, screenshots, payroll, productivity analytics); ecosystem SSO consumer
**Reviewed against:** origin/main (fresh clone), PRD.md, ECOSYSTEM-PRD.md
**Date:** 2026-07-09

---

## Ecosystem handoffs

| Handoff | Status | Evidence | Notes |
|---|---|---|---|
| SSO login via catalyst-opus OAuth PKCE | PARTIAL | `src/lib/auth/sso-config.ts:13-21` (real PKCE endpoints, S256 in `auth-proxy/index.ts:114-125`); `Login.tsx:204` `ssoLogin()` triggers the real redirect | PKCE flow is genuine, but NOT the default path (see next row). |
| "No local login screen" (PRD) | CONTRADICTED | `src/pages/Login.tsx:149-210` renders a full email/password form + Google button as the default; `handleLogin` POSTs raw credentials to `auth-proxy` (94-104), which does `grant_type=password` against Catalyst's Supabase (`auth-proxy/index.ts:80-105`) | Collects the user's Catalyst password on its own domain (phishing-shaped anti-pattern) instead of redirecting to Opus consent. The pure-PKCE redirect is buried behind "Forgot your password?". |
| Auto-provision via sso-user-sync | EXISTS | `sso-user-sync/index.ts:112-600` upserts `clients`/`profiles`/`va_details`, resolves pending assignments (307-318), pulls `/v1/me` (439-505) | Solid. Best-effort (failures swallowed, `Login.tsx:113`). |
| Assignments/clients sync from Opus (`sso-data-access`) | EXISTS (real) | `sso-user-sync` calls `SSO_API_GATEWAY/v1/assignments` (144,323) and reconciles terminations (245-273, 409-431); `sso-data-access` is 192 actions/17.7k LOC | Real bidirectional sync of assignments, clients, VA rates, caps. Not aspirational. |
| Routine write-back HourHive->Opus | EXISTS | Routines threaded into Lark EOD cards with `work.catalystoutsourcing.com/go?routine=` links (`sso-data-access/index.ts:3631-3638`); timer-session calls CD api-gateway (4417-4465) | Read + link-back present. |
| Client can see VA hours/EOD/screenshots | EXISTS | `ClientReports.tsx` (54KB), `useClientScreenshotFeed.ts:22` action `get-client-screenshot-feed` with `role:'client'`; signed URLs minted server-side (`sso-data-access:11552`) | Client visibility is real -- good for the ecosystem flow. |
| Payroll computation | EXISTS (real) | `usePayrollData.ts:210-290` per-client rates, fixed/hourly mix, proration, OT, daily caps, separate billing vs pay rate; `payroll_records` table with `status CHECK (draft/approved/paid)`, adjustments, `final_amount` | Genuinely computed. Currency hardcoded S$ though (see gaps). |
| Audit trail | EXISTS | `audit_events` table + `logAuditEvent` in `sso-user-sync:30-55` and `sso-data-access`; VA-invoice dispute workflow (`InvoiceReceiver.tsx:153-167`) | Present and used across mutations. |
| Desktop agent | PARTIAL (working prototype, active) | Full Python app at `desktop-agent/src/main.py`, sync/backup/offline-queue/idle/power-events/multi-monitor modules, ~30 pytest files; release notes through v1.1.5 | But `desktop-agent/latest.json` still points to v0.6.7 -- auto-update manifest is stale vs newest release. |

## Top bugs & edge cases

1. **CRITICAL -- Authorization bypass in `sso-data-access` (the primary data gateway).** `verify_jwt = false` (`config.toml`) and it trusts the `role` and `email` fields from the REQUEST BODY with no token validation (`index.ts:3515`; only `Authorization` read is one service-key check at 9978). Admin gating is `if (role !== 'admin')` where role is client-supplied (4967, 10113); every query runs with the service role key (3564). The frontend passes role straight from client state (`useClientScreenshotFeed.ts:24`). Anyone with the public anon key can `POST {action:'get-all-reports', role:'admin', email:'x'}` and read/write ALL tenants' reports, payroll, invoices, and signed screenshot URLs.
2. **CRITICAL -- RLS policies are dead code on the app's real path.** The local Supabase client uses the anon key and never establishes an authenticated session (`integrations/supabase/client.ts:11`); SSO tokens come from the Catalyst project, so `auth.uid()` is always null locally. Every `timer_screenshots`/`daily_reports` RLS policy keys on `auth.uid()` (`migration ...4044f8e7:54-69`) and never grants. RLS provides ZERO real isolation; #1 is the only gate. (`timer-session` DOES validate tokens at 452-491, so the insecure pattern is `sso-data-access`-specific and fixable.)
3. **HIGH -- No server-side overlap enforcement on time segments.** `findOverlap` exists only client-side (`src/lib/segment-validation.ts:23-40`). Combined with #1, overlapping/duplicate billable segments can be injected directly, inflating payroll and client invoices.
4. **HIGH -- Overnight-segment math inconsistent client vs server.** Server wraps midnight correctly (`timer-session:2225`). The manual EOD editor's `calculateHours` returns null whenever `endMin <= startMin` (`segment-validation.ts:19`), so a PH VA on a night shift covering a US client cannot manually enter a 22:00-02:00 span. Timezone data-entry failure for exactly the ecosystem's core use case.
5. **HIGH -- Admin productivity RPC 500s on any window >~2 weeks** and the error is swallowed (`catch {}`), so admins silently see N/A metrics (`docs/BLOCKERS.md:13-37`, `get_activity_metrics_for_admin` materializes ~634k rows past the 1000-row cap). Still open.
6. **MED -- Corrupt/inverted VA rates propagate from Opus** (`BLOCKERS.md:59-75`: $800/hr vs $0.01). Sync is upsert-only so a dirty source re-pollutes on every push. No rate-sanity validation at sync time.
7. **MED -- AI work-summary window off-by-one** (7-day window spans 8 dates) -- inclusive-both-ends bounds (`BLOCKERS.md:79-95`). Skews client-facing productivity summaries.
8. **MED -- `auth-proxy` password path is a credential-relay** (`auth-proxy:80-105`). HourHive sees and can log plaintext Catalyst passwords; compromise of this one edge function harvests credentials for the whole ecosystem.
9. **LOW -- Assignment reconciliation can mass-terminate on a partial SSO response.** If `/v1/assignments` returns OK but truncated/empty, the reconciler marks every local assignment not in the response as `terminated` (`sso-user-sync:245-273`) with no "empty response" guard.
10. **LOW -- Screenshot retention undefined.** `timer_screenshots` has no TTL/cleanup migration; storage and privacy liability grow unbounded.

## UX friction

1. Login defaults to typing Catalyst credentials INTO HourHive rather than an SSO "Continue with Catalyst" button -- confusing and trains users to enter SSO creds on satellite domains.
2. "Forgot your password?" doesn't reset a password -- it silently triggers the SSO redirect (`Login.tsx:204-208`). Mislabeled control.
3. Night-shift VAs can't hand-enter an overnight EOD segment (bug #4).
4. Admin productivity dashboards show N/A for any range beyond ~2 weeks with no error surfaced (bug #5).
5. `SubmitReport.tsx` is 130KB -- an enormous single EOD form on the VA's daily 5-minute path (the PRD's flagship <5-min metric).
6. Timezone ambiguity: report "date" is the VA's local day; clients elsewhere may see a report dated a day off, no tz indicator.
7. Desktop-agent auto-update points at v0.6.7 while releases are at v1.1.5 -- VAs won't receive current fixes.
8. Payroll/invoice amounts render as `S$` regardless of the VA's actual payout currency (`payroll-utils.ts:17,39-41`).

## Challenged design decisions

1. **`verify_jwt=false` + body-asserted role across 192 actions.** Not a patch-per-action gap; a broken trust model. The gateway must validate the SSO token (as `timer-session` already does) and derive role/email from the verified token, never the body.
2. **Password-grant proxy instead of pure PKCE redirect.** Defeats the security rationale of SSO and contradicts the PRD. The PKCE redirect already works -- make it the only path.
3. **RLS written but structurally unreachable.** 70+ tables of `auth.uid()` policies that never evaluate create a false sense of security. Either authenticate the local session so RLS is live, or document that edge functions are the sole gate.
4. **Payroll computed live in the browser from `daily_reports`** (`usePayrollData.ts:146-290`) rather than immutable snapshots. Historical payroll shifts if an old report/segment is edited -- weak guarantee for something that must "100% match" invoiced hours.
5. **Upsert-only sync with no source validation.** One bad row upstream silently corrupts payroll; partial reads can mass-terminate. Needs sanity gates and an "empty/partial response => do not reconcile" guard.

## PRD vs reality gaps

- **"No local login screen":** false -- a full credential form is the default. Only "Forgot password" uses the redirect.
- **"SSO integration: Done":** token plumbing is done, but the auth MODEL is insecure (bugs #1/#2), so "Done" overstates readiness.
- **"Desktop agent auto-update: In Progress":** accurate -- `latest.json` (v0.6.7) lags releases (v1.1.5).
- **Timezone & VA-edit-reports open questions:** still unresolved -- overnight entry is broken (#4) and segment edits mutate live payroll.
- **Screenshot retention:** no retention policy/cleanup exists (#10).
- **Payroll "<1 hour" & 100% accuracy:** undermined by live recomputation and no server-side overlap guard.
- **Multi-currency:** implied by `fetch-fx-rates` + `src/lib/currency/`, but payroll export hardcodes S$ -- partial.

## Verdict

The feature surface is genuinely built and deep -- real payroll math, working assignment/client sync from Opus, client visibility into EOD/screenshots, an audit trail, and a substantial well-tested desktop agent -- so functionally it is far past prototype. But it is NOT ready to be the ecosystem's system of record for payroll and surveillance screenshots because its primary data gateway (`sso-data-access`, 192 actions) runs on the service-role key with `verify_jwt=false` and trusts a client-supplied `role`/`email`, making admin/client/VA isolation trivially bypassable while the RLS that would defend the data never evaluates. Fix the auth model first (validate the SSO token server-side and derive role from it, as `timer-session` already does) and switch login to the real PKCE redirect; until then, treat every "Done" auth/isolation claim as unproven.
