
## New Client Notification to Recruiter Project

### Overview
When a client completes payment in the Sales Portal, automatically notify the recruiter project (tavus-talent-spotter on Lovable Cloud) so recruiters can start the hiring process.

### Changes in THIS project (Sales Portal)

**1. Add secrets for recruiter project connection:**
- `RECRUITER_PORTAL_URL` = `https://nkvmvtndwgmkwcabqojb.supabase.co`
- `RECRUITER_PORTAL_ANON_KEY` = the anon key from the recruiter project
- `RECRUITER_SYNC_SECRET` = a shared webhook secret for authentication

**2. Update `supabase/functions/stripe-webhook/index.ts`:**
- After successful payment processing, send an HTTP POST to the recruiter project's `receive-new-client` edge function
- Payload includes: client name, email, company, selected services, contract details

### Changes in the RECRUITER project (tavus-talent-spotter)

**3. Create `receive-new-client` edge function:**
- Accepts POST with client data
- Validates shared secret
- Inserts a record into a `new_client_notifications` table
- Recruiters see it in their dashboard

**4. Create `new_client_notifications` database table:**
- `id`, `client_name`, `email`, `company_name`, `selected_services`, `contract_length`, `status` (new/acknowledged), `created_at`
- RLS: authenticated users can read

### Data sent to recruiter:
| Field | Source |
|-------|--------|
| client_name | proposal.client_name |
| email | proposal.email |
| company_name | proposal.company_name |
| selected_services | proposal.selected_services |
| contract_length | proposal.contract_length |
| payment_amount | session amount |
| paid_at | timestamp |
