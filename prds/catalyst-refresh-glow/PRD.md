# PRD: Catalyst Refresh Glow (Marketing Website)

Version: 1.0
Date: 2026-04-07
Status: Active
Owner: Leo Tan

---

## 1. Introduction

Catalyst Refresh Glow is the public-facing marketing website for Catalyst Outsourcing. It serves as the top of the sales funnel -- attracting prospective clients through SEO-optimized content, showcasing services and pricing, and driving conversions to the Sales Portal.

---

## 2. Goals

| ID | Goal | Success Metric |
|----|------|----------------|
| G-01 | Drive organic traffic to CO services | > 1,000 unique visitors/month from search |
| G-02 | Convert visitors into quote requests | Website-to-quote conversion rate > 3% |
| G-03 | Clearly communicate VA service offerings and pricing | < 2 bounce rate on pricing page |
| G-04 | Build trust through testimonials and case studies | Time on site > 2 minutes average |
| G-05 | Rank on page 1 for "virtual assistant outsourcing Singapore" | Top 10 Google results |

---

## 3. User Roles

### Visitor (Public)
- Browses service pages, pricing, and testimonials
- Submits quote request or contact form
- Downloads resources (guides, case studies)

---

## 4. User Stories

### US-001: Visitor learns about VA services
**Description:** As a business owner, I want to understand what VA services CO offers so I can decide if it fits my needs.

**Acceptance Criteria:**
- [ ] Service pages clearly list VA specializations (admin, bookkeeping, marketing, etc.)
- [ ] Each service page has description, benefits, and use cases
- [ ] Pricing visible without requiring signup
- [ ] FAQ section answers common questions

### US-002: Visitor requests a quote
**Description:** As a prospective client, I want to request a custom quote so I can get specific pricing for my needs.

**Acceptance Criteria:**
- [ ] Quote request form captures company, services, budget, timeline
- [ ] Form submits to Sales Portal `receive-quote` edge function
- [ ] Confirmation page or email after submission
- [ ] UTM parameters preserved for attribution tracking

### US-003: Visitor finds CO via search
**Description:** As someone searching for VA services, I want to find CO through Google so I can evaluate their offering.

**Acceptance Criteria:**
- [ ] Meta titles and descriptions optimized per page
- [ ] Schema.org structured data (LocalBusiness, Service, FAQ)
- [ ] Page load time < 3 seconds (Core Web Vitals green)
- [ ] Mobile responsive (390px+ viewports)

### US-004: Visitor reads case studies
**Description:** As a prospective client, I want to see how other businesses use CO's VAs so I build confidence in the service.

**Acceptance Criteria:**
- [ ] Case study pages with client outcomes and metrics
- [ ] Testimonial carousel on homepage
- [ ] Trust indicators (client logos, review scores)

---

## 5. Functional Requirements

### Pages
- FR-01: Homepage with hero, value proposition, trust signals, and CTA
- FR-02: Service pages per VA specialization (admin, bookkeeping, marketing, etc.)
- FR-03: Pricing page with tier comparison and CTA to Sales Portal
- FR-04: About page with company story and team
- FR-05: Contact page with form submission
- FR-06: FAQ page with expandable sections
- FR-07: Blog/resources section (planned)

### SEO
- FR-08: Unique meta title and description per page
- FR-09: Open Graph and Twitter card meta tags
- FR-10: XML sitemap
- FR-11: Schema.org JSON-LD (LocalBusiness, Service, FAQ)
- FR-12: Canonical URLs

### Lead Capture
- FR-13: Quote request form submitting to Sales Portal edge function
- FR-14: Contact form with email notification
- FR-15: UTM parameter tracking through to Sales Portal
- FR-16: Optional: exit-intent popup for lead capture

### Performance
- FR-17: Largest Contentful Paint < 2.5s
- FR-18: Cumulative Layout Shift < 0.1
- FR-19: Mobile-first responsive design
- FR-20: Image optimization (WebP, lazy loading)

---

## 6. Non-Goals

- No user accounts or login functionality
- No CMS or admin panel for content editing (code-based content)
- No e-commerce or payment processing (handled by Sales Portal)
- No blog platform (static pages only for now)
- No multilingual support

---

## 7. Technical Considerations

- **Static site:** React + Vite, no Supabase backend
- **Deployment:** Lovable Cloud / Vercel
- **No database** -- all dynamic actions (quote requests) go to Sales Portal
- **SEO-critical:** Must be server-renderable or pre-rendered for crawlers

---

## 8. Success Metrics

| Metric | Target |
|--------|--------|
| Monthly organic traffic | > 1,000 uniques |
| Quote request submissions | > 30/month |
| Bounce rate | < 50% |
| Average session duration | > 2 minutes |
| Mobile performance score (Lighthouse) | > 90 |
| Page 1 ranking for primary keywords | 3+ keywords |

---

## 9. Current Status

| Feature | Status |
|---------|--------|
| Homepage with hero and value props | Done |
| Service pages (financial advisors, bookkeeping) | Done |
| Pricing page | Done |
| FAQ sections | Done |
| Contact form | Done |
| SEO meta tags and optimization | In Progress |
| Schema.org structured data | Planned |
| Blog / resources section | Planned |
| Case studies page | Planned |

---

## 10. Open Questions

1. Should this be merged into the Sales Portal as a /marketing route?
2. Should we add a blog for SEO content marketing?
3. Should quote request form live on this site or redirect to Sales Portal?
4. Do we need localized versions for different markets (Philippines, US)?
