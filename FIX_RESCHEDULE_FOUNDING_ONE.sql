-- ════════════════════════════════════════════════════════════════════
--  A rescheduled booking is taking Founding One
--
--  THE SYMPTOM: Danielle was moved from Sep 26 to Nov 21 and the Nov 21
--  roster shows her as Founding One. She did not book Nov 21 first —
--  she did not book it at all. Her booking carries its ORIGINAL Sep 26
--  timestamp, which is older than everybody who really did book Nov 21,
--  so she sorts to the front and takes the badge.
--
--  THE CAUSE: the site already refuses to give Founding One to a moved
--  booking. It decides that by looking at moved_at, which ⇄ Move is
--  supposed to stamp. There are two versions of reformer_move() in this
--  repository — the original in REFORMER_MOVE.sql, which only changes
--  the date, and the one in RESCHEDULE_TRACKING.sql, which also records
--  the move. If the original is what is running, every move made so far
--  left no trace, and those bookings look like original bookings.
--
--  So this is two repairs, not one: teach the function to record a move
--  from now on, and stamp the moves already made.
--
--  HOW TO RUN: Supabase → SQL Editor, in order. Run 0 and 1, read 1,
--  then 2, then 3, then 4.
-- ════════════════════════════════════════════════════════════════════


-- ─── 0) THE TWO COLUMNS ──────────────────────────────────────────────
--  First, because section 1 reads them. Additive and safe to re-run: on a
--  database that already has them this does nothing at all. NULL in both
--  means "booked this date directly", which is what every existing row
--  will read until section 3 says otherwise.
alter table public.reformer_registrations
  add column if not exists moved_at   timestamptz,
  add column if not exists moved_from text;


-- ─── 1) WHAT IS RUNNING, AND WHO HOLDS THE BADGE ─────────────────────
--  Read-only. Look in the printed function for "moved_at": if it is not
--  there, that is the bug and section 2 is the fix.
select pg_get_functiondef(p.oid) as live_move_function
from   pg_proc p
join   pg_namespace n on n.oid = p.pronamespace
where  n.nspname = 'public' and p.proname = 'reformer_move';

--  Who the site currently calls Founding One on each upcoming session,
--  and whether anything is on record as moved. The site picks the
--  earliest paid, non-comped, non-archived, non-waitlisted, non-moved
--  booking — so "rank 1" below is who wears the badge today.
select r.event, r.session, r.name, r.email,
       r.created_at,
       r.moved_at,
       r.moved_from,
       rank() over (partition by r.event, r.session order by r.created_at) as rank
from   public.reformer_registrations r
where  r.event in ('riddim-kompa-brooklyn-2026-11-21','turkey-burn-2026-11-22')
  and  coalesce(r.is_paid,false)
  and  coalesce(r.archived,false) = false
  and  coalesce(r.type,'') <> 'waitlist'
  and  coalesce(r.comp,false) = false
  and  r.moved_at is null
order  by r.event, r.session, r.created_at;


-- ─── 2) RECORD MOVES FROM NOW ON ─────────────────────────────────────
--  The function from RESCHEDULE_TRACKING.sql. Safe to re-run, and safe
--  whether or not that file was ever applied.
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
     -- Every expression reads the row as it was BEFORE this update, so
     -- `event` on the right is still the date they are leaving. coalesce
     -- keeps the FIRST origin: someone moved Sep 26 -> Oct 10 -> Nov 21
     -- still reads "from Sep 26", which is the date that explains them.
     set moved_from    = coalesce(moved_from, event),
         moved_at      = now(),
         event         = new_event,
         session       = new_session,
         session_label = coalesce(new_session_label, session_label)
   where id = rid;
end;
$$;

revoke all on function public.reformer_move(text, bigint, text, text, text) from public, anon;
grant execute on function public.reformer_move(text, bigint, text, text, text) to authenticated;


-- ─── 3) STAMP THE MOVES ALREADY MADE ─────────────────────────────────
--  Section 2 only helps from here on. A move made before it leaves no
--  record, and the database cannot work out on its own who was moved —
--  so they have to be named.
--
--  3a. Find the row. Read the id and the email before changing anything:
--      if two people share a first name, this is where you see it.
select id, name, email, event, session, session_label, created_at, moved_at, moved_from
from   public.reformer_registrations
where  event = 'riddim-kompa-brooklyn-2026-11-21'
  and  name ilike '%danielle%'
order  by created_at;

--  3b. Stamp her as moved from Sep 26. Put the id from 3a in place of
--      <ID>. Doing it by id, not by name, so it cannot catch anyone else.
--
--      moved_at is set to her created_at rather than now(): she was moved
--      some time in the past and claiming it happened today would be a
--      second wrong fact in the same row.
--
-- update public.reformer_registrations
--    set moved_from = 'riddim-kompa-brooklyn-2026-09-26',
--        moved_at   = coalesce(moved_at, created_at)
--  where id = <ID>;


-- ─── 4) WHO HOLDS IT NOW ─────────────────────────────────────────────
--  Read-only. Run after 3b. The same test the site uses, so rank 1 is
--  who the roster will badge once the page is reloaded.
select r.event, r.session, r.name, r.created_at,
       rank() over (partition by r.event, r.session order by r.created_at) as rank
from   public.reformer_registrations r
where  r.event = 'riddim-kompa-brooklyn-2026-11-21'
  and  coalesce(r.is_paid,false)
  and  coalesce(r.archived,false) = false
  and  coalesce(r.type,'') <> 'waitlist'
  and  coalesce(r.comp,false) = false
  and  r.moved_at is null
order  by r.session, r.created_at;

--  And everyone now on record as moved, so the badge "⇄ Moved from …"
--  on the roster can be checked against what actually happened.
select id, name, event, session, moved_from, moved_at
from   public.reformer_registrations
where  moved_at is not null
order  by moved_at desc;
