-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Security Step 4d-2, PART B: revoke public UPDATE
--
--  ▶ RUN ONLY AFTER Part A is in, the updated site is live, and you've
--    confirmed booking still works (book a spot on pilates / mat & chat /
--    create & recharge; the hold-expiry + payment paths now run through the
--    Part A functions).
--
--  Removes the public key's ability to UPDATE these three tables directly.
--  Public update paths now go through the narrow Part A functions; you (owner)
--  keep full update for admin actions.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname='public'
      and tablename in ('pilates_registrations','matchat_registrations','create_recharge_registrations')
      and cmd = 'UPDATE'
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

create policy pil_owner_update on public.pilates_registrations
  for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy mc_owner_update on public.matchat_registrations
  for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy cr_owner_update on public.create_recharge_registrations
  for update to authenticated using (public.is_owner()) with check (public.is_owner());

-- Verify — UPDATE should be {authenticated} only, no {anon}/{public}.
select tablename, policyname, cmd as command, roles as applies_to
from pg_policies
where schemaname='public'
  and tablename in ('pilates_registrations','matchat_registrations','create_recharge_registrations')
  and cmd = 'UPDATE'
order by tablename;
