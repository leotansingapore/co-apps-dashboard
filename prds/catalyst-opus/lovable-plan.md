

## Update OAuth Client Redirect URIs

**What:** Append `http://localhost:8081/auth/callback` to the `redirect_uris` array for OAuth client `d2eb9a26c3a60161c4bd32a39e804625`.

**Current redirect_uris (8 entries):**
- `https://id-preview--8dd7cadb-351d-42e8-93fd-f0fc9f4ada93.lovable.app/auth/callback`
- `https://preview--hourhive-buddy.lovable.app/auth/callback`
- `https://hourhive-buddy.lovable.app/auth/callback`
- `https://track.catalystoutsourcing.com/auth/callback`
- `https://8dd7cadb-351d-42e8-93fd-f0fc9f4ada93.lovableproject.com/auth/callback`
- `http://localhost:8754/callback`
- `http://127.0.0.1:8754/callback`
- `http://localhost:8080/auth/callback`

**Action:** Run the following SQL update using the insert/update tool:

```sql
UPDATE oauth_clients 
SET redirect_uris = array_append(redirect_uris, 'http://localhost:8081/auth/callback')
WHERE client_id = 'd2eb9a26c3a60161c4bd32a39e804625';
```

No code changes needed — this is a one-line data update.

