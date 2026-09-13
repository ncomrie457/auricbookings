-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Attendance marking for reformer events
--  (Riddim & Kompa, Shhh… Quiet on the Creek, Turkey Burn)
--
--  WHY: the Mat & Chat / Pilates / Create & Recharge rosters have
--  "✓ Attended" and "○ No-show" buttons, and those attendance marks feed
--  the Auric Club. The reformer events never had them, so people who came
--  to Riddim & Kompa couldn't earn a Club mark. This adds that.
--
--  WHAT THIS CREATES
--    1) reformer_registrations.attendance  — 'attended' | 'noshow' | null
--    2) reformer_set_attendance(...)       — owner-only write, used by the
--                                            admin roster buttons.
--    3) reformer_club_marks(p_email)       — returns ONLY a number: how many
--                                            reformer events that email
--                                            attended. Safe to call from the
--                                            public "Check My Marks" box
--                                            because it never returns names,
--                                            emails, or any other rows.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

-- 1) The flag. Null = not marked yet, so nothing changes for existing rows.
alter table public.reformer_registrations
  add column if not exists attendance text;

-- 2) Owner-only setter used by the "✓ Attended" / "○ No-show" buttons.
--    val: 'attended', 'noshow', or null/'' to clear the mark.
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

-- 3) Public Club counter. Takes an email, returns a single integer.
--    Counts DISTINCT events so one person can't get two marks for one event.
--    Deliberately returns no rows/PII, so the public Auric Club lookup can
--    call it without exposing who attended.
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

-- 4) NOTE: the admin roster reads through reformer_roster(). If that function
--    uses SELECT * this already works. If it lists columns explicitly, add
--    `attendance` to its SELECT (and to its RETURNS TABLE(...) if it has one),
--    otherwise the buttons won't show the current state.

select 'reformer attendance ready — ✓ Attended / ○ No-show now work and feed the Auric Club.' as status;
