-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Security Step 4b, PART 2: LOCK the booking-table reads
--
--  ▶ RUN THIS ONLY AFTER:
--     1. You ran PART 1 (the read + dedup functions), AND
--     2. The updated website is live AND you've confirmed booking still works
--        (book a test spot on pilates / mat & chat / create & recharge, and
--         check the admin rosters still load).
--
--  What it does: removes the public key's ability to READ these three tables
--  directly (it can no longer pull names / emails / phones / health notes).
--  The public pages now get what they need through the safe functions from
--  PART 1 instead. Booking sign-ups (INSERT) and the booking write paths
--  (waitlist, hold-expiry, Stripe-return) are left working.
--
--  Reversible: to undo, re-create an anon SELECT policy (see bottom).
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

-- Drop ONLY the SELECT (read) policies on these tables; leave INSERT/UPDATE/
-- DELETE untouched so every booking write keeps working.
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('pilates_registrations','matchat_registrations','create_recharge_registrations')
      and cmd = 'SELECT'
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Add an owner-only direct SELECT (belt-and-suspenders: the app reads through
-- the PART 1 functions, but this lets you query the tables directly while
-- logged in, and future admin features keep working).
create policy pil_owner_select on public.pilates_registrations
  for select to authenticated using (public.is_owner());
create policy mc_owner_select on public.matchat_registrations
  for select to authenticated using (public.is_owner());
create policy cr_owner_select on public.create_recharge_registrations
  for select to authenticated using (public.is_owner());

-- ─── Verify: these tables should now have NO anon/public SELECT policy ──
select tablename, policyname, cmd as command, roles as applies_to
from pg_policies
where schemaname='public'
  and tablename in ('pilates_registrations','matchat_registrations','create_recharge_registrations')
order by tablename, cmd, policyname;

-- ─── (Reference only — DO NOT run unless you need to UNDO the lock) ─────
-- create policy pil_anon_select on public.pilates_registrations         for select to anon using (true);
-- create policy mc_anon_select  on public.matchat_registrations         for select to anon using (true);
-- create policy cr_anon_select  on public.create_recharge_registrations for select to anon using (true);
