-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — long sleeve shirt size on reformer bookings
--
--  WHY: the Halloween booking form now asks "What size shirt are you in a
--  long sleeve?" so you know what to order. This is where that answer is
--  kept.
--
--  The booking form does NOT depend on this having been run. If the column
--  is missing, the site notices the insert was refused and re-sends the
--  booking without the size — the spot is still booked, you just won't have
--  the size on that row. Run this and every booking from then on carries it.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

alter table public.reformer_registrations
  add column if not exists shirt_size text;

-- NOTE: the admin roster reads through reformer_roster(). If that function
-- uses SELECT * this already works. If it lists columns explicitly, add
-- `shirt_size` to its SELECT (and to its RETURNS TABLE(...) if it has one),
-- otherwise the roster will not show the size.

-- Who has given a size so far, and what to order:
--   select shirt_size, count(*)
--     from public.reformer_registrations
--    where event = 'halloween-creek-2026-10-24' and shirt_size is not null
--    group by shirt_size order by shirt_size;

select 'shirt_size ready — Halloween bookings now record a long sleeve size.' as status;
