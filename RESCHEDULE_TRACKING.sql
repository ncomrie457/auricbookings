-- ─────────────────────────────────────────────────────────────────────────
-- Show, on a roster, who was moved there from another date
--
-- WHY
--   When a date gets rained out and everyone moves — Sep 26 to Oct 10 —
--   the Oct 10 roster ends up holding two different kinds of people: those
--   who booked Oct 10, and those who were moved onto it. They look
--   identical, which makes it hard to know who to write to, who is owed an
--   explanation, and who booked the date on purpose.
--
--   moved_at already records THAT a booking was moved (it is what keeps a
--   transfer from taking Founding One off the person who earned it).
--   It does not record where from.
--
-- WHAT THIS DOES
--   Adds moved_from, and teaches ⇄ Move to stamp the date they came from.
--   The admin roster then badges those rows "⇄ Moved from Sep 26".
--
-- SAFE TO RE-RUN. Safe whether or not you ran FOUNDING_ONE_RULE.sql —
-- this adds both columns and replaces the same function, so running this
-- alone is enough.
-- ─────────────────────────────────────────────────────────────────────────

-- 1) The two columns. NULL in both means "booked this date directly",
--    which is the normal case and what every existing row will read.
alter table public.reformer_registrations
  add column if not exists moved_at   timestamptz,
  add column if not exists moved_from text;

comment on column public.reformer_registrations.moved_at is
  'Set when a booking is moved to a different event via reformer_move(). '
  'A non-null value means this person did not book this date first, so they '
  'are not eligible for Founding One on it.';

comment on column public.reformer_registrations.moved_from is
  'The event id this booking was FIRST moved away from. Set once and kept, '
  'so a booking moved twice still shows where it originally came from.';

-- 2) Teach the move function to record both.
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
     -- Every expression here reads the row as it was BEFORE this update, so
     -- `event` on the right is still the date they are leaving. coalesce
     -- keeps the FIRST origin: someone moved Sep 26 -> Oct 10 -> Nov 21 still
     -- reads "from Sep 26", which is the date that actually explains them.
     set moved_from    = coalesce(moved_from, event),
         moved_at      = now(),
         event         = new_event,
         session       = new_session,
         session_label = coalesce(new_session_label, session_label)
   where id = rid;
end;
$$;

revoke all on function public.reformer_move(text, bigint, text, text, text) from public, anon;

-- ─── Checks ──────────────────────────────────────────────────────────────

-- 3) Did the columns land? Expect every row under booked_directly until you
--    move someone; rows moved before today will show moved_at but no origin,
--    because nothing was recording it yet.
select count(*)                                     as total_rows,
       count(moved_at)                              as moved_ever,
       count(moved_from)                            as origin_known,
       count(*) - count(moved_at)                   as booked_directly
from public.reformer_registrations;

-- 4) Who is on Oct 10 because Sep 26 was rained out. Run this after you have
--    moved everyone — it is the list to check your email against.
select name, email, session_label, moved_at
from public.reformer_registrations
where event = 'riddim-kompa-brooklyn-2026-10-10'
  and moved_from = 'riddim-kompa-brooklyn-2026-09-26'
  and not coalesce(archived, false)
order by moved_at, id;

-- 5) IF THE BADGE DOES NOT SHOW UP, it is this: the admin roster reads through
--    reformer_roster(), and if that function lists its columns explicitly
--    rather than using select *, the new column never reaches the page.
--    This prints the function. If you see a column list rather than `select *`,
--    send it over and the two new columns can be added to it.
select pg_get_functiondef(p.oid) as reformer_roster_definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'reformer_roster';
