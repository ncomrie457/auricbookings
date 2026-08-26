-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Security Step 4d-1: write hardening (SQL-only, safe)
--
--  Protects ALL events (including upcoming reformer ones) against the two
--  highest-impact tampering vectors, with NO website change and NO booking
--  risk:
--    • No public DELETE — nobody can wipe registrations.
--    • Constrained public INSERT — a booking may only be inserted as UNPAID,
--      so nobody can inject a fake "already paid" row. (Every real booking
--      inserts as unpaid; Stripe / the webhook / you mark it paid later.)
--    • You (logged-in owner) keep full insert/delete for manual adds & admin.
--
--  Not included here (needs code changes, past-event tables only): dropping
--  public UPDATE on pilates/matchat/create_recharge — handled in a later step.
--  Reformer already has no public UPDATE, so upcoming events are covered.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

-- Drop existing INSERT and DELETE policies on the four registration tables
-- (leaves SELECT and UPDATE policies untouched).
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname='public'
      and tablename in ('reformer_registrations','pilates_registrations',
                        'matchat_registrations','create_recharge_registrations')
      and cmd in ('INSERT','DELETE')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Rebuild: public may INSERT only UNPAID rows; owner may INSERT anything;
-- only owner may DELETE.
do $$
declare t text;
begin
  foreach t in array array['reformer_registrations','pilates_registrations',
                           'matchat_registrations','create_recharge_registrations']
  loop
    execute format($f$
      create policy %1$s_public_insert_unpaid on public.%1$I
        for insert to anon, authenticated
        with check (coalesce(is_paid, false) = false);
    $f$, t);
    execute format($f$
      create policy %1$s_owner_insert on public.%1$I
        for insert to authenticated with check (public.is_owner());
    $f$, t);
    execute format($f$
      create policy %1$s_owner_delete on public.%1$I
        for delete to authenticated using (public.is_owner());
    $f$, t);
  end loop;
end $$;

-- Verify — INSERT rows should show the unpaid-check + owner; DELETE owner-only.
select tablename, policyname, cmd as command, roles as applies_to
from pg_policies
where schemaname='public'
  and tablename in ('reformer_registrations','pilates_registrations',
                    'matchat_registrations','create_recharge_registrations')
  and cmd in ('INSERT','DELETE')
order by tablename, cmd, policyname;
