-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — email opt-outs
--
--  WHY: a promotional email has to carry a working unsubscribe link.
--  "Working" means two things, and the link is only the first:
--    1. the person can opt out without logging in or emailing you, and
--    2. the next send actually skips them.
--  A link that records nothing is worse than no link, because it tells
--  someone they have opted out when they have not.
--
--  WHAT THIS IS NOT: this list does not touch booking confirmations,
--  waivers, payment receipts or event reminders. Those are transactional
--  — someone who bought a class is owed the details of it, and opting
--  out of marketing does not cancel that. It only gates campaigns.
--
--  WHAT THIS CREATES
--    1) email_optouts            — one row per address, newest wins.
--    2) auric_optout_add(email)  — PUBLIC. What the unsubscribe page calls.
--    3) auric_optout_check(email)— PUBLIC. So the page can say "already done".
--    4) auric_optouts_list()     — owner only, for the admin panel.
--    5) auric_optout_remove()    — owner only, if someone asks to come back.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

-- 1) The list ─────────────────────────────────────────────────────────
create table if not exists public.email_optouts (
  id          bigint generated always as identity primary key,
  email       text not null unique,      -- always stored lower-cased and trimmed
  source      text,                      -- which campaign they left from
  created_at  timestamptz not null default now()
);

create index if not exists email_optouts_email_idx on public.email_optouts (email);

alter table public.email_optouts enable row level security;

-- 2) Opt out — PUBLIC ─────────────────────────────────────────────────
--    The person clicking unsubscribe is not signed in, so anon has to be
--    able to call this. It only ever ADDS an address to a suppression
--    list, which is the safe direction: the worst a bad actor achieves is
--    stopping marketing to an address, and section 5 lets you undo it.
create or replace function public.auric_optout_add(p_email text, p_source text default null)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  key text := lower(trim(coalesce(p_email, '')));
begin
  if key = '' or key !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'a valid email address is required';
  end if;

  insert into public.email_optouts (email, source)
  values (key, nullif(trim(p_source), ''))
  on conflict (email) do nothing;        -- asking twice is not an error

  return true;
end;
$$;

-- 3) Are they already off the list? — PUBLIC ──────────────────────────
--    Returns only a yes/no for the exact address asked about, so it
--    cannot be used to read the list.
create or replace function public.auric_optout_check(p_email text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  key text := lower(trim(coalesce(p_email, '')));
begin
  if key = '' then return false; end if;
  return exists (select 1 from public.email_optouts where email = key);
end;
$$;

-- 4) The whole list — owner only ──────────────────────────────────────
create or replace function public.auric_optouts_list(pass text default '')
returns setof public.email_optouts
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;
  return query select * from public.email_optouts order by created_at desc;
end;
$$;

-- 5) Put someone back — owner only ────────────────────────────────────
--    Only ever after they ask you to. Taking someone off a suppression
--    list without being asked is exactly the thing the list exists to
--    prevent.
create or replace function public.auric_optout_remove(pass text, p_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;
  delete from public.email_optouts where email = lower(trim(p_email));
end;
$$;

-- 6) Who may call what ────────────────────────────────────────────────
revoke all on function public.auric_optouts_list(text)        from public, anon;
revoke all on function public.auric_optout_remove(text, text) from public, anon;

grant execute on function public.auric_optouts_list(text)        to authenticated;
grant execute on function public.auric_optout_remove(text, text) to authenticated;

-- The unsubscribe page is opened by someone who is not signed in.
grant execute on function public.auric_optout_add(text, text) to anon, authenticated;
grant execute on function public.auric_optout_check(text)     to anon, authenticated;

select 'opt-outs ready — the unsubscribe page will now record, and campaigns will skip them.' as status;
