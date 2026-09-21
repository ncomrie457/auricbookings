-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — credits
--
--  WHY: when someone cancels in time under the 48-hour policy, they are
--  owed a credit toward a future event. Until now that lived in your head
--  and your sent folder. A credit is money you owe someone, so it needs a
--  record that survives a lost phone and tells you, months later, exactly
--  what you promised and whether it has been used.
--
--  Credits live in their own table rather than on a booking row, because a
--  credit earned at one event gets spent at a different one.
--
--  WHAT THIS CREATES
--    1) auric_credits          — one row per credit issued.
--    2) auric_credits_list()   — owner-only, powers the admin Credits tab.
--    3) auric_credit_add(...)  — owner-only, issues a credit.
--    4) auric_credit_redeem()  — owner-only, marks one used (or un-uses it).
--    5) auric_credit_delete()  — owner-only, removes one issued by mistake.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

-- 1) The table ────────────────────────────────────────────────────────
create table if not exists public.auric_credits (
  id          bigint generated always as identity primary key,
  name        text not null,
  email       text not null,
  amount      numeric(10,2),        -- what they paid, e.g. 45.00. Null = "one class".
  from_event  text,                 -- the event they cancelled, free text
  note        text,                 -- anything you want to remember
  issued_at   timestamptz not null default now(),
  expires_at  date,                 -- null = no expiry
  redeemed_at timestamptz,          -- null = still owed
  redeemed_for text                 -- which event they used it on
);

-- Looking someone up by email is the common case.
create index if not exists auric_credits_email_idx
  on public.auric_credits (lower(email));

-- Nobody reaches this table directly; everything goes through the
-- owner-only functions below.
alter table public.auric_credits enable row level security;

-- 2) List every credit, newest first. The admin panel calls this. ─────
create or replace function public.auric_credits_list(pass text default '')
returns setof public.auric_credits
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;
  return query
    select * from public.auric_credits
     order by (redeemed_at is not null), issued_at desc;   -- unused first
end;
$$;

-- 3) Issue a credit ───────────────────────────────────────────────────
create or replace function public.auric_credit_add(
  pass        text,
  p_name      text,
  p_email     text,
  p_amount    numeric default null,
  p_from      text default null,
  p_note      text default null,
  p_expires   date default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id bigint;
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;
  if coalesce(trim(p_name), '') = '' or coalesce(trim(p_email), '') = '' then
    raise exception 'name and email are required';
  end if;

  insert into public.auric_credits (name, email, amount, from_event, note, expires_at)
  values (trim(p_name), lower(trim(p_email)), p_amount, nullif(trim(p_from), ''), nullif(trim(p_note), ''), p_expires)
  returning id into new_id;

  return new_id;
end;
$$;

-- 4) Mark a credit used, or put it back ───────────────────────────────
--    p_for: which event they spent it on. Pass used := false to undo.
create or replace function public.auric_credit_redeem(
  pass   text,
  cid    bigint,
  used   boolean default true,
  p_for  text default null
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

  update public.auric_credits
     set redeemed_at   = case when used then now() else null end,
         redeemed_for  = case when used then nullif(trim(p_for), '') else null end
   where id = cid;
end;
$$;

-- 5) Delete one issued by mistake ─────────────────────────────────────
create or replace function public.auric_credit_delete(pass text, cid bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;
  delete from public.auric_credits where id = cid;
end;
$$;

-- 6) Lock the functions to a signed-in owner ──────────────────────────
revoke all on function public.auric_credits_list(text)                                        from public, anon;
revoke all on function public.auric_credit_add(text, text, text, numeric, text, text, date)   from public, anon;
revoke all on function public.auric_credit_redeem(text, bigint, boolean, text)                from public, anon;
revoke all on function public.auric_credit_delete(text, bigint)                               from public, anon;

grant execute on function public.auric_credits_list(text)                                      to authenticated;
grant execute on function public.auric_credit_add(text, text, text, numeric, text, text, date) to authenticated;
grant execute on function public.auric_credit_redeem(text, bigint, boolean, text)              to authenticated;
grant execute on function public.auric_credit_delete(text, bigint)                             to authenticated;

select 'credits ready — the Credits tab in the admin panel will now load.' as status;
