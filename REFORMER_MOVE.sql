-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — "Move a booking to another event"
--
--  WHY: the admin roster already lets you move someone between sessions of
--  the SAME event (reformer_set_session). This adds reformer_move, which
--  changes the EVENT too — e.g. a no-show at West Hempstead rebooked onto
--  the Brooklyn 12 PM session. Their paid status and waiver stay with them.
--
--  Owner-only: gated by is_owner(), same as every other reformer_* write.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.reformer_move(
  pass text,
  rid bigint,
  new_event text,
  new_session text,
  new_session_label text
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

  update public.reformer_registrations
     set event         = new_event,
         session       = new_session,
         session_label = coalesce(new_session_label, session_label)
   where id = rid;
end;
$$;

revoke all on function public.reformer_move(text, bigint, text, text, text) from public, anon;
grant execute on function public.reformer_move(text, bigint, text, text, text) to authenticated;

select 'reformer_move ready — the "⇄ Move event" button now works.' as status;
