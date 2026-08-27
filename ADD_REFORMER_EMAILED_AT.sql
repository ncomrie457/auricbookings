-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — add an "email sent" marker to reformer bookings
--
--  WHY: the Stripe webhook marks a booking paid, then emails the
--  confirmation. If the first delivery hiccups AFTER marking paid, Stripe
--  retries — but the old code only looked for UNPAID bookings, so the retry
--  saw "already paid" and skipped the email. Result: paid, no email.
--
--  This adds emailed_at. The new webhook sends the email only while
--  emailed_at is null, and stamps it once the email actually goes out — so a
--  retry re-sends a missed email, and a success is never re-sent (no
--  duplicates).
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

alter table public.reformer_registrations
  add column if not exists emailed_at timestamptz;

-- Backfill: treat every booking that's ALREADY paid as already-emailed, so
-- this change never re-sends a confirmation for a past booking.
update public.reformer_registrations
   set emailed_at = coalesce(paid_at, now())
 where is_paid = true and emailed_at is null;

select 'emailed_at column added + backfilled.' as status;
