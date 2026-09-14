-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — why isn't someone showing in the Auric Club?
--
--  Run these one at a time in Supabase → SQL Editor. Nothing here writes
--  anything; every query only reads. Replace 'amanda' in queries 1 and 2
--  with whoever you're looking for.
--
--  The Club counts two different things:
--    • Mat & Chat / Pilates / Create & Recharge — an "#attended" tag
--      inside that row's admin_notes column.
--    • Riddim & Kompa / Halloween / Turkey Burn — attendance = 'attended'
--      on the reformer_registrations row.
--  If either one is missing, that half of a person's marks is missing.
-- ════════════════════════════════════════════════════════════════════

-- 1) Her reformer bookings. attendance should read 'attended'.
--    If it is null, the ✓ Attended button never saved for that row.
select id, event, name, email, attendance, referrals
  from public.reformer_registrations
 where name ilike '%amanda%' or email ilike '%amanda%'
 order by event;

-- 2) Her Mat & Chat booking. admin_notes must contain "#attended".
--    Watch for an email that differs from the reformer one — even by a
--    trailing space, they are two different people as far as the Club knows.
select code, name, email, admin_notes
  from public.matchat_registrations
 where name ilike '%amanda%' or email ilike '%amanda%';

-- 3) THE MOST LIKELY CAUSE, if nobody at all from Sept 13 is showing.
--    The admin reads the roster through reformer_roster(). If that function
--    lists its columns one by one instead of using SELECT *, it will not be
--    returning the new `attendance` column, so every reformer row arrives at
--    the Club with no attendance and earns nothing. Read its definition:
select pg_get_functiondef(p.oid)
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'reformer_roster';

--    In what comes back, look for `attendance`. If it is missing, add
--    `attendance` and `referrals` to that function's SELECT (and to its
--    RETURNS TABLE(...) if it has one), then re-run it.

-- 4) Confirm the columns exist at all — that the SQL files really ran.
select column_name
  from information_schema.columns
 where table_schema = 'public'
   and table_name   = 'reformer_registrations'
   and column_name in ('attendance','referrals','winner','archived')
 order by column_name;
--    Expect four rows. A missing one means that SQL file has not been run:
--      attendance, winner → REFORMER_ATTENDANCE.sql
--      referrals          → REFORMER_REFERRAL.sql
--      archived           → REFORMER_ARCHIVE.sql

-- 5) Everyone currently marked attended for a reformer event. If this comes
--    back empty but you have been ticking ✓ Attended, the button is not
--    saving — check that REFORMER_ATTENDANCE.sql ran without error.
select event, count(*) as attended
  from public.reformer_registrations
 where attendance = 'attended'
 group by event
 order by event;

-- 6) Everyone currently tagged attended for Mat & Chat, for the same reason.
select count(*) as attended
  from public.matchat_registrations
 where admin_notes ilike '%#attended%';

-- 7) Create & Recharge. Same tag-based system as Mat & Chat: the Club counts
--    anyone whose admin_notes contains "#attended". If this comes back empty
--    but you have been ticking ✓ Attended on that roster, the tag is not
--    saving — the button writes straight to the table, so a row-level
--    security rule blocking the update would fail quietly.
select count(*) as attended
  from public.create_recharge_registrations
 where admin_notes ilike '%#attended%';

-- 8) One named person across every event at once — the fastest way to see
--    which side of the Club is missing them. Change 'angelina' below.
--    Each row shows the event and whether it is earning a mark.
with who as (select '%angelina%'::text as q)
select 'Create & Recharge' as event, name, email,
       case when admin_notes ilike '%#attended%' then 'attended' else '— not marked —' end as status
  from public.create_recharge_registrations, who
 where name ilike q or email ilike q
union all
select 'Mat & Chat', name, email,
       case when admin_notes ilike '%#attended%' then 'attended' else '— not marked —' end
  from public.matchat_registrations, who
 where name ilike q or email ilike q
union all
select 'Pilates x Niara', name, email,
       case when admin_notes ilike '%#attended%' then 'attended' else '— not marked —' end
  from public.pilates_registrations, who
 where name ilike q or email ilike q
union all
select coalesce(event,'Reformer'), name, email,
       coalesce(attendance, '— not marked —')
  from public.reformer_registrations, who
 where name ilike q or email ilike q
 order by 1;
--    No rows at all → that person is not booked under that name anywhere;
--    check whether someone else booked for them.
--    Rows showing "— not marked —" → that is the mark that never saved.
--    Two rows with emails that differ → the Club sees two separate people.
