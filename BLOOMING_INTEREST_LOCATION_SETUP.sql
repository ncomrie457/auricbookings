-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — add location preference + preferred days/times to the
--  Riddim & Kompa interest list (blooming_interest table).
--
--  The /riddim-interest form now asks which location a person prefers
--  (West Hempstead / Brooklyn / Either) and, optionally, what days/times
--  work best. These two columns store that.
--
--  Signups still work before this runs — the form falls back to saving
--  the base fields — but the location/times won't be recorded until you
--  add these columns.
--
--  HOW TO RUN: Supabase → SQL Editor → paste → Run. One time.
-- ════════════════════════════════════════════════════════════════════

alter table public.blooming_interest add column if not exists location        text;
alter table public.blooming_interest add column if not exists preferred_times text;

select 'blooming_interest now stores location + preferred_times.' as status;
