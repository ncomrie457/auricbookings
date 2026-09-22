-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — let an archived registration say WHY it's archived
--
--  WHY: the Archive list used to label every unpaid row "never paid".
--  That's wrong for two common cases:
--    · you gave them a credit  — crediting them marks them unpaid, because
--      that's how their seat is freed for the next person
--    · they rescheduled        — you moved them off this session by hand
--  Both people paid you. Calling them non-payers is a bad record to keep.
--
--  WHAT THIS DOES: widens reformer_set_attendance so it also accepts
--  'credited' and 'rescheduled'. Nothing else changes — 'attended' and
--  'noshow' behave exactly as before, and the Auric Club still counts
--  only 'attended', so no one gains or loses a mark.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
--  (Run REFORMER_ATTENDANCE.sql first if you haven't.)
-- ════════════════════════════════════════════════════════════════════

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

  if val is not null and val <> ''
     and val not in ('attended','noshow','credited','rescheduled') then
    raise exception 'attendance must be attended, noshow, credited, rescheduled, or empty';
  end if;

  update public.reformer_registrations
     set attendance = nullif(val, '')
   where id = rid;
end;
$$;

revoke all on function public.reformer_set_attendance(text, bigint, text) from public, anon;
grant execute on function public.reformer_set_attendance(text, bigint, text) to authenticated;

select 'ready — the Archive can now label someone Credit or Rescheduled.' as status;
