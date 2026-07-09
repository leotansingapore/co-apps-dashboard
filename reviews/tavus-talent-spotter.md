# Tavus Talent Spotter -- Critical Product Review

**App role:** Recruitment / hiring portal (candidate intake, Tavus AI video screening, hiring pipeline for recruiters + clients + salespeople)
**Reviewed against:** origin/main (fresh clone), PRD.md, ECOSYSTEM-PRD.md
**Date:** 2026-07-09

> **Flag for owner:** Supabase project `nkvmvtndwgmkwcabqojb` is the SAME ref the ECOSYSTEM-PRD attributes to the Sales Portal (PRD line 139). Either the PRD table is wrong or these two apps share a database, which contradicts the "no shared DB" principle. Confirm.

---

## Ecosystem handoffs

| Handoff | Status | Evidence | Notes |
|---|---|---|---|
| Job intake from Sales Portal | PARTIAL | `receive-new-client/index.ts:8-182` (HMAC via `x-sync-secret`, 29) writes only into `new_client_notifications`, never creates a `jobs` row. Job creation is a separate manual step: `JobsSection.tsx:616` | The sales handoff lands as a "New Clients" notification, not a job. A recruiter reads it and re-types a job by hand. No automation, no prefill. |
| Talent alignment brief | EXISTS (data) / WEAK (UX) | Brief fields ingested in `receive-new-client/index.ts:71-152` (`business_description`, `success_vision`, `support_types`, `required_skills`, `non_negotiables`, `talent_alignment`). Rendered read-only in `NewClientsSection.tsx:993-1062` | Concept is real and richly modeled. But there is NO "convert brief -> job" button anywhere; `JobsSection.tsx:616` insert has no `notification_id`/`talent_alignment`/prefill. Brief and job are disconnected records. |
| Salesperson visibility of progress | EXISTS but BROKEN SCOPING | `fetch-salesperson-portal-data/index.ts:66-84` fetches ALL jobs with comment "get all jobs for now (can be filtered by salesperson later)". `salesperson_access_tokens` (`migrations/20260103112042...sql:2-17`) has NO salesperson_id/job scope column | Any single salesperson portal link exposes every client's jobs, candidates, AI scores, transcripts, insights and red flags across the whole platform (97-180). Cross-tenant leak. See Bug #2. |
| Client visibility of progress | EXISTS | `fetch-client-portal-data/index.ts:51-65` scopes strictly by `tokenData.client_id`; `ClientPortal.tsx`, `ClientShortlist.tsx`. Authenticated client role also supported (`ClientDashboard.tsx:107-118`) | Correctly scoped, unlike the salesperson path. |
| Interview coordination / scheduling | EXISTS | `schedule-client-interview/index.ts` (client books via token, validates ownership 79-85, writes `interview_schedules`, calendar email 184-201); `send-interview-email`, `send-interview-reminders` present | Client-facing booking works. No native calendar/timezone picker beyond a `scheduledAt` timestamp + optional `meetingLink`. |
| Hired-candidate handoff -> catalyst-opus | EXISTS | `emit-hire/index.ts:135-195` POSTs `hire.completed` to `${OPUS_SUPABASE_URL}/functions/v1/provision-hire` with `x-sync-secret`. Auto-fired by DB trigger `migrations/20260616154224...sql` on `applications.status -> 'hired'`. Callers at `KanbanBoard.tsx:608`, `CandidatesSection.tsx:790`, `MyOffers.tsx:194` | Well-built with fallbacks (92-131). No-ops if Opus env unset (138-144). Depends on secrets configured in prod. |
| Pipeline progress back to Sales/Opus | PARTIAL | `notify-client-status/index.ts:96-151` pushes stage updates to Opus `receive-recruiter-update` using `proposal_id` from `new_client_notifications`. Requires `job.notification_id` | `jobs.notification_id` is NEVER written by any code path (grep: only reads). So for manually-created jobs it stays null and these progress pushes silently do nothing. |
| SSO via catalyst-opus | MISSING (own auth + bridge to a different app) | Own Supabase Auth + login (`src/pages/Auth.tsx`, `signInWithPassword` 144, Google OAuth 182, signup 200). `auth-proxy/index.ts` bridges to CD_SUPABASE (Refresh Glow / "Catalyst Dashboard"), NOT Opus's OAuth PKCE authority | Directly contradicts ECOSYSTEM-PRD 5.2 ("No app has its own login screen"; Opus is SSO authority). A full parallel auth system. |

## Top bugs & edge cases

1. **HIGH -- Tavus webhook is unauthenticated and forgeable.** `tavus-webhook/index.ts` has `verify_jwt=false` (`config.toml`) and zero signature/HMAC verification. Any POST with a known/guessed `conversation_id` can flip interview status, inject a fake `full_transcript`/perception (42-127), and trigger scoring -- poisoning candidate rankings recruiters rely on.
2. **HIGH -- Salesperson portal leaks all clients' candidate data.** `fetch-salesperson-portal-data/index.ts:66-180` uses the service-role key and returns every job + every application's PII, AI scores, transcripts, `red_flags`, `flagged_issues` for anyone holding ANY valid, non-scoped salesperson token.
3. **HIGH -- AI interview creation has no auth gate -> Tavus cost-abuse.** `tavus-interview-v2/index.ts:55-56`: `accessToken` is optional; when omitted, `validatedApplicationId = applicationId` straight from the request body. With `verify_jwt=false` and CORS `*`, anyone can POST `{action:'start-interview', applicationId}` to spin up real Tavus conversations for arbitrary IDs, burning paid credits.
4. **MEDIUM -- Scoring race / partial-data scoring.** `tavus-webhook/index.ts:289` only scores when `transcript_ready && perception_ready`. If Tavus never emits `perception_analysis`, scoring never fires and the candidate is stuck "interview complete, no score" with no timeout/fallback. A forged single event (Bug #1) can force scoring on empty data.
5. **MEDIUM/PII -- Public S3 recording URLs assume a public bucket.** `tavus-webhook/index.ts:165-168` stores `https://${bucket}.s3.${region}.amazonaws.com/${s3Key}` as `recording_mode:'s3'`. A signing function exists (`get-recording-url`), but the raw stored URL only works if the bucket is public (interview videos world-readable) or playback 403s if private.
6. **MEDIUM -- `emit-hire` fires on any hired transition, no idempotency key.** Trigger fires on every `status->'hired'`. hired->other->hired calls `provision-hire` again with no dedupe token. Risk of duplicate VA provisioning.
7. **MEDIUM -- DB trigger depends on `app.settings.service_role_key` GUC.** `fire_emit_hire()` reads `current_setting('app.settings.service_role_key', true)` and calls emit-hire with `Bearer ''` if unset. Later migration wraps in `EXCEPTION WHEN OTHERS THEN NULL`, so failures are swallowed -- hires may never reach Opus with no error surfaced.
8. **LOW/MED -- Interview access token reuse not blocked.** `tavus-interview-v2/index.ts:79-85` sets `used_at` only if not already set, but never rejects an already-used token. A single link can be replayed until `expires_at`.
9. **LOW -- Pipeline notifications dead for hand-typed jobs.** Because `jobs.notification_id` is never populated, `notifyPipelineStage(...job.notification_id...)` and `notify-client-status` no-op for the majority of jobs.
10. **LOW -- Anon can read pending invitations by token.** `Auth.tsx:66-72` queries `user_invitations` directly from the browser (anon) filtered by token; invitation email+role readable by anyone with a token guess. No rate limiting.

## UX friction

1. **Manual re-keying of the brief into a job.** Recruiter reads a fully-structured brief (`NewClientsSection.tsx:993-1062`) then opens a blank Create Job form (`JobsSection.tsx:1229`) and retypes it. The single highest-value automation in the whole ecosystem is missing.
2. No job <-> brief <-> client linkage after creation -- recruiters can't trace a job back to which proposal/brief spawned it; progress-to-sales notifications silently die.
3. Candidate dead-end after interview with no score (Bug #4) -- perpetually "Pending" with no retry affordance.
4. **Two parallel candidate surfaces** -- `/candidate` (`CandidateDashboard.tsx` is a 202-byte stub) vs `/applicant` (`ApplicantDashboard.tsx`, 15KB). Default `candidate` role lands on the STUB (`Auth.tsx:132-134`).
5. Salesperson portal shows firehose, not "your positions."
6. Email delivery silently fails without config (`.env.example`: Resend fallback `onboarding@resend.dev` only delivers to the account owner).
7. Signup email-confirmation gap -- no resend-confirmation UI (`Auth.tsx:210-217`).
8. Client token expiry (30-day default) with no self-renew (`generate-client-access-token/index.ts:55`).

## Challenged design decisions

1. **Own auth instead of Opus SSO** -- ships a full login (password + Google), proxies to Refresh Glow's Supabase. Fragments identity and breaks E-01.
2. **Service-role edge functions as the tenant boundary** -- portal functions run as service-role and re-implement authz by hand per function. The salesperson one got it wrong (Bug #2). RLS would fail safe; hand-rolled service-role checks fail open.
3. **`verify_jwt=false` on a large surface** (~30 functions incl. `tavus-interview-v2`, `tavus-webhook`, `fetch-*-portal-data`). Every one must perfectly self-authorize -- several don't.
4. **Notification and Job as separate, unlinked entities.** Root cause of the re-keying friction and dead progress-notifications. A brief should instantiate a draft job.
5. **Scoring gated on two independent async webhooks with no timeout** -- makes the core deliverable (a ranked pipeline) fragile to Tavus event delivery.

## PRD vs reality gaps

- **App PRD "own Supabase instance, not shared":** project `nkvmvtndwgmkwcabqojb` is the ecosystem PRD's Sales Portal project. Shared-or-mislabeled.
- **App PRD "screening + triage, not an ATS":** reality is effectively a full ATS -- jobs, applications, offer letters, client/salesperson portals, kanban, email campaigns, talent-pool import, analytics.
- **Open Q "SSO via Opus or own auth?":** already answered "own auth + Refresh Glow bridge," diverging from ecosystem SSO.
- **Ecosystem ER-03 "payment -> recruiter notified in 5 min":** plumbed (`receive-new-client`), but the brief->job automation implied by "without re-entering data" is NOT delivered.
- **Open Q "GDPR for candidate videos":** `export-user-data` and `process-deletion-request` exist, but raw public-S3 URL storage (Bug #5) undercuts the retention story.

## Verdict

Not ready as the ecosystem's shared hiring dashboard yet. The bones are impressive -- client and salesperson portals, token scheduling, a robust `emit-hire -> catalyst-opus` handoff, and a real talent-alignment-brief data model all exist -- but three things block it: (1) the salesperson portal leaks every client's candidate data because tokens aren't scoped, and the Tavus webhook and interview-creation endpoints are unauthenticated (forgeable scores + credit abuse); (2) the sales->hiring handoff stops at a notification a recruiter must manually retype into an unlinked job, so the "no re-entering data" promise and progress-back-to-sales notifications silently fail; and (3) it runs its own auth (bridged to Refresh Glow, not Opus SSO), contradicting the ecosystem's single-identity design. Fix the salesperson scoping, add webhook/interview auth, and wire briefs into first-class draft jobs before positioning this as the recruiter+client+salesperson hub.
