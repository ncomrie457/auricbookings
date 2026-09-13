-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — "Archive a registration" (started signing up, didn't pay)
--
--  WHY: the admin roster fills up with people who began a booking but never
--  paid. This lets you ARCHIVE them — they drop off the active roster and out
--  of the paid/registered counts, but nothing is deleted. They appear in the
--  "🗄️ Archived — didn't pay" section, where you can Unarchive or Remove them.
--
--  Owner-only: gated by is_owner(), same as every other reformer_* write.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

-- 1) Add the flag (defaults to false, so every existing row stays on the roster).
alter table public.reformer_registrations
  add column if not exists archived boolean not null default false;

-- 2) Owner-only setter used by the "🗄️ Archive" / "↩️ Unarchive" buttons.
create or replace function public.reformer_archive(
  pass text,
  rid  bigint,
  val  boolean
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
     set archived = coalesce(val, false)
   where id = rid;
end;
$$;

revoke all on function public.reformer_archive(text, bigint, boolean) from public, anon;
grant execute on function public.reformer_archive(text, bigint, boolean) to authenticated;

-- 3) IMPORTANT: the roster must return the new column so the admin panel can
--    see who's archived. If your reformer_roster() function uses SELECT * this
--    already works — nothing else to do. If it lists columns explicitly, add
--    `archived` to its SELECT (and to its RETURNS TABLE(...) if it has one).

select 'reformer_archive ready — the "🗄️ Archive" button now works.' as status;
