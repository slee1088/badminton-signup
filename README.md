# Tennis Signups

A lightweight sign-up sheet for tennis sessions. Anyone can create an account
and add their own name to a session; admins can edit and delete any row.
Built with plain HTML/JS + Supabase (auth, database, and email) — no server
or build step required.

---

## What's in this repo

| File | Purpose |
|---|---|
| `index.html` | The whole app: sign in, sign up, forgot password, and the signups table |
| `reset-password.html` | Landing page a password-reset email links to, where the user sets a new password |
| `schema.sql` | One-time database setup — run this in Supabase's SQL Editor |

---

## How it works

- **Auth** is handled entirely by Supabase (`supabase-js` loaded from a CDN in
  both HTML files). No custom backend.
- **Roles**: every user gets a row in a `profiles` table with a `role` of
  either `standard` or `admin` (new signups default to `standard`).
  - **Standard users** can see the table, select/copy text, and click
    **"＋ Sign me up"** once — that adds a row with their email and a
    timestamp. The button disables itself after they've signed up once
    (checked against the actual data, so it stays disabled across refreshes
    and logins too).
  - **Admins** see the same table but with editable fields, a delete button
    per row, and can add unlimited blank rows.
- **Permissions are enforced in the database**, not just hidden in the UI.
  Row-level security (RLS) policies in `schema.sql` mean that even if
  someone opened dev tools and called the Supabase API directly, a standard
  user still couldn't edit or delete rows — only Postgres's own rules decide
  that, based on the `role` column.
- **No shared secret token.** Every user has their own Supabase session.
  There's nothing sensitive baked into the page besides the public
  "anon"/"publishable" API key, which is safe to expose (that's what RLS is
  for).

---

## 1. Create the Supabase project

1. Go to [supabase.com](https://supabase.com) → **New project**.
2. Pick a name/region and set a database password (you likely won't need it
   day to day, but keep it somewhere safe).
3. Wait for it to finish provisioning (~2 minutes).

## 2. Run the schema

1. In the Supabase dashboard: **SQL Editor → New query**.
2. Paste in the entire contents of `schema.sql` and click **Run**.

This creates:
- `profiles` — one row per user, with their `role` (defaults to `standard`
  via a trigger that fires automatically on every signup)
- `ledger` — the actual signups table (`match`, `score`, `notes`,
  `added_by`, `added_by_email`, `created_at` — the app labels these "Player",
  "Session", "Notes", "Signed up" in the UI, but the underlying column names
  are unchanged from the original build)
- RLS policies enforcing: everyone can read, everyone can insert as
  themselves, only admins can update/delete

## 3. Custom SMTP (using Gmail)

Supabase's built-in email sender is rate-limited and not meant for real use
— it will return a `500` error on signup or password reset once you exceed
a handful of emails per hour. This project sends email through **Gmail**
using an **app password** instead. Steps:

1. **Turn on 2-Step Verification** on the Google account you want to send
   from, if it isn't already: [myaccount.google.com/security](https://myaccount.google.com/security).
   App passwords only work once 2-Step Verification is enabled.
2. Go to **[myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)**,
   create a new app password (name it something like "Supabase"), and copy
   the 16-character password it gives you. This is different from your
   normal Gmail password.
3. In Supabase: **Authentication → Providers → Email → SMTP Settings**, and
   turn on **Enable Custom SMTP**. Fill in:
   | Field | Value |
   |---|---|
   | Sender email | your Gmail address |
   | Sender name | whatever you want emails to show as coming from (e.g. "Tennis Signups") |
   | Host | `smtp.gmail.com` |
   | Port | `587` |
   | Username | your Gmail address |
   | Password | the 16-character app password from step 2 (not your regular Gmail password) |
4. Save, then test by triggering a password reset from the app — the email
   should now come from your Gmail address instead of Supabase's shared
   sender, and won't hit the same rate limit.

Gmail itself has its own daily sending caps (a few hundred emails/day on a
regular account), which is more than enough for a club sign-up sheet but
worth knowing if usage ever grows significantly.

## 4. Get your API keys and wire them in

**Project Settings → API** in Supabase. Copy the **Project URL** and the
**anon / publishable** key, then paste both into the top of the `<script>`
block in **both** `index.html` and `reset-password.html`:

```js
const SUPABASE_URL = "https://YOUR-PROJECT-REF.supabase.co";
const SUPABASE_ANON_KEY = "YOUR-ANON-PUBLIC-KEY";
```

## 5. Host the files

This project is hosted on **GitHub Pages**. In general, any static host
works (Netlify, Vercel, S3, etc.) — the key requirement is that
`index.html` and `reset-password.html` live in the same folder, since the
password-reset link assumes that.

If using GitHub Pages:
1. Push `index.html`, `reset-password.html`, and `schema.sql` to a repo.
2. **Settings → Pages** → set the source to your main branch (root, or
   `/docs` if you keep files there).
3. Your site will be live at `https://<username>.github.io/<repo-name>/`.
4. In Supabase, under **Authentication → URL Configuration**, set both
   **Site URL** and **Redirect URLs** to that exact URL — otherwise
   verification and password-reset links will redirect somewhere invalid
   (this is the fix for the `localhost:3000` redirect issue encountered
   earlier).

## 6. Make yourself an admin

After signing up through the app once, run this in the SQL Editor (with
your own email):

```sql
update public.profiles set role = 'admin' where email = 'you@example.com';
```

Sign out and back in — you'll now see edit/delete controls and an
unrestricted "＋ Add row" button.

---

## Known limitations / possible next steps

- The "one signup per standard user" rule is enforced by the app checking
  existing data before showing the button as active — it isn't backed by a
  database constraint, so it wouldn't stop someone who called the Supabase
  API directly rather than using the UI. Adding a database-level check (e.g.
  a partial unique index scoped to standard users) would close that gap if
  it ever matters.
- There's no UI yet for an admin to promote another user to admin — that
  still requires running SQL directly. A small "manage users" screen could
  be added later if needed.
- Gmail SMTP is fine for low volume; if this ever needs to send more email
  than Gmail's daily limits allow, a dedicated transactional email provider
  (Resend, Postmark) would be a drop-in replacement in the same SMTP
  settings panel.
