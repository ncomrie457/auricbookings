-- ─────────────────────────────────────────────────────────────────────────
-- Founding One: stop a transferred booking stealing the badge
--
-- THE PROBLEM
--   "Founding One" goes to whoever booked a date first. The roster works that
--   out from created_at — the moment the booking was made.
--
--   Moving someone between dates (⇄ Move event) changes their event and
--   session but NOT created_at. So a person who booked Sep 26 back in August
--   and then got moved to Oct 10 carries an August timestamp onto a date that
--   only went on sale in September. They land ahead of everyone who actually
--   booked Oct 10, and take the badge from the person who earned it.
--
--   Worse: the "already gifted" memory is keyed by email + event + session.
--   Move someone and that key changes, so a person who ALREADY received the
--   Founding One gift for Sep 26 reappears as a fresh Founding One on Oct 10
--   and could be sent a second one.
--
-- THE FIX
--   Record when a booking was moved. A row that was moved onto this date did
--   not book this date first, so it is left out of the running. Whatever they
--   earned on their original date, they keep.
--
-- WHEN TO RUN: once, in Supabase → SQL Editor. Safe to re-run.
-- ─────────────────────────────────────────────────────────────────────────

-- 1) A column recording when (and whether) a booking was moved here.
--    NULL means "booked this date directly" — the normal case.
alter table public.reformer_registrations
  add column if not exists moved_at timestamptz;

comment on column public.reformer_registrations.moved_at is
  'Set when a booking is moved to a different event via reformer_move(). '
  'A non-null value means this person did not book this date first, so they '
  'are not eligible for Founding One on it.';

-- 2) Teach the move function to stamp it.
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
         session_label = coalesce(new_session_label, session_label),
         -- They did not book the new date first; record that.
         moved_at      = now()
   where id = rid;
end;
$$;

revoke all on function public.reformer_move(text, bigint, text, text, text) from public, anon;

-- 3) Check it took. Expected: the column exists and every existing row is
--    NULL, because nothing has been moved yet.
select
  count(*)                                as total_rows,
  count(moved_at)                         as moved_so_far,
  count(*) - count(moved_at)              as booked_directly
from public.reformer_registrations;

-- 4) And who currently holds Founding One on each upcoming date, under the
--    new rule. Anyone listed here booked that date directly, has paid, and
--    has not cancelled or no-showed.
select distinct on (event, session)
       event, session, name, email, created_at
from public.reformer_registrations
where is_paid
  and moved_at is null
  and coalesce(type, '') <> 'waitlist'
  and not coalesce(archived, false)
  and coalesce(attendance, '') <> 'noshow'
order by event, session, created_at, id;
