-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Security Step 4a: LOCK DOWN admin-only data
--
--  What this does:
--   • Adds an "owner" role tied to YOUR login.
--   • Locks reading/editing/deleting of your admin-only tables to YOU
--     when logged in (blooming/riddim/bag list, corporate, notify list,
--     signed agreements). Public sign-up forms can still INSERT.
--   • Blocks the public key from calling the reformer admin functions
--     (roster, mark-paid, remove, edit) — so no one can pull your roster
--     with the old password anymore.
--   • Keeps event_config publicly READable (your badges) but owner-only
--     writable.
--
--  What it does NOT touch (handled in Step 4b, needs code changes):
--   • pilates / matchat / create_recharge tables (your public booking
--     page reads these) and standalone_waivers.
--   • The collaborator login.
--   • Removing the password from the site code.
--
--  ▶ Safe to run once. No downtime. No website change needed for this step.
--
--  HOW TO RUN: Supabase → SQL Editor → New query → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

-- ─── 0) Owner role ──────────────────────────────────────────────────
create table if not exists public.admin_roles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null default 'owner',
  created_at timestamptz default now()
);
alter table public.admin_roles enable row level security;

-- Seed YOU as the owner, looked up by your login email.
-- ▶▶ If your Supabase login email is NOT the one below, edit it here:
insert into public.admin_roles (user_id, role)
select id, 'owner' from auth.users
where email = 'niara.comrie@gmail.com'
on conflict (user_id) do update set role = 'owner';

-- Helper: is the current caller an owner?
create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admin_roles
    where user_id = auth.uid() and role = 'owner'
  );
$$;
revoke all on function public.is_owner() from public;
grant execute on function public.is_owner() to anon, authenticated;

-- Only the owner can see/manage the roles table.
drop policy if exists admin_roles_owner_all on public.admin_roles;
create policy admin_roles_owner_all on public.admin_roles
  for all to authenticated using (public.is_owner()) with check (public.is_owner());

-- ─── 1) Wipe the wide-open anon policies on the admin-only tables ────
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in (
        'blooming_interest','corporate_inquiries','corporate_bookings',
        'notify_list','signed_agreements','event_config'
      )
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- ─── 2) Rebuild correct policies ────────────────────────────────────
-- Pattern: anyone may INSERT (sign-up forms); only the OWNER may
-- read / edit / delete.

-- blooming_interest  (Something's Blooming + Riddim + Bag reserve lists)
create policy bi_public_insert on public.blooming_interest
  for insert to anon, authenticated with check (true);
create policy bi_owner_select on public.blooming_interest
  for select to authenticated using (public.is_owner());
create policy bi_owner_delete on public.blooming_interest
  for delete to authenticated using (public.is_owner());

-- corporate_inquiries
create policy cinq_public_insert on public.corporate_inquiries
  for insert to anon, authenticated with check (true);
create policy cinq_owner_select on public.corporate_inquiries
  for select to authenticated using (public.is_owner());
create policy cinq_owner_update on public.corporate_inquiries
  for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy cinq_owner_delete on public.corporate_inquiries
  for delete to authenticated using (public.is_owner());

-- corporate_bookings
create policy cbk_public_insert on public.corporate_bookings
  for insert to anon, authenticated with check (true);
create policy cbk_owner_select on public.corporate_bookings
  for select to authenticated using (public.is_owner());
create policy cbk_owner_update on public.corporate_bookings
  for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy cbk_owner_delete on public.corporate_bookings
  for delete to authenticated using (public.is_owner());

-- notify_list
create policy nl_public_insert on public.notify_list
  for insert to anon, authenticated with check (true);
create policy nl_owner_select on public.notify_list
  for select to authenticated using (public.is_owner());
create policy nl_owner_update on public.notify_list
  for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy nl_owner_delete on public.notify_list
  for delete to authenticated using (public.is_owner());

-- signed_agreements  (waiver signatures — sensitive)
create policy sa_public_insert on public.signed_agreements
  for insert to anon, authenticated with check (true);
create policy sa_owner_select on public.signed_agreements
  for select to authenticated using (public.is_owner());
create policy sa_owner_delete on public.signed_agreements
  for delete to authenticated using (public.is_owner());

-- event_config  (badges) — public may READ, only owner may write
create policy ec_public_select on public.event_config
  for select to anon, authenticated using (true);
create policy ec_owner_insert on public.event_config
  for insert to authenticated with check (public.is_owner());
create policy ec_owner_update on public.event_config
  for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy ec_owner_delete on public.event_config
  for delete to authenticated using (public.is_owner());

-- ─── 3) Block the public key from the reformer admin functions ──────
-- (reformer_spot_counts stays public — it returns counts only, no names.
--  book_* stay public — that's how customers book.)
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'reformer_roster','reformer_set_paid','reformer_remove',
        'reformer_edit','reformer_clear_health','reformer_set_session'
      )
  loop
    execute format('revoke execute on function %s from anon, public', r.sig);
    execute format('grant  execute on function %s to authenticated', r.sig);
  end loop;
end $$;

-- ─── 4) Verify — should show your owner row, then the new policies ──
select 'owner seeded:' as check, count(*) as rows from public.admin_roles where role='owner';

select tablename, policyname, cmd as command, roles as applies_to
from pg_policies
where schemaname='public'
  and tablename in ('blooming_interest','corporate_inquiries','corporate_bookings',
                    'notify_list','signed_agreements','event_config','admin_roles')
order by tablename, cmd, policyname;
