# Tavus Talent Spotter -- Product Requirements Document

**Repo:** [leotansingapore/tavus-talent-spotter-15b98171](https://github.com/leotansingapore/tavus-talent-spotter-15b98171)
**Owner:** Jilian Garette
**Status:** Active
**Stack:** React + TypeScript + Vite + Supabase, Lovable-hosted

---

## 1. One-liner

A recruitment portal that uses Tavus AI video interviews to screen candidates for VA roles, feeding qualified hires into the Catalyst Outsourcing hiring pipeline.

## 2. Goals

- Replace manual screening calls with asynchronous AI video interviews
- Produce a ranked candidate pipeline that recruiters can review in minutes instead of hours
- Reduce time-to-hire for new VAs by front-loading qualification
- Hand off qualified candidates to Catalyst Opus hiring workflow without re-entering data

## 3. Non-goals

- Payroll, time tracking, or post-hire workflow (owned by HourHive Buddy / Catalyst Opus)
- Public job board / candidate-sourcing (recruiters source candidates themselves)
- Full applicant tracking system -- this is screening + triage, not a replacement for Greenhouse / Lever

## 4. Core features

- Candidate intake form (role, experience, timezone, availability)
- Tavus AI video interview invitation + scoring
- Recruiter dashboard: ranked candidate list with video playback + transcript
- Decision actions: advance / hold / reject
- Handoff to Catalyst Opus on "advance" decision

## 5. Architecture

- Frontend: Lovable-generated React + TypeScript
- Auth + DB: Supabase (own instance, not shared with other apps)
- AI video: Tavus API for conversational video interviews
- Hand-off: REST/webhook into Catalyst Opus hiring module (TBD)

## 6. How it fits the ecosystem

- **Upstream:** Candidates apply directly or are sourced by recruiters
- **Downstream:** Advanced candidates feed into Catalyst Opus hiring pipeline
- **Adjacent:** Sales Portal (client demand) drives the number of hires needed

## 7. Current status

- Repo bootstrapped via Lovable
- Live URL: https://lovable.dev/projects/28119f40-5ec3-48f1-b7fa-c4f411e06f61
- PRD stub created during CO Apps dashboard onboarding -- full PRD to be fleshed out with Jilian

## 8. Open questions

1. Integration shape with Catalyst Opus hiring -- API, webhook, or manual export?
2. Does Tavus Talent Spotter authenticate via Catalyst Opus SSO or keep its own auth?
3. Which Tavus replica(s) do we use for interviewer persona?
4. Data retention / GDPR for candidate videos?

## 9. Related

- [Ecosystem PRD](../ECOSYSTEM-PRD.md)
- [Catalyst Opus PRD](../catalyst-opus/PRD.md) -- downstream hiring workflow
