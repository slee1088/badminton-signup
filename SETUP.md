# Setup guide

## 1. Create the Supabase project
1. Go to https://supabase.com → New project. Pick any name/region, set a database password (save it somewhere — you won't need it day-to-day, but you'll need it if you ever connect a Postgres client directly).
2. Wait for provisioning to finish (~2 min).

## 2. Run the schema
1. In the Supabase dashboard: **SQL Editor → New query**.
2. Paste in the entire contents of `schema.sql` and click **Run**.
3. This creates the `profiles` and `ledger` tables, the trigger that gives every new signup a `standard` profile, and the row-level security policies that enforce standard vs admin permissions at the database level (not just in the UI).

## 3. Configure auth email settings
1. **Authentication → Providers → Email**: confirm "Confirm email" is turned on (it is by default) — this is what makes email verification required before sign-in works.
2. **Authentication → URL Configuration**: set **Site URL** to wherever you'll host these files (e.g. `https://yourdomain.com` or, if testing locally, `http://localhost:5500`). Add the same URL to **Redirect URLs**.
3. Supabase's default email templates work out of the box on the free tier for testing. For production, **Authentication → Providers → Email → SMTP Settings** lets you plug in your own sender (e.g. via Resend, Postmark) so verification/reset emails don't land in spam and aren't rate-limited.

## 4. Get your API keys
**Project Settings → API**. Copy:
- **Project URL**
- **anon public** key (safe to expose in client-side code — that's what row-level security is for)

Paste both into `SUPABASE_URL` and `SUPABASE_ANON_KEY` at the top of the `<script>` block in **both** `index.html` and `reset-password.html`.

## 5. Host the two files
Anywhere that serves static files works: GitHub Pages, Netlify, Vercel, S3, or even opening `index.html` directly for local testing (some browsers restrict `file://` origins for auth redirects, so a local static server like `npx serve` is more reliable than double-clicking the file).

Make sure `index.html` and `reset-password.html` live in the same folder — the reset-password redirect link assumes that.

## 6. Try it end to end
1. Open `index.html` → **Create account** → sign up with a real email you can check.
2. Click the verification link in your inbox — it'll redirect back to `index.html`.
3. Sign in. You're now a `standard` user: you can select text and use **Add myself**, but there's no edit/delete.
4. To make yourself (or anyone) an admin, run in the SQL Editor:
   ```sql
   update public.profiles set role = 'admin' where email = 'you@example.com';
   ```
5. Sign out and back in — you'll now see edit and delete controls.

## Notes
- There's no shared secret token anywhere in this version (unlike the old GitHub-PAT approach) — every user authenticates with their own Supabase session, and permissions are enforced by Postgres row-level security, so even a tampered client can't do more than their role allows.
- Free tier limits (as of this writing): 50,000 monthly active users, 500MB database, and a modest email-send rate limit — worth checking Supabase's current pricing page if you expect real usage, since these change.
- If you later want a "remember me on this device" style long-lived session, Supabase sessions already persist in `localStorage` and auto-refresh, so this is handled without extra work — closing the tab and reopening `index.html` will keep the user signed in as-is.
