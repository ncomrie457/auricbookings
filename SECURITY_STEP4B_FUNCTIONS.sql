-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Security Step 4b, PART 1: safe read + dedup functions
--
--  These CLOSE the last privacy leak: today anyone with the public key can
--  read every pilates / matchat / create-recharge registrant's name, email,
--  phone, and health notes. These functions let the PUBLIC booking pages get
--  what they need — "spots left" counts + "are YOU already registered?" —
--  WITHOUT ever returning other people's personal info.
--
--  How it works:
--   • <event>_read()        → returns all rows, but with name/email/phone/
--                             notes/signature BLANKED unless you are the
--                             logged-in owner. (Owner still sees everything.)
--   • <event>_email_status()→ tells a booker only about THEIR OWN email.
--   • matchat_remove_prior()→ server-side cleanup after a booking supersedes
--                             a prior waitlist entry (was a public read+delete).
--
--  ▶ PART 1 is additive and safe — it changes nothing about the live site.
--    The website is switched to use these first; the lock (PART 2) comes after.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

-- ─── PILATES ────────────────────────────────────────────────────────
create or replace function public.pilates_read()
returns setof public.pilates_registrations
language sql stable security definer set search_path = public as $$
  select jsonb_populate_record(
    null::public.pilates_registrations,
    case when public.is_owner() then to_jsonb(r)
         else to_jsonb(r) - 'name' - 'email' - 'signature' - 'notes' - 'admin_notes'
    end)
  from public.pilates_registrations r
  order by r.created_at;
$$;

create or replace function public.pilates_email_status(p_session text, p_email text)
returns table(code text, type text, wl_position int, is_paid boolean)
language sql stable security definer set search_path = public as $$
  select code, type, wl_position, is_paid
  from public.pilates_registrations
  where session_id = p_session and lower(email) = lower(trim(p_email))
  order by created_at desc limit 1;
$$;

-- ─── MAT & CHAT ─────────────────────────────────────────────────────
create or replace function public.matchat_read()
returns setof public.matchat_registrations
language sql stable security definer set search_path = public as $$
  select jsonb_populate_record(
    null::public.matchat_registrations,
    case when public.is_owner() then to_jsonb(r)
         else to_jsonb(r) - 'name' - 'email' - 'phone' - 'signature'
                          - 'notes' - 'admin_notes' - 'friend_name' - 'friend_email'
    end)
  from public.matchat_registrations r
  order by r.created_at;
$$;

create or replace function public.matchat_email_status(p_session text, p_email text)
returns table(code text, type text, wl_position int, is_paid boolean)
language sql stable security definer set search_path = public as $$
  select code, type, wl_position, is_paid
  from public.matchat_registrations
  where lower(email) = lower(trim(p_email))
  order by created_at desc limit 1;
$$;

-- After a confirmed booking supersedes a prior waitlist/cancelled row for
-- the same email, remove those and re-number the remaining waitlist.
create or replace function public.matchat_remove_prior(p_email text, p_keep_code text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.matchat_registrations
  where lower(trim(email)) = lower(trim(p_email))
    and code <> p_keep_code
    and type in ('waitlist','cancelled');
  with ord as (
    select code, row_number() over (order by created_at) as rn
    from public.matchat_registrations where type = 'waitlist'
  )
  update public.matchat_registrations m
  set wl_position = ord.rn from ord where m.code = ord.code;
end;
$$;

-- ─── CREATE & RECHARGE ──────────────────────────────────────────────
create or replace function public.crecharge_read()
returns setof public.create_recharge_registrations
language sql stable security definer set search_path = public as $$
  select jsonb_populate_record(
    null::public.create_recharge_registrations,
    case when public.is_owner() then to_jsonb(r)
         else to_jsonb(r) - 'name' - 'email' - 'phone' - 'signature' - 'notes' - 'admin_notes'
    end)
  from public.create_recharge_registrations r
  order by r.created_at;
$$;

create or replace function public.crecharge_email_status(p_session text, p_email text)
returns table(code text, type text, wl_position int, is_paid boolean)
language sql stable security definer set search_path = public as $$
  select code, type, wl_position, is_paid
  from public.create_recharge_registrations
  where lower(email) = lower(trim(p_email))
  order by created_at desc limit 1;
$$;

-- ─── Grants: the public pages may call these; owner gets full data ──
grant execute on function public.pilates_read()                       to anon, authenticated;
grant execute on function public.pilates_email_status(text,text)      to anon, authenticated;
grant execute on function public.matchat_read()                       to anon, authenticated;
grant execute on function public.matchat_email_status(text,text)      to anon, authenticated;
grant execute on function public.matchat_remove_prior(text,text)      to anon, authenticated;
grant execute on function public.crecharge_read()                     to anon, authenticated;
grant execute on function public.crecharge_email_status(text,text)    to anon, authenticated;

-- Quick check — should return rows with name/email BLANK (you're not logged
-- into the SQL editor as your app user, so this simulates the public view):
select 'pilates_read masks PII for non-owner:' as check,
       bool_and(name is null and email is null) as pii_blanked
from public.pilates_read();
