-- ─────────────────────────────────────────────────────────────────────────
-- Pre-Turkey Burn moved from Sat Nov 21 to Sun Nov 22.
--
-- The site now stores that event as `turkey-burn-2026-11-22`. Any row booked
-- before the move still says `turkey-burn-2026-11-21`, and the roster filters
-- on that exact string — so those rows would simply stop appearing anywhere,
-- which is the worst kind of bug: silent.
--
-- WHEN TO RUN THIS: once, in Supabase → SQL Editor. It is safe to run even if
-- there are no old rows (it just reports 0).
--
-- HOW: paste the whole file, press Run, read the output of each step.
-- ─────────────────────────────────────────────────────────────────────────

-- 1) Look before you change anything. This tells you how many bookings are
--    about to move, and who they are. If it says 0 rows, you can stop here —
--    nothing needs migrating and step 2 will do nothing.
select id, name, email, session, is_paid, created_at
from reformer_registrations
where event = 'turkey-burn-2026-11-21'
order by created_at;

-- 2) Move them onto the new event id.
update reformer_registrations
set event = 'turkey-burn-2026-11-22'
where event = 'turkey-burn-2026-11-21';

-- 3) Confirm nothing is left behind on the old id.
--    Expected: 0 rows.
select count(*) as still_on_the_old_date
from reformer_registrations
where event = 'turkey-burn-2026-11-21';

-- 4) And confirm they landed. Sessions should only ever be
--    tb1130 / tb1230 / tb130 — anything else is a row worth looking at,
--    because the booking form cannot produce another value.
select session, count(*) as bookings, sum(case when is_paid then 1 else 0 end) as paid
from reformer_registrations
where event = 'turkey-burn-2026-11-22'
group by session
order by session;

-- ─────────────────────────────────────────────────────────────────────────
-- A NOTE ON THE 1:35 → 1:30 CHANGE
--
-- The later session at both Valley events moved from 1:35 PM to 1:30 PM, and
-- Halloween gained an 11:30 AM session. The session KEYS did not change
-- (`tb130`, `hw130`), so no booking needs moving for that — only the time
-- shown to guests changed.
--
-- But anyone who booked the 1:35 session BEFORE this change already has a
-- confirmation email and a calendar entry that say 1:35 PM. This query finds
-- them so you can send a short note:
--
--   select name, email, event, session, created_at
--   from reformer_registrations
--   where session in ('hw130', 'tb130') and is_paid
--   order by created_at;
-- ─────────────────────────────────────────────────────────────────────────
