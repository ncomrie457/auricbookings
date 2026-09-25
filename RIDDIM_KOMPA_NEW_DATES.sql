-- ════════════════════════════════════════════════════════════════════════
--  Riddim & Kompa on the Reformer — Brooklyn
--  Saturday, October 10 and Saturday, November 21, 2026
--  Maison Luxe Wellness Pilates · four sessions each · $45 · cap 5
--  ─────────────────────────────────────────────────────────────────────
--
--  READ THIS FIRST — there is probably nothing here you have to run.
--
--  These two dates need NO new table and NO new column. A reformer event
--  is just a value in the `event` text column of reformer_registrations,
--  the way Sept 13, Sept 26, Halloween and Turkey Burn already are. There
--  is no enum and no CHECK constraint listing the allowed events, and
--  reformer_move takes the event and session as free text. So the rows
--  will simply appear the first time somebody books.
--
--  What this file IS for: checking the one assumption the site depends on
--  that I cannot see from the code — how reformer_spot_counts behaves.
--  Run section 1. If it says everything is fine, you are done and can
--  ignore the rest.
--
--  Safe to run: sections 1 and 3 only READ. Section 2 changes a function
--  and is commented out — only use it if section 1 tells you to.
-- ════════════════════════════════════════════════════════════════════════


-- ─── 1) CHECK ─────────────────────────────────────────────────────────
--  Everything here is read-only. Run the whole section and read the
--  `verdict` column of each result.

-- 1a. Is anything constraining which events or sessions are allowed?
--     Expect: no rows. Any row here means the new dates would be rejected.
select 'constraints on event/session' as check,
       con.conname,
       pg_get_constraintdef(con.oid) as definition,
       'INVESTIGATE — this may reject the new dates' as verdict
from   pg_constraint con
join   pg_class rel on rel.oid = con.conrelid
join   pg_namespace ns on ns.oid = rel.relnamespace
where  ns.nspname = 'public'
  and  rel.relname = 'reformer_registrations'
  and  con.contype = 'c'
  and  pg_get_constraintdef(con.oid) ~* '(event|session)';

-- 1b. The session keys already in your data, and the new ones.
--     The site's seat counter groups by session name with NO event
--     column, so two events sharing a session key would share a seat
--     count — each would show the other's bookings as sold out.
--     Expect: verdict 'ok' on every row.
with new_keys(session, for_date) as (
  values ('o12','Oct 10'), ('o1','Oct 10'), ('o2','Oct 10'), ('o3','Oct 10'),
         ('n12','Nov 21'), ('n1','Nov 21'), ('n2','Nov 21'), ('n3','Nov 21')
)
select 'session key collision' as check,
       n.session,
       n.for_date,
       count(r.*) filter (where r.event not in ('riddim-kompa-brooklyn-2026-10-10',
                                               'riddim-kompa-brooklyn-2026-11-21')) as used_by_another_event,
       case when count(r.*) filter (where r.event not in ('riddim-kompa-brooklyn-2026-10-10',
                                                          'riddim-kompa-brooklyn-2026-11-21')) = 0
            then 'ok' else 'COLLISION — this key is already in use' end as verdict
from   new_keys n
left join public.reformer_registrations r on r.session = n.session
group by n.session, n.for_date
order by n.for_date desc, n.session;

-- 1c. What does reformer_spot_counts actually do?
--     This is the one function the booking page relies on that isn't in
--     the repo. Read the definition that comes back and check it does NOT
--     name specific sessions or events. If it lists them (something like
--     `where session in ('1pm','2pm','bk12', …)`), the new sessions will
--     always report zero booked and will never sell out — run section 2.
select 'reformer_spot_counts definition' as check,
       pg_get_functiondef(p.oid) as definition
from   pg_proc p
join   pg_namespace n on n.oid = p.pronamespace
where  n.nspname = 'public' and p.proname = 'reformer_spot_counts';

-- 1d. What it returns right now, with the new sessions marked.
--     Before anyone books the new dates these simply won't appear — that
--     is expected. After the first booking, o12/o1/o2/o3 and n12/n1/n2/n3
--     must show up here. If they don't, run section 2.
select 'spot counts today' as check, *,
       case when session in ('o12','o1','o2','o3','n12','n1','n2','n3')
            then 'new date' else '' end as note
from   public.reformer_spot_counts()
order  by session;


-- ─── 2) ONLY IF SECTION 1 SAID TO ────────────────────────────────────
--  A version of reformer_spot_counts that names no sessions and no
--  events, so it keeps working for every date you ever add without
--  being edited again. It returns the same two columns the booking
--  page reads (session, paid), grouped the same way, so nothing else
--  has to change.
--
--  Only uncomment this if 1c showed a hardcoded list or 1d is missing
--  the new sessions. If your existing function returns a different set
--  of columns, Postgres will refuse to replace it and tell you so —
--  that is safe, nothing will be half-changed. Send me the error.
--
--  Waitlist rows and archived rows are excluded on purpose: a waitlister
--  has not taken a seat, and an archived row is someone who started and
--  never paid. Counting either would sell out a class that isn't full.

-- drop function if exists public.reformer_spot_counts();
-- create or replace function public.reformer_spot_counts()
-- returns table (session text, paid bigint)
-- language sql
-- stable
-- security definer
-- set search_path = public
-- as $$
--   select r.session,
--          count(*)::bigint as paid
--   from   public.reformer_registrations r
--   where  coalesce(r.is_paid, false) = true
--     and  coalesce(r.type, '') <> 'waitlist'
--     and  coalesce(r.archived, false) = false
--   group  by r.session;
-- $$;
-- grant execute on function public.reformer_spot_counts() to anon, authenticated;


-- ─── 3) AFTER THE FIRST BOOKINGS ─────────────────────────────────────
--  Read-only. Run this once people start booking to see the two dates
--  side by side, and to confirm they are counted separately.

select case r.event
         when 'riddim-kompa-brooklyn-2026-10-10' then 'Sat Oct 10'
         when 'riddim-kompa-brooklyn-2026-11-21' then 'Sat Nov 21'
         else r.event end                                    as date,
       r.session,
       min(r.session_label)                                  as time,
       count(*)                                              as registered,
       count(*) filter (where coalesce(r.is_paid,false))     as paid,
       5 - count(*) filter (where coalesce(r.is_paid,false)) as seats_left,
       count(*) filter (where r.type = 'waitlist')           as waitlist
from   public.reformer_registrations r
where  r.event in ('riddim-kompa-brooklyn-2026-10-10',
                   'riddim-kompa-brooklyn-2026-11-21')
  and  coalesce(r.archived, false) = false
group  by r.event, r.session
order  by date, r.session;

-- Anyone who booked more than one of your dates. Worth knowing, because
-- the Stripe webhook currently matches a payment to a person by email
-- alone across every reformer event — so these are exactly the people
-- whose payment can land on the wrong row.
select lower(trim(r.email))              as email,
       min(r.name)                       as name,
       count(distinct r.event)           as dates_booked,
       string_agg(distinct r.event, ', ' order by r.event) as which
from   public.reformer_registrations r
where  coalesce(r.archived, false) = false
  and  coalesce(r.type,'') <> 'waitlist'
  and  r.email is not null
group  by lower(trim(r.email))
having count(distinct r.event) > 1
order  by dates_booked desc, email;


-- ─── 4) DOES THE PAID COLUMN LOOK RIGHT? ─────────────────────────────
--  Read this honestly: none of these queries talks to Stripe. is_paid is
--  whatever the webhook wrote, so if a payment was filed against the
--  wrong row, every query above will report that wrong row as paid and
--  look perfectly healthy.
--
--  What these three CAN do is catch the shape the webhook bug leaves
--  behind. It matches a payment to a person by email alone across every
--  reformer event, takes the most recent unpaid row, and returns an
--  error to Stripe if the confirmation email fails — so Stripe retries,
--  and the retry walks onto the NEXT matching row. One payment, several
--  rows marked paid, several confirmations sent.
--
--  Every one of these should come back empty. A row in any of them is
--  worth checking against Stripe by hand before you chase anyone.

-- 4a. One email, several paid spots in the same session.
--     This is NOT automatically a problem: booking for yourself and a
--     friend under one email is a normal thing to do, and it is two real
--     payments. So the query sorts them by whether the names differ.
--
--       different names  -> almost certainly one person booking for
--                           someone else. Two people, two charges. Fine.
--       same name twice  -> either they really did buy two spots under
--                           their own name, or one payment was counted
--                           twice. Only Stripe can tell you which:
--                           count the charges on that email for that day.
select 'one email, several paid spots in one session' as finding,
       r.event, r.session, lower(trim(r.email)) as email,
       count(*)                     as paid_rows,
       count(distinct lower(trim(r.name))) as distinct_names,
       string_agg(distinct r.name, ' + ' order by r.name) as names,
       case when count(distinct lower(trim(r.name))) = count(*)
            then 'looks like booking for someone else — expect this many charges'
            else 'SAME NAME TWICE — check Stripe for how many charges'
       end as verdict,
       string_agg(to_char(r.created_at,'Mon DD HH24:MI'), ' | ' order by r.created_at) as booked_at
from   public.reformer_registrations r
where  coalesce(r.is_paid,false)
  and  coalesce(r.archived,false) = false
  and  coalesce(r.type,'') <> 'waitlist'
group  by r.event, r.session, lower(trim(r.email))
having count(*) > 1
order  by (count(distinct lower(trim(r.name))) = count(*)), paid_rows desc;

-- 4b. One email paid across several sessions of the SAME date.
--     Same caveat: a person can legitimately book the 12 PM for a friend
--     and the 1 PM for themselves. But this is also the exact shape the
--     webhook retry leaves, because it cannot tell which session a
--     payment was for and walks onto the next matching row. Compare the
--     number of charges on Stripe against paid_rows below.
select 'one email paid across several sessions of one date' as finding,
       r.event, lower(trim(r.email)) as email,
       count(*)                            as paid_rows,
       count(distinct r.session)           as sessions_paid,
       count(distinct lower(trim(r.name))) as distinct_names,
       string_agg(distinct r.name, ' + ' order by r.name)   as names,
       string_agg(distinct r.session, ', ' order by r.session) as which,
       case when count(distinct lower(trim(r.name))) > 1
            then 'different names — probably a real second booking'
            else 'one name across sessions — check Stripe charge count'
       end as verdict
from   public.reformer_registrations r
where  coalesce(r.is_paid,false)
  and  coalesce(r.archived,false) = false
  and  coalesce(r.type,'') <> 'waitlist'
group  by r.event, lower(trim(r.email))
having count(distinct r.session) > 1
order  by sessions_paid desc;

-- 4c. More paid than the room holds.
--     The five-seat cap is enforced in the browser only — a direct
--     Stripe link, or two people paying at the same moment, can go past
--     it. Compare against what the studio can actually take.
select 'more paid than seats' as finding,
       r.event, r.session, min(r.session_label) as time,
       count(*) filter (where coalesce(r.is_paid,false)) as paid,
       5 as cap
from   public.reformer_registrations r
where  coalesce(r.archived,false) = false
  and  coalesce(r.type,'') <> 'waitlist'
group  by r.event, r.session
having count(*) filter (where coalesce(r.is_paid,false)) > 5
order  by paid desc;
