-- ════════════════════════════════════════════════════════════════════
--  Archived bookings are still holding seats
--
--  THE SYMPTOM: you archive somebody, the roster drops them, and the
--  booking page still says "Join waitlist" for that time. Domenica was
--  archived off Nov 22 at 11:30 and the seat never came back, so
--  Angelina sat on the waitlist next to an empty reformer.
--
--  THE CAUSE: the booking page gets its seat numbers from one function,
--  reformer_spot_counts(). Every other place that counts a roster
--  excludes archived rows — the admin sections, the reminder list, the
--  Founding One, the audit. That function appears not to, so an
--  archived row keeps occupying a seat that nobody can book.
--
--  WHY THIS IS NOT VISIBLE FROM THE REPOSITORY: the function lives in
--  the database, not in this repo. A corrected version was written down
--  in RIDDIM_KOMPA_NEW_DATES.sql and left commented out, so it was
--  never applied. Section 1 below checks what is actually running
--  before you change anything.
--
--  HOW TO RUN: Supabase → SQL Editor. Run section 1 first and read it.
--  Run section 2 only if section 1 says the archived filter is missing.
--  Section 3 proves it worked.
-- ════════════════════════════════════════════════════════════════════


-- ─── 1) WHAT IS ACTUALLY RUNNING? ────────────────────────────────────
--  Read-only. Prints the live function. Look in the body for the word
--  "archived": if it is not there, that is the bug, and section 2 is
--  the fix. If it IS there, stop — the cause is something else and the
--  seat counts below will tell you what.
select pg_get_functiondef(p.oid) as live_definition
from   pg_proc p
join   pg_namespace n on n.oid = p.pronamespace
where  n.nspname = 'public'
  and  p.proname = 'reformer_spot_counts';

--  And the same numbers, counted both ways, for the dates still to come.
--  "counted_now" is what the booking page believes. "should_be" excludes
--  archived rows. Where the two differ, that difference is seats the
--  page is refusing to sell.
select r.event,
       r.session,
       min(r.session_label)                                     as time,
       count(*) filter (where coalesce(r.is_paid,false)
                          and coalesce(r.type,'') <> 'waitlist') as counted_now,
       count(*) filter (where coalesce(r.is_paid,false)
                          and coalesce(r.type,'') <> 'waitlist'
                          and coalesce(r.archived,false) = false) as should_be,
       count(*) filter (where coalesce(r.archived,false))        as archived_rows,
       count(*) filter (where r.type = 'waitlist')               as waiting
from   public.reformer_registrations r
where  r.event in ('turkey-burn-2026-11-22','riddim-kompa-brooklyn-2026-11-21')
group  by r.event, r.session
order  by r.event, r.session;


-- ─── 2) THE FIX ──────────────────────────────────────────────────────
--  One added line: archived rows stop counting. Everything else is the
--  same contract the page already relies on — same name, same returned
--  columns (session, paid), same grants — so nothing else has to change
--  and the page picks it up on the next load.
--
--  Note it still counts across ALL events, not per event, because that
--  is how the page calls it: each booking overlay asks for the whole
--  table and reads out only its own session keys. Session keys are
--  unique per date (tb1130, n12, hw1130 …), so they do not collide.
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


-- ─── 3) DID IT WORK? ─────────────────────────────────────────────────
--  Read-only. Run after section 2. For every upcoming session this
--  shows what the booking page will now say, against the cap the page
--  enforces, so you can see the seat come back before you tell anyone
--  it has.
--
--  Caps, as set in index.html: Nov 21 Brooklyn = 5, Nov 22 = 6.
with counts as (select * from public.reformer_spot_counts())
select r.event,
       r.session,
       min(r.session_label) as time,
       coalesce(max(c.paid), 0) as paid_after_fix,
       case r.event
         when 'riddim-kompa-brooklyn-2026-11-21' then 5
         when 'turkey-burn-2026-11-22'           then 6
       end as cap,
       case r.event
         when 'riddim-kompa-brooklyn-2026-11-21' then 5
         when 'turkey-burn-2026-11-22'           then 6
       end - coalesce(max(c.paid), 0) as seats_left,
       count(*) filter (where r.type = 'waitlist') as waiting
from   public.reformer_registrations r
left   join counts c on c.session = r.session
where  r.event in ('turkey-burn-2026-11-22','riddim-kompa-brooklyn-2026-11-21')
group  by r.event, r.session
order  by r.event, r.session;

--  A session showing seats_left > 0 with waiting > 0 is somebody who
--  can be let in right now. Send them the booking link rather than a
--  Stripe link — the booking flow is what collects the waiver, the
--  health disclosure and the refund acknowledgement:
--      https://book.auricmovement.com/?book=turkey
