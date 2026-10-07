-- ═══════════════════════════════════════════════════════════════════════════
--  Comp attendees — a free seat, recorded as free.
--
--  WHY A COLUMN AND NOT JUST "MARK THEM PAID"
--    A comp has to be marked is_paid so it behaves like a real booking: it
--    holds a seat, it counts toward the session being full, and it can be sent
--    a confirmation. But a comp is not revenue, and once it is marked paid
--    there is nothing left to tell the two apart.
--
--    That matters at exactly the wrong moment. A sold-out class with three
--    comps in it took $90 less than it looks like it did, and without this
--    column no report, no export and no memory can recover which three.
--
--  WHAT CHANGES
--    Nothing about how a comp behaves. It is still paid, still holds a seat,
--    still appears on the roster and in the reminder list. The column only
--    records why it was free.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. Safe to re-run.
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.reformer_registrations
  add column if not exists comp boolean not null default false;

comment on column public.reformer_registrations.comp is
  'True when the seat was given rather than sold — a guest, a prize, a make-good. '
  'These rows are is_paid = true so they hold a seat and behave like any other '
  'booking; this column is the only record that no money came in.';

-- ─── Checks ──────────────────────────────────────────────────────────────

-- 1) Did it land? Every existing row reads false — nothing has been comped yet.
select count(*) as total_rows,
       count(*) filter (where comp) as comped
from public.reformer_registrations;

-- 2) What an event actually took. Paid seats and comped seats are both full
--    seats; only one of them is money.
select event,
       count(*) filter (where is_paid and not comp and coalesce(type,'') <> 'waitlist'
                          and not coalesce(archived,false))                as paid_seats,
       count(*) filter (where is_paid and comp and not coalesce(archived,false)) as comped_seats,
       (count(*) filter (where is_paid and not comp and coalesce(type,'') <> 'waitlist'
                           and not coalesce(archived,false))) * 45          as approx_revenue
from public.reformer_registrations
group by event
order by event;

-- 3) Who is on a comp, and for what.
select name, email, event, session_label, created_at
from public.reformer_registrations
where comp and not coalesce(archived, false)
order by created_at desc;
