-- ─────────────────────────────────────────────────────────────────────────
-- Phone numbers, so you can text people about the class they booked
--
-- WHY
--   The nor'easter on September 26th made the gap obvious: you needed to
--   reach the 12 PM group that morning and email was the wrong tool —
--   people were already dressed, already travelling, or hadn't opened it.
--   A text gets read in minutes.
--
--   The reformer booking form has never asked for a phone number, so there
--   was nothing to text. This adds the field, and records separately what
--   each person agreed to.
--
-- THE TWO PERMISSIONS, AND WHY THEY ARE SEPARATE
--   phone       — given under a label that says "for day-of updates about
--                 this class". That is about the thing they paid for, so
--                 texting them about a time change or the weather is fine.
--   sms_events  — ticked, separately and by choice, to hear about FUTURE
--                 events. That is marketing, and in the US it needs express
--                 written consent, with penalties charged per message.
--
--   Keeping them apart is the whole point. Do not text someone about
--   November because they gave you a number for October.
--
-- WHEN TO RUN: once, in Supabase → SQL Editor. Safe to re-run.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.reformer_registrations
  add column if not exists phone      text,
  add column if not exists sms_events boolean not null default false;

comment on column public.reformer_registrations.phone is
  'Mobile number, given voluntarily at booking for day-of updates about that '
  'class. Not consent to market to them — see sms_events.';

comment on column public.reformer_registrations.sms_events is
  'True only if they ticked the box asking to hear about future events. '
  'This is the express written consent that promotional texts require.';

-- 3) A setter, so a number someone sends back by email can be typed into the
--    roster. reformer_edit() takes a fixed name/email pair and cannot carry
--    this, so it gets its own — owner-only, like every other reformer write.
--    Blank clears the number, which is how someone opts back out.
create or replace function public.reformer_set_phone(
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

  update public.reformer_registrations
     set phone = nullif(btrim(coalesce(val, '')), '')
   where id = rid;
end;
$$;

revoke all on function public.reformer_set_phone(text, bigint, text) from public, anon;

-- ─── Checks ──────────────────────────────────────────────────────────────

-- 1) Did it land? Every existing row will read 0 for both — nobody has been
--    asked yet. The numbers start arriving with the next booking.
select count(*)                                   as total_rows,
       count(phone)                               as have_a_number,
       count(*) filter (where sms_events)         as want_future_events
from public.reformer_registrations;

-- 2) Who to text about one event's day-of changes. Paid, not archived, not
--    waitlisted, and has a number. This is the list the admin panel's
--    "Text list" button shows you.
select name, phone, session_label
from public.reformer_registrations
where event = 'riddim-kompa-brooklyn-2026-10-10'
  and phone is not null and phone <> ''
  and is_paid
  and coalesce(type,'') <> 'waitlist'
  and not coalesce(archived, false)
order by session, created_at;

-- 3) Who has agreed to hear about future events, across everything, one row
--    per person. This is the only list a "come book November" text may go to.
select distinct on (lower(phone)) name, phone, event, created_at
from public.reformer_registrations
where sms_events
  and phone is not null and phone <> ''
order by lower(phone), created_at desc;

-- 4) IF THE NUMBERS DO NOT SHOW UP IN THE PANEL, it is this: the admin roster
--    reads through reformer_roster(), and if that function lists its columns
--    explicitly rather than using select *, the new ones never reach the page.
--    This prints it. If you see a column list, send it over and the two can be
--    added to it.
select pg_get_functiondef(p.oid) as reformer_roster_definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'reformer_roster';
