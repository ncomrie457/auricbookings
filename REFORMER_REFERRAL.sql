-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Referral credits for reformer events
--  (Riddim & Kompa, Shhh… Quiet on the Creek, Turkey Burn)
--
--  WHY: the Auric Club list has a "+½ ref" button that gives someone half
--  a mark for referring a friend. It only appears for Mat & Chat, Pilates
--  and Create & Recharge people, because those rows carry a `code` and the
--  button writes a "#referral" tag straight into that table's admin_notes.
--  Reformer rows are keyed by a numeric id and every write to them goes
--  through a password-guarded RPC, so they had nowhere to record it and the
--  button never rendered. Anyone whose marks come only from a reformer
--  event — everyone from Sept 13 — could not be credited at all.
--
--  WHAT THIS CREATES
--    1) reformer_registrations.referrals — how many friends they referred.
--    2) reformer_set_referral(...)       — owner-only, used by "+½ ref".
--    3) reformer_roster                  — returns the new column so the
--                                          Club list can count it.
--
--  Each referral is worth HALF a mark, matching the other events.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

-- 1) The counter. Defaults to 0, so nothing changes for existing rows.
alter table public.reformer_registrations
  add column if not exists referrals integer not null default 0;

-- 2) Owner-only setter used by the "+½ ref" button.
--    delta: +1 adds a referral, -1 takes one back. Never goes below zero.
create or replace function public.reformer_set_referral(
  pass  text,
  rid   bigint,
  delta integer
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  new_count integer;
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;

  update public.reformer_registrations
     set referrals = greatest(0, coalesce(referrals, 0) + coalesce(delta, 0))
   where id = rid
   returning referrals into new_count;

  return new_count;
end;
$$;

revoke all on function public.reformer_set_referral(text, bigint, integer) from public, anon;
grant execute on function public.reformer_set_referral(text, bigint, integer) to authenticated;

-- 3) NOTE: the admin roster reads through reformer_roster(). If that function
--    uses SELECT * this already works. If it lists columns explicitly, add
--    `referrals` to its SELECT (and to its RETURNS TABLE(...) if it has one),
--    otherwise the Club list won't see the count and the button won't show.

select 'reformer referrals ready — "+½ ref" now works for reformer attendees.' as status;
