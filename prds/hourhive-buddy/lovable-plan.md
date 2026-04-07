
## Fix: Invoice hours calculation should filter by selected client

### Problem
The VA "Submit Invoice" dialog (`CreateInvoiceDialog.tsx`) fetches **all hours across all clients** for the selected period, even when a specific client is selected. This means the total shows combined hours (e.g., 240h) instead of only that client's hours.

The same issue affects the hourly rate/currency lookup — it doesn't pass the selected client, so it may return the wrong rate.

### Root Cause
Two queries in `CreateInvoiceDialog.tsx` don't include `selectedClientId`:

1. **Hours query** (line 161): missing `selectedClientId` in both the query key and the `getVAHoursForPeriod` call
2. **Rate query** (line 168): missing `selectedClientId` in both the query key and the `getVADetails` call

The API functions (`vaInvoicesApi.getVAHoursForPeriod` and `getVADetails`) already support an optional `clientId` parameter — they just aren't being called with it.

### Changes

**File: `src/components/va/CreateInvoiceDialog.tsx`**

1. **Hours query** — add `selectedClientId` to the query key and pass it to the API call:
   - Query key: `['va-invoice-hours', vaUserId, selectedClientId, start, end]`
   - API call: `getVAHoursForPeriod(vaUserId, start, end, selectedClientId || undefined)`

2. **Rate/details query** — add `selectedClientId` to the query key and pass it to `getVADetails`:
   - Query key: `['va-details-for-invoice', vaUserId, selectedClientId, !!accessToken]`
   - API call: `getVADetails(vaUserId, selectedClientId || undefined)` (both in the accessToken branch and the fallback)

This ensures that when a client is selected, only that client's hours are summed and the client-specific rate/currency is used.
