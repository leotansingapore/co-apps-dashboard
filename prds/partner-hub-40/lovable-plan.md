

## Add Portal Switcher for Dual-Role Users

Add a "Switch Portal" button to both the Affiliate and Admin sidebars so users with both roles can navigate between portals without logging out.

### How It Works

- Users with admin roles will see a **"Switch to Admin"** button in the Affiliate Portal sidebar and a **"Switch to Affiliate"** button in the Admin Portal sidebar
- On mobile, the switcher will also appear in the Bottom Nav's "More" sheet
- The switch is instant -- no re-login required since the user already has both sessions

### Changes

**1. Affiliate Sidebar (`src/components/AppSidebar.tsx`)**
- Add a "Switch to Admin Portal" button (with Shield icon) in the footer section, above the Sign Out button
- Only visible when `isAdmin` is true (from AuthContext)
- Clicking navigates to `/admin` and ensures admin session is initialized

**2. Admin Sidebar (`src/components/admin/AdminSidebar.tsx`)**
- Replace the existing "Affiliate Portal" external link with a proper "Switch to Affiliate Portal" button
- Navigates to `/dashboard` using React Router (not an external link)

**3. Mobile Bottom Nav (`src/components/BottomNav.tsx`)**
- Add a "Switch to Admin Portal" item in the "More" sheet for admin users
- Only visible when `isAdmin` is true

**4. Admin Layout Header (`src/components/admin/AdminLayout.tsx`)**
- Add a small "Affiliate Portal" switch button in the header bar for quick access

### Technical Details

- The `isAdmin` flag from `useAuth()` context determines visibility
- Navigation uses `useNavigate()` from React Router for seamless SPA transitions
- The admin sidebar switch uses `navigate('/dashboard')` instead of the current `<a href="/dashboard" target="_blank">` which opens a new tab
- No new components needed -- just additions to existing sidebar/nav components

