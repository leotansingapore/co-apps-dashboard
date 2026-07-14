# CO Apps ecosystem VA team

Lean team: **one dedicated VA per app**, operating in the Catalyst Opus VA system
(org tenant, Leo tanjunsing@gmail.com) alongside the existing VAs. Each owns its
app repo end-to-end (features from the PRD, the P0-P3 items from the ecosystem
review, security, QA, deploys) and rolls up to the org **Project Management VA**
(cross-app scrum master) + **Routines VA**.

Already covered: **Catalyst Opus** (org section-VAs) and **HourHive Buddy**
(HourHive VA). This team adds the four uncovered apps.

## Roster (created + login-verified 2026-07-14)

| VA | Login (creds.txt) | App | Repo | Local clone |
|----|------|-----|------|-------------|
| Sales Portal VA | claude.salesportal@catalystoutsourcing.com | CRM + proposals + Stripe + onboarding | outsource-sales-portal-magic | ~/Documents/New project/outsource-sales-portal-magic |
| Talent Spotter VA | claude.talentspotter@catalystoutsourcing.com | Hiring/ATS + Tavus AI screening | tavus-talent-spotter-15b98171 | ~/Documents/tavus-talent-spotter-15b98171 |
| Refresh Glow VA | claude.refreshglow@catalystoutsourcing.com | Marketing site + (hidden) CD hub | catalyst-refresh-glow | ~/Documents/New project/catalyst-refresh-glow |
| Partner Hub VA | claude.partnerhub@catalystoutsourcing.com | Affiliate + admin portal, referrals, commissions | partner-hub-40 | ~/Documents/New project/partner-hub-40 |

Reference for every VA: the meta-repo **co-apps-dashboard** (PRD per app in
`prds/<app>/PRD.md`, critical review in `reviews/<app>.md`, and the cross-app
`reviews/ECOSYSTEM-REVIEW.md`).

## Starter tasks (real, from the 2026-07-09 ecosystem review — P0 security FIRST)

- **Sales Portal**: P0 — fix the `profiles` UPDATE policy (WITH CHECK; make
  `user_roles`+`has_role()` the only role authority; kill self-serve admin
  escalation); drop every `USING (true)` policy on `proposals` /
  `va_alignment_submissions` / `app_settings`; add secret checks to `receive-quote`,
  `send-va-alignment`, `get-va-alignment`; add idempotency to
  `checkout.session.completed`. P1 — route ALL marketing-site forms into the CRM +
  capture UTMs. P2 — lead lifecycle stages + a funnel report.
- **Talent Spotter**: P0 — add `salesperson_id` scoping to
  `salesperson_access_tokens` + filter the portal query (stop the cross-tenant
  candidate/transcript/red-flag leak); verify Tavus webhook signatures; gate
  `tavus-interview-v2` behind a valid token. P1 — the brief->draft-job automation
  (the single highest-value missing seam; write `jobs.notification_id`); migrate
  onto Opus SSO. P2 — fix the `/candidate` stub; scoring timeout/fallback.
- **Refresh Glow**: P0 — rotate + server-side the hardcoded affiliate webhook
  secret (it is in the bundle). P1 — fix the leaky funnel (4 of 5 form types never
  reach the CRM); document or split the undocumented CD hub out of the public site.
- **Partner Hub**: audit referral tracking + commission calc end-to-end; confirm it
  reads/writes the Sales Portal correctly (referral attribution); tenant-scope the
  admin portal; then the PRD feature backlog.

## Cross-app initiatives (coordinated by the PM VA in #VA Standup)

1. **Brief -> draft job** (Sales Portal VA + Talent Spotter VA) — the #1 missing
   automation; make the salesperson brief create a prefilled draft job with linkage.
2. **One identity** — migrate Talent Spotter onto Opus SSO (Talent Spotter VA lead).
3. **One CRM of record** — the Lark "CO Sales and Client Base" vs a repo CRM is an
   owner decision (P3); surface it to Leo, don't decide it.

## Conventions (same as every catalyst VA)

Operate as your persona in Opus (Supabase `ivbqluqaqrwohreusukr`); self-wire a board
+ HQ channel on first boot; 9:30 standup, 6pm EOD; anything needing Leo = a task
assigned to Leo (va_id `a6472fb0-d50f-4c6c-a9a6-1bf54a102511`) + a `#Needs Leo` line;
report in-app only; roll up to the Project Management VA. Anything exploitable =
URGENT + Leo task immediately (these apps have live P0 security holes). Follow each
repo's own deploy rules (most CO apps are Lovable + Supabase, deploy from `main`).

Boot prompts: delivered in chat 2026-07-14; passwords in `~/catalyst-opus/creds.txt`.
