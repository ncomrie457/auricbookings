-- ════════════════════════════════════════════════════════════════════
--  THREE FIXES IN ONE PASTE
--
--  Each of these has its own file in this repository and none of them
--  was ever run, so each is still broken in the live database. They are
--  gathered here so it is one trip to the SQL Editor instead of three.
--
--  (The filename says THREE. It is four now — the name is kept only
--   because the admin panel's error messages point at it by name.)
--
--  WHAT IT FIXES
--    0. The Auric Club does not show reformer guests. Ticking somebody
--       "✓ Attended" is what earns a Club mark, and the column and
--       function behind those buttons were never created — so nobody
--       from Riddim & Kompa, Halloween or Turkey Burn can be ticked,
--       and none of them can appear in the Club. This is almost
--       certainly what you are looking at right now.
--    1. "+½ ref" says: run REFORMER_REFERRAL.sql first.
--       The function it calls does not exist, so no reformer attendee
--       can be credited for referring a friend.
--    2. Archived bookings still hold their seat. Archive somebody and
--       the booking page keeps saying Join waitlist for a reformer that
--       is standing empty — this is what put Angelina on a waitlist.
--    3. Moving somebody between dates leaves no record, so a moved
--       booking keeps its original timestamp and takes Founding One
--       from whoever actually booked that date first.
--
--  SAFE TO RUN TWICE. Every statement is additive or a create-or-
--  replace. It adds no rows, deletes no rows, and changes nobody's
--  booking. Section 4 only reads.
--
--  HOW TO RUN: Supabase → SQL Editor → New query → paste ALL of this →
--  Run. It is one transaction's worth of work and takes a second.
--
--  Then read section 6's output, and do section 7 by hand if you still
--  want Danielle off Founding One.
-- ════════════════════════════════════════════════════════════════════


-- ─── 1) COLUMNS ──────────────────────────────────────────────────────
--  All three, before anything reads them. The ordering matters: a
--  previous version of the reschedule file put its diagnostics above
--  the columns they selected and failed on its own first run.
alter table public.reformer_registrations
  add column if not exists attendance text,
  add column if not exists winner     boolean not null default false,
  add column if not exists referrals  integer not null default 0,
  add column if not exists moved_at   timestamptz,
  add column if not exists moved_from text;


-- ─── 2) THE "✓ Attended" BUTTONS, AND THE AURIC CLUB ─────────────────
--  Attendance is what earns a Club mark. Without this the roster's
--  tick buttons have nothing to write to, so no reformer guest can be
--  marked and none of them reach the Club.
create or replace function public.reformer_set_attendance(
  pass text,
  rid  bigint,
  val  text
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

  if val is not null and val <> '' and val not in ('attended','noshow') then
    raise exception 'attendance must be attended, noshow, or empty';
  end if;

  update public.reformer_registrations
     set attendance = nullif(val, '')
   where id = rid;
end;
$$;

revoke all on function public.reformer_set_attendance(text, bigint, text) from public, anon;
grant execute on function public.reformer_set_attendance(text, bigint, text) to authenticated;

--  The public "check my marks" lookup. Returns a single number and no
--  rows, so it can be called from the public page without exposing who
--  attended anything. Counts DISTINCT events, so somebody who booked
--  two sessions of one date still earns one mark.
create or replace function public.reformer_club_marks(p_email text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(count(distinct event), 0)::integer
    from public.reformer_registrations
   where attendance = 'attended'
     and p_email is not null
     and lower(email) = lower(trim(p_email));
$$;

grant execute on function public.reformer_club_marks(text) to anon, authenticated;

--  The prize-drawing winner flag, from the same file — the 🎟 Winner
--  button on the roster writes through this.
create or replace function public.reformer_set_winner(
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
     set winner = coalesce(val, false)
   where id = rid;
end;
$$;

revoke all on function public.reformer_set_winner(text, bigint, boolean) from public, anon;
grant execute on function public.reformer_set_winner(text, bigint, boolean) to authenticated;


-- ─── 3) THE "+½ ref" BUTTON ──────────────────────────────────────────
--  Owner-only. delta +1 adds a referral, -1 takes one back, and it
--  never goes below zero. Each referral is worth half a mark, matching
--  how the other events count.
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


-- ─── 4) ARCHIVED ROWS STOP HOLDING SEATS ─────────────────────────────
--  One added line against the live version: archived rows no longer
--  count. Same name, same returned columns, same grants, so the booking
--  page picks it up on its next load with nothing else to change.
--
--  It still counts across ALL events rather than per event, because
--  that is how the page calls it: each booking overlay asks for the
--  whole table and reads out only its own session keys, which are
--  unique per date (tb1130, n12, hw1130 …) and so cannot collide.
create or replace function public.reformer_spot_counts()
returns table (session text, paid bigint)
language sql
stable
security definer
set search_path = public
as $$
  select r.session,
         count(*)::bigint as paid
  from   public.reformer_registrations r
  where  coalesce(r.is_paid, false) = true
    and  coalesce(r.type, '') <> 'waitlist'
    and  coalesce(r.archived, false) = false   -- ← the fix
  group  by r.session;
$$;

grant execute on function public.reformer_spot_counts() to anon, authenticated;


-- ─── 5) MOVES GET RECORDED FROM NOW ON ───────────────────────────────
--  Every expression below reads the row as it was BEFORE the update, so
--  `event` on the right is still the date they are leaving. coalesce
--  keeps the FIRST origin: somebody moved Sep 26 → Oct 10 → Nov 21
--  still reads "from Sep 26", which is the date that explains them.
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


-- ─── 6) DID IT WORK? ─────────────────────────────────────────────────
--  Read-only. Three answers, in order.

--  6a. All three functions should be listed, and reformer_spot_counts
--      should say true under has_archived_filter.
select p.proname                                            as function_name,
       case when p.proname = 'reformer_spot_counts'
            then position('archived' in pg_get_functiondef(p.oid)) > 0
       end                                                  as has_archived_filter,
       case when p.proname = 'reformer_move'
            then position('moved_at' in pg_get_functiondef(p.oid)) > 0
       end                                                  as records_moves
from   pg_proc p
join   pg_namespace n on n.oid = p.pronamespace
where  n.nspname = 'public'
  and  p.proname in ('reformer_set_attendance','reformer_club_marks','reformer_set_winner',
                     'reformer_set_referral','reformer_spot_counts','reformer_move')
order  by p.proname;

--  6b. The three columns should all be present.
select column_name, data_type
from   information_schema.columns
where  table_schema = 'public'
  and  table_name   = 'reformer_registrations'
  and  column_name in ('attendance','winner','referrals','moved_at','moved_from')
order  by column_name;

--  6c. Seats that just came back. Any row where counted_before is
--      higher than counts_now is a seat the page was refusing to sell.
select r.event,
       r.session,
       min(r.session_label)                                   as time,
       count(*) filter (where coalesce(r.is_paid,false)
                          and coalesce(r.type,'') <> 'waitlist')               as counted_before,
       count(*) filter (where coalesce(r.is_paid,false)
                          and coalesce(r.type,'') <> 'waitlist'
                          and coalesce(r.archived,false) = false)              as counts_now,
       count(*) filter (where r.type = 'waitlist')                             as waiting
from   public.reformer_registrations r
group  by r.event, r.session
having count(*) filter (where coalesce(r.is_paid,false)
                          and coalesce(r.type,'') <> 'waitlist')
     > count(*) filter (where coalesce(r.is_paid,false)
                          and coalesce(r.type,'') <> 'waitlist'
                          and coalesce(r.archived,false) = false)
order  by r.event, r.session;


-- ─── 7) THE ONE THING THIS CANNOT DO FOR YOU ─────────────────────────
--  Section 5 records moves from here on. A move made BEFORE it left no
--  trace, and the database cannot work out on its own who was moved —
--  so Danielle has to be named.
--
--  Run 7a, read it, then uncomment 7b with her id. Doing it by id, not
--  by name, so it cannot catch somebody else with the same first name.

--  7a. Find her. Read the email before changing anything.
select id, name, email, event, session, session_label, created_at, moved_at, moved_from
from   public.reformer_registrations
where  event = 'riddim-kompa-brooklyn-2026-11-21'
  and  name ilike '%danielle%'
order  by created_at;

--  7b. Stamp her as moved from Sep 26. Put the id from 7a in place of
--      <ID>. moved_at is set to her created_at rather than now(): she
--      was moved some time in the past, and claiming it happened today
--      would be a second wrong fact in the same row.
--
-- update public.reformer_registrations
--    set moved_from = 'riddim-kompa-brooklyn-2026-09-26',
--        moved_at   = coalesce(moved_at, created_at)
--  where id = <ID>;


-- ─── 8) ONE THING TO WATCH ───────────────────────────────────────────
--  The Club list reads the roster through reformer_roster(). If that
--  function selects columns by name rather than *, it will not return
--  the new `referrals` column and the count will not show even though
--  the button now works. This prints its definition — look for
--  `referrals` or a bare `select *`.
select pg_get_functiondef(p.oid) as reformer_roster_definition
from   pg_proc p
join   pg_namespace n on n.oid = p.pronamespace
where  n.nspname = 'public' and p.proname = 'reformer_roster';
