-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Security Step 4c: LOCK the waiver page data
--
--  Closes the last public read leak: standalone_waivers (the /waiver page)
--  currently lets anyone with the public key read every signed waiver —
--  names, emails, signatures, health notes. This locks reads/deletes to the
--  logged-in owner while keeping public waiver SIGNING (insert) working.
--
--  ▶ RUN AFTER the updated waiver page is live (its admin now requires login).
--    Signing a waiver keeps working; only reading/clearing requires your login.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

do $$
declare r record;
begin
  for r in select policyname from pg_policies
    where schemaname='public' and tablename='standalone_waivers'
  loop
    execute format('drop policy if exists %I on public.standalone_waivers', r.policyname);
  end loop;
end $$;

-- Anyone may SIGN (insert). Only the owner may read or delete.
create policy sw_public_insert on public.standalone_waivers
  for insert to anon, authenticated with check (true);
create policy sw_owner_select on public.standalone_waivers
  for select to authenticated using (public.is_owner());
create policy sw_owner_delete on public.standalone_waivers
  for delete to authenticated using (public.is_owner());

-- Verify — INSERT should allow anon; SELECT/DELETE should be authenticated only.
select tablename, policyname, cmd as command, roles as applies_to
from pg_policies
where schemaname='public' and tablename='standalone_waivers'
order by cmd, policyname;
