-- ============================================================
-- Ledger app schema for Supabase
-- Run this once in your project's SQL Editor (Supabase Dashboard
-- → SQL Editor → New query → paste all → Run).
-- ============================================================

-- ---------- profiles ----------
-- One row per user, holding their role. Created automatically
-- whenever someone signs up (see trigger below).
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  role text not null default 'standard' check (role in ('standard', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- A user can read their own profile (needed so the app can check
-- "am I standard or admin" after login).
create policy "profiles: read own row"
  on public.profiles for select
  using (auth.uid() = id);

-- ---------- auto-create profile on signup ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- helper: is this user an admin? ----------
-- security definer so it can check profiles without being blocked
-- by the RLS policy above (which only allows reading your own row).
create or replace function public.is_admin(uid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = uid and role = 'admin'
  );
$$;

-- ---------- ledger ----------
create table if not exists public.ledger (
  id bigint generated always as identity primary key,
  match text default '',
  score text default '',
  notes text default '',
  added_by uuid references auth.users (id),
  added_by_email text,
  created_at timestamptz not null default now()
);

alter table public.ledger enable row level security;

-- Everyone logged in can read every row (so standard users can
-- see and select the text on the page).
create policy "ledger: read all"
  on public.ledger for select
  to authenticated
  using (true);

-- Standard + admin can insert, but only as themselves — this is
-- the "add my login" button. added_by/added_by_email/created_at
-- should be set from the client to the logged-in user, but this
-- check makes it impossible to insert as someone else even if the
-- client is tampered with.
create policy "ledger: insert own row"
  on public.ledger for insert
  to authenticated
  with check (added_by = auth.uid());

-- Only admins can edit existing rows.
create policy "ledger: admin update"
  on public.ledger for update
  to authenticated
  using (public.is_admin(auth.uid()));

-- Only admins can delete rows.
create policy "ledger: admin delete"
  on public.ledger for delete
  to authenticated
  using (public.is_admin(auth.uid()));

-- A standard user can also delete their own signup row (but no one else's).
-- Postgres OR's multiple policies for the same action together, so this
-- adds an additional allowed case on top of "admin delete" above, rather
-- than replacing it.
create policy "ledger: delete own row"
  on public.ledger for delete
  to authenticated
  using (added_by = auth.uid());

-- ---------- make yourself an admin ----------
-- After you sign up through the app once, run this (with your own
-- email) to promote yourself. Do this for every admin you want.
--
-- update public.profiles set role = 'admin' where email = 'you@example.com';

