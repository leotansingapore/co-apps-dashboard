# CO Apps — Blockers needing Leo

Last updated: 2026-07-11

Everything else from the ecosystem P0 wave + academy rebuild is committed and (per Leo) published. These are the items that need a human hand — mostly secrets and rotations I can't/shouldn't do myself.

## 1. Set 3 edge-function secrets (activates the fail-open security gates)
The receiver checks are deployed but **fail-open until the secret is set** — so they don't break live traffic, but they also don't enforce until you add the secret. Set each in the project's Supabase → Edge Functions → Secrets (or Lovable's secret UI):

| Secret | Projects | What it locks down |
|---|---|---|
| `RECEIVE_QUOTE_SECRET` | Sales Portal (`glowmruekgeygxplguew`) **and** Refresh Glow (`lybfxzttbikispdjjijc`) — **same value on both** | Stops forged anonymous leads / round-robin assignment-email spam into the sales CRM. The sender already sends the header; it activates the moment both sides have the value. |
| `TAVUS_WEBHOOK_SECRET` | Talent Spotter (`nkvmvtndwgmkwcabqojb`) | Stops forged Tavus webhooks from injecting fake interview transcripts/scores. tavus-interview-v2 registers the callback with this secret; the webhook enforces it once set. |

Use a long random string (e.g. `openssl rand -hex 24`). I attempted to set these via the Management API but the action was blocked pending your approval — happy to set them if you grant secret-store write access, otherwise it's a 2-minute manual step.

## 2. Rotate exposed credentials
- **Refresh Glow affiliate webhook secret** — the value `aff_whsec_7kX9mP2nQ4rT6vW8yB3cD5fH1jL0oS` was hardcoded in the shipped browser bundle (now flagged/being moved server-side). **Rotate it** in the external affiliate portal and update the env var.
- **Opus test accounts** — `credentials.txt` (removed from the repo, but it's in git history) exposed shared-password logins: admin `desiertomonchingb@gmail.com`, client `bluemonde1999@gmail.com`, VA `monchingdesierto49@gmail.com`. **Change those passwords.**

## 3. Confirm Lovable actually ran the pending SQL migrations
Publishing a Lovable app deploys the frontend but may not run `SUPABASE.md` pending items unless prompted. For each repo below, tell Lovable **"check pending tasks at SUPABASE.md and run the migrations"** (or confirm they already ran). The apps degrade gracefully if not (academy falls back to localStorage; the routine/completion gates are enforced client-side), but the DB backstops aren't live until these run:

| Repo | Pending migrations |
|---|---|
| catalyst-opus | ~~#36–#45 all ran~~ ✅ (verified 2026-07-11 — invite-token RLS, notifications, academy tables, routine RLS, redeploys, btoa re-hash, demo confirms, self-tenant backfill). Remaining: **#46** demo-admin login 500 repair + demo-client role fix (see repo SUPABASE.md). Then **republish** — the whole academy workspace-builder wave (doc/SOP/handoff builders, mobile layout, resume) is on main but not on prod. |
| hourhive-buddy | sso-data-access token auth (edge fn deploy — see its SUPABASE.md; **do NOT set `SSO_DATA_ACCESS_STRICT` yet** — that's stage 2 below) |
| tavus-talent-spotter | #P0-SALESPERSON-SCOPING-AND-BRIEF-JOBS (salesperson_email + jobs.notification_id columns) |

The **sales-portal** P0 policies are already applied and verified (I have Management API access to that project) — nothing needed there.

## 4. HourHive stage 2 — supervised (do together)
HourHive's `sso-data-access` is the ecosystem's most dangerous surface (trusts a client-supplied `role`). Stage 1 (validate the SSO token when present, fall back to body-trust) is deployed. **Stage 2** — flipping `SSO_DATA_ACCESS_STRICT=true` to reject un-tokened calls — will break every caller that doesn't yet attach the SSO token (78 sites), so it must be done after migrating the callers and QA-ing VA + admin + client logins together. Ping me when you want to run it; not safe to flip blind.

---
When 1–3 are done the P0 security posture is fully closed. 4 is a scheduled joint task.
