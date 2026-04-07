# PRD: Admin Payroll & EOD Hub

**Status:** FINALIZED
**Date:** 2026-03-11
**Project:** Catalyst Opus — Client Dashboard (`/admin`)

---

## 1. Architecture Decision

### Tracker = Time Clock (hours + EOD reports only)

The Tracker project records work hours and EOD reports. That's its job. Its invoice feature is **stalled ("Coming Soon")** until the client dashboard payroll system is built.

### Client Dashboard = Business Brain (rates, payroll, invoices, billing)

The client dashboard owns all business logic:
- **Rates** — `employee_profiles.hourly_rate`, `employee_profiles.payment_type`, `va_assignments.hourly_rate`
- **Payroll calculations** — hours (from Tracker) × rates (from local DB)
- **Invoices & billing** — generated here, not in Tracker

### Data Flow

```
TRACKER (time clock)                     CLIENT DASHBOARD (business brain)
────────────────────                     ─────────────────────────────────

VA clocks hours ─────┐                  Rates in employee_profiles
VA submits EOD ──────┤                    ├── hourly_rate
                     │   read-only        ├── payment_type (hourly/fixed)
                     ├── bridge ────────► └── va_assignments.hourly_rate (per-client)
                     │   fetchTrackerData()
daily_reports ───────┤                  Payroll Calculation:
  hours_worked       │                    hours (from Tracker) × rate (from local)
  billable_hours     │                    = gross_pay
  tasks, notes       │                    - deductions + bonuses = net_pay
  client_id          │
  report_date        │                  Invoices & Billing:
                     │                    Generated in client-dashboard
Invoice feature ─────┘                    (Tracker invoices → "Coming Soon")
  → "COMING SOON"
```

### Why This Works
- **No rate sync needed** — client-dashboard owns rates, Tracker doesn't need them
- **No invoice duplication** — one system in client-dashboard
- **Bridge stays read-only** — just fetch hours + EOD reports
- **Single source of truth** for money: client-dashboard

---

## 2. What We Read from Tracker

Only **two things** come from Tracker via `fetchTrackerData()`:

### A. Hours Data (`get-all-reports`)

Raw daily reports for all VAs. We use this for both Payroll and EOD tabs.

```typescript
// Response from Tracker "get-all-reports" action
interface TrackerDailyReport {
  id: string;
  va_user_id: string;
  va_email: string;
  va_name: string;
  client_id: string;
  client_name: string;
  report_date: string;          // "2026-03-10"
  start_time: string | null;
  end_time: string | null;
  hours_worked: number;         // ← this is what we need for payroll
  billable_hours: number | null;
  tasks: string | null;         // ← for EOD tab
  notes: string | null;         // ← for EOD tab
  time_tracked: boolean;        // timer vs manual
  created_at: string;
}
```

### B. Leave Requests (`get-all-leave-requests`)

For showing leave days in the payroll view.

```typescript
interface TrackerLeaveRequest {
  id: string;
  va_user_id: string;
  va_name: string;
  va_email: string;
  leave_type: 'vacation' | 'sick' | 'personal' | 'unpaid' | 'other';
  start_date: string;
  end_date: string;
  reason: string | null;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
}
```

### What We Do NOT Read from Tracker

- ~~`get-payroll-report`~~ — Uses Tracker's own rates. We calculate locally instead.
- ~~`get-va-client-hours`~~ — Uses Tracker's rates. We calculate per-client from raw reports + local rates.
- ~~`get-va-invoices`~~ — Stalled feature. Not used.

---

## 3. Payroll Calculation Logic (Client-Side)

### Data Sources

```
Tracker: get-all-reports ──────► hours_worked per VA per day per client
Local: employee_profiles ──────► hourly_rate, payment_type
Local: va_assignments ─────────► per-client hourly_rate override
Local: departments ────────────► department name, color
Local: profiles ───────────────► full_name, avatar_url
```

### Calculation

```typescript
// For each VA in the filtered date range:

// 1. Get all their daily_reports from Tracker
const vaReports = trackerReports.filter(r => r.va_user_id === vaId);

// 2. Sum hours
const totalHours = vaReports.reduce((sum, r) => sum + r.hours_worked, 0);
const billableHours = vaReports.reduce((sum, r) => sum + (r.billable_hours ?? r.hours_worked), 0);

// 3. Get rate from local DB
const employeeProfile = employeeProfiles.find(p => p.user_id === vaId);
const paymentType = employeeProfile?.payment_type ?? 'hourly';
const defaultRate = employeeProfile?.hourly_rate ?? 0;

// 4. Calculate gross pay
let grossPay: number;
if (paymentType === 'fixed') {
  grossPay = defaultRate; // fixed monthly rate
} else {
  grossPay = billableHours * defaultRate; // hourly
}

// 5. Per-client breakdown (for sidebar expansion)
const clientBreakdown = vaReports.reduce((acc, report) => {
  const clientId = report.client_id;
  if (!acc[clientId]) {
    // Check for per-client rate override
    const assignment = vaAssignments.find(a => a.va_id === vaId && a.client_id === clientId);
    const clientRate = assignment?.hourly_rate ?? defaultRate;
    acc[clientId] = { clientName: report.client_name, hours: 0, rate: clientRate, subtotal: 0 };
  }
  acc[clientId].hours += report.hours_worked;
  acc[clientId].subtotal = acc[clientId].hours * acc[clientId].rate;
  return acc;
}, {});
```

---

## 4. UI Layout (People Management Pattern)

Reference: `src/pages/AdminPeople.tsx` — same structure

```
┌──────────────────────────────────────────────────────────┐
│  Payroll & EOD                                           │
│  Manage payroll and end-of-day reports                   │
│                                                          │
│  ┌──────────┐ ┌──────────┐                               │
│  │ Payroll  │ │   EOD    │  ← tabs (persist in context)  │
│  └──────────┘ └──────────┘                               │
│                                                          │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                     │
│  │Total │ │Billable│ │Gross │ │ VA  │  ← summary cards   │
│  │Hours │ │Hours  │ │ Pay  │ │Count│                     │
│  └──────┘ └──────┘ └──────┘ └──────┘                     │
│                                                          │
│  ┌───────────────────┐ ┌────────┐ ┌──────┐ ┌──────────┐  │
│  │ Search VA...      │ │Dept ▾  │ │Type ▾│ │ Mar 2026 │  │
│  └───────────────────┘ └────────┘ └──────┘ └──────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Name       │ Dept    │ Type  │ Rate │ Hours│ Pay  │  │
│  │────────────│─────────│───────│──────│──────│──────│  │
│  │ Archie M.  │ Design  │ Hourly│$5/hr │ 160  │ $800 │  │ ← click
│  │ Jeylyn K.  │ Mktg    │ Hourly│$6/hr │ 120  │ $720 │  │
│  │ Leree Ann  │ Admin   │ Fixed │ $500 │  80  │ $500 │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌── TOTALS ──────────────────────────────────────────┐  │
│  │              Hours: 360  │  Total Pay: $2,020      │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘

Click a row → Sidebar Sheet opens:

┌────────── Sidebar Drawer ──────────┐
│                                     │
│  Archie Miguel            ✕ close   │
│  Design Department                  │
│  Hourly @ $5/hr                     │
│                                     │
│  ── PAYROLL SIDEBAR ──              │
│  Period: Mar 1-11, 2026             │
│  Total Hours: 160                   │
│  Billable Hours: 155                │
│  Gross Pay: $800                    │
│                                     │
│  Per-Client Breakdown:              │
│  ┌───────────────────────────────┐  │
│  │ Dont Delete   │ 80h │ $400   │  │
│  │ D'Marketing   │ 75h │ $375   │  │
│  │ Avyl Test     │  5h │  $25   │  │
│  └───────────────────────────────┘  │
│                                     │
│  ── OR EOD SIDEBAR ──               │
│  Calendar (highlighted dates)       │
│                                     │
│  Mar 10: 8.5 hrs                    │
│  Client: Dont Delete                │
│  Tasks: Updated landing page...     │
│  Status: Approved                   │
│                                     │
│  Mar 9: 7.0 hrs                     │
│  Client: D'Marketing               │
│  Tasks: Social media designs...     │
│  Status: Pending                    │
└─────────────────────────────────────┘
```

---

## 5. Payroll Tab

### Summary Cards
- Total Hours (sum of all VAs' hours in period)
- Billable Hours
- Gross Pay (calculated: hours × local rates)
- VA Count

### Table Columns

| Column | Source | Sortable |
|--------|--------|----------|
| VA Name | `profiles.full_name` (alpha default) | Yes |
| Department | `employee_profiles` → `departments` | Yes |
| Payment Type | `employee_profiles.payment_type` (hourly/fixed badge) | Yes |
| Rate | `employee_profiles.hourly_rate` or fixed rate | Yes |
| Total Hours | Sum from Tracker `daily_reports` | Yes |
| Billable Hours | Sum from Tracker `daily_reports` | Yes |
| Gross Pay | Calculated: hours × rate (or fixed amount) | Yes |

### Footer Row
Total Hours, Total Billable, Total Gross Pay across all visible rows.

### Sidebar (click a row)
- VA info header (name, department, payment type, rate)
- Period totals
- Per-client breakdown table (hours per client × per-client rate from `va_assignments`)

---

## 6. EOD Tab

### Table Columns

| Column | Source | Sortable |
|--------|--------|----------|
| VA Name | `va_name` from Tracker report (alpha default) | Yes |
| Date | `report_date` | Yes |
| Hours | `hours_worked` | Yes |
| Client(s) | `client_name` (+N badge if multiple per day) | Yes |
| Tasks | Truncated preview | No |
| Tracked | `time_tracked` (timer/manual icon) | Yes |

### Grouping
- By VA (default) — collapsible sections per VA
- By Date — collapsible sections per date
- Flat list

### Sidebar (click a row)
- VA info header
- Mini calendar with highlighted report dates (color by status if available)
- Scrollable list of EOD reports for this VA in the date range
- Each report: date, hours, client, task summary

---

## 7. Filters (Persist Across Tabs)

| Filter | Type | Options |
|--------|------|---------|
| Date Range | Calendar picker + presets | This month, Last month, Last 2 months, Custom |
| Department | Multi-select | From local `departments` table |
| Payment Type | Select | All, Hourly, Fixed |
| Search | Text input | VA name search (debounced 300ms) |

**Persistence:** `PayrollEODFilterContext` + `localStorage` key `catalyst_payroll_eod_filters`.

```typescript
interface PayrollEODFilters {
  dateRange: { start: string; end: string };
  departmentIds: string[];
  paymentType: 'all' | 'hourly' | 'fixed';
  vaSearch: string;
  activeTab: 'payroll' | 'eod';
  sortField: string;
  sortDirection: 'asc' | 'desc';
}

const STORAGE_KEY = 'catalyst_payroll_eod_filters';
// Pattern: SpaceContext.tsx (context + localStorage with try-catch)
// Tab state: controlled `value` on SubTabs (NOT defaultValue)
```

---

## 8. Tracker Changes Needed

### Put Invoice Feature in "Coming Soon" State

In the Tracker project, the following should be disabled/gated:

- VA invoice creation UI → show "Coming Soon" banner
- Admin invoice management UI → show "Coming Soon" banner
- Keep the `va_invoices` table and edge function actions intact (don't delete data)
- Just disable the UI entry points

**Files to modify in Tracker:**
- `src/pages/admin/Finance.tsx` — Invoice History tab → "Coming Soon"
- `src/pages/va/InvoiceReceiver.tsx` — VA invoice view → "Coming Soon"
- `src/components/admin/va-invoices/*` — Gate behind coming soon flag

**No edge function changes needed** — the actions stay, we just don't call them.

---

## 9. Implementation Plan

### Phase 1: Data Layer + Payroll Tab
- [ ] Add types to `src/types/tracker.ts` (TrackerDailyReport already exists, verify it matches)
- [ ] Create `useTrackerAllReports()` hook — wraps `fetchTrackerData("get-all-reports")`
- [ ] Create `usePayrollCalculation()` hook — merges Tracker hours with local rates
  - Fetches: Tracker reports + local employee_profiles + va_assignments + departments + profiles
  - Calculates: per-VA totals, per-client breakdowns, summary cards
  - Returns: sorted/filtered payroll entries
- [ ] Create `PayrollEODFilterContext` with localStorage persistence
- [ ] Create `/admin/payroll-eod` route + `AdminPayrollEOD.tsx` page
- [ ] Add to AdminSidebar navigation (DollarSign icon)
- [ ] Build PayrollTab: summary cards + VA table + footer totals
- [ ] Build VADetailDrawer (Sheet sidebar) with payroll content

### Phase 2: EOD Tab
- [ ] Build EODTab: report table with grouping controls
- [ ] Build EOD sidebar content (calendar + report list)
- [ ] Wire up `get-all-leave-requests` for leave indicator
- [ ] Client column with "+N" overflow badge

### Phase 3: Polish
- [ ] CSV/PDF export (extend `src/lib/payroll/export.ts`)
- [ ] Advanced date presets (last quarter, YTD)
- [ ] Leave days indicator in payroll view
- [ ] Department color badges

### Phase 4: Tracker "Coming Soon"
- [ ] Gate Tracker invoice UI behind "Coming Soon" state
- [ ] Keep data/actions intact, just disable entry points

---

## 10. Files to Modify / Create

### Modify (Client Dashboard)
- `src/App.tsx` — Add: `const AdminPayrollEOD = lazyWithRetry(() => import("./pages/AdminPayrollEOD"))` + route
- `src/components/layout/AdminSidebar.tsx` — Add nav item `{ title: "Payroll & EOD", url: "/admin/payroll", icon: DollarSign }`
- `src/types/tracker.ts` — Verify/add `TrackerDailyReport` and `TrackerLeaveRequest` types

### Create (Client Dashboard)
```
src/pages/AdminPayrollEOD.tsx
src/contexts/PayrollEODFilterContext.tsx
src/hooks/usePayrollCalculation.ts         ← core: merges Tracker hours with local rates
src/components/admin/payroll-eod/
  ├── PayrollTab.tsx
  ├── EODTab.tsx
  ├── PayrollEODFilterBar.tsx
  ├── VADetailDrawer.tsx                   ← Sheet sidebar
  ├── PayrollSummaryCards.tsx
  ├── PayrollVATable.tsx
  ├── EODReportTable.tsx
  ├── DrawerPayrollDetail.tsx
  └── DrawerEODDetail.tsx
```

### Modify (Tracker — Phase 4)
- `src/pages/admin/Finance.tsx` — Gate invoice tabs
- `src/pages/va/InvoiceReceiver.tsx` — "Coming Soon" banner

### Existing to Reuse
- `src/lib/tracker-api.ts` — `fetchTrackerData()` bridge (no changes)
- `src/hooks/useTrackerData.ts` — Extend with `useTrackerAllReports()`
- `src/hooks/usePayrollData.ts` — `useDepartments()` for department list
- `src/lib/payroll/export.ts` — CSV/PDF export utilities
- `src/lib/payroll/calculations.ts` — May refactor to accept Tracker data

---

## 11. Key Technical Notes

### Merge Strategy
- **Merge key:** `va_user_id` (UUID consistent across both Supabase instances)
- **Secondary merge:** `va_email` (fallback if UUID not matched)
- Tracker reports include `va_user_id` — match against local `employee_profiles.user_id`

### Payroll Calculation in `usePayrollCalculation()`
```typescript
// This hook is the core of the feature
function usePayrollCalculation(filters: PayrollEODFilters) {
  // 1. Fetch Tracker reports for date range
  const { data: trackerReports } = useTrackerAllReports();

  // 2. Fetch local data
  const { data: employeeProfiles } = useEmployeeProfiles();
  const { data: vaAssignments } = useVAAssignments();
  const { data: departments } = useDepartments();
  const { data: profiles } = useProfiles();

  // 3. Filter Tracker reports by date range
  // 4. Group by va_user_id
  // 5. For each VA:
  //    - Sum hours from Tracker
  //    - Get rate from local employee_profiles
  //    - Get per-client rate overrides from va_assignments
  //    - Calculate gross pay (hourly × hours OR fixed amount)
  //    - Get department from employee_profiles → departments
  // 6. Apply filters (department, payment type, search)
  // 7. Sort by current sort field
  // 8. Return entries + summary totals
}
```

### What `get-all-reports` Returns (No Date Filter)
This action returns ALL reports. Client-side filtering by date range is needed:
```typescript
const filteredReports = trackerReports.filter(r =>
  r.report_date >= filters.dateRange.start &&
  r.report_date <= filters.dateRange.end
);
```
For large datasets, consider using `get-all-reports-for-period` (returns aggregated totals per VA, not per-date detail) for summary cards, and `get-all-reports` for EOD detail.

### Rate Priority
1. `va_assignments.hourly_rate` (per-client override) — if exists and not null
2. `employee_profiles.hourly_rate` (VA default rate) — fallback
3. `0` — if neither exists (show warning)
