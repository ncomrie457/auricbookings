-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — set the expiry on an existing credit
--
--  WHY: credits issued before the six-month rule went in were saved with
--  no expiry date. They show as "· no expiry set" in the Credits tab.
--  This adds the one function needed to fix them in place.
--
--  Fixing in place matters: re-creating the row would reset "issued",
--  and that date is part of the record of what was promised and when.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
--  (Run AURIC_CREDITS.sql first if you haven't.)
-- ════════════════════════════════════════════════════════════════════

create or replace function public.auric_credit_set_expiry(
  pass      text,
  cid       bigint,
  p_expires date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;

  update public.auric_credits
     set expires_at = p_expires
   where id = cid;
end;
$$;

revoke all on function public.auric_credit_set_expiry(text, bigint, date) from public, anon;
grant execute on function public.auric_credit_set_expiry(text, bigint, date) to authenticated;

select 'ready — the Credits tab can now set an expiry on older credits.' as status;
