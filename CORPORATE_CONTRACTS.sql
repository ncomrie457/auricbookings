-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — private & corporate event contracts
--
--  WHY: a private booking is money you turn other work away for. Until
--  now the only record of what was agreed was an email thread. If a
--  client cancels three days out and disputes the fee, "I emailed them"
--  is weak. "They typed their name at 3:42pm on October 15, and here is
--  the exact text they agreed to" is not.
--
--  HOW IT WORKS
--    1. You draft a contract from an inquiry in the admin panel. You set
--       the fee, the deposit, and the notice windows.
--    2. The SITE generates the terms text and stores it on the row, word
--       for word. The client sees that stored text, not a fresh render —
--       so editing the template later can never change what someone
--       already signed.
--    3. You copy the link and send it yourself, in your own words.
--    4. They open it, read it, tick, and type their name. Signed.
--
--  THE LINK IS THE KEY. Anyone holding it can read and sign that one
--  contract, so the code carries 64 bits of randomness and is generated
--  down here, where the browser cannot weaken it. Send it to the client
--  and nobody else.
--
--  WHAT THIS CREATES
--    1) corporate_contracts         — one row per contract.
--    2) auric_contract_create(...)  — owner only. Returns the new code.
--    3) auric_contract_get(code)    — PUBLIC. One row, by exact code.
--    4) auric_contract_sign(...)    — PUBLIC. Signs once, never twice.
--    5) auric_contracts_list()      — owner only. Powers the admin list.
--    6) auric_contract_delete(code) — owner only.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

-- 1) The table ────────────────────────────────────────────────────────
create table if not exists public.corporate_contracts (
  id              bigint generated always as identity primary key,
  code            text not null unique,

  -- who
  company_name    text not null,
  contact_name    text not null,
  contact_email   text not null,
  contact_phone   text,

  -- what
  class_type      text,
  duration        text,
  headcount       text,
  session_date    text,          -- free text: "Saturday, Nov 22 at 11:00 AM"
  location        text,

  -- money
  total_fee       numeric(10,2),
  deposit         numeric(10,2),
  balance_due_days   int default 7,   -- balance due this many days before
  cancel_window_days int default 7,   -- inside this window, the full fee
  reschedule_notice_days int default 14,

  extra_terms     text,          -- anything you add by hand for this client

  -- The exact words they agreed to. Never regenerate this; a contract
  -- that can be rewritten after signing is not a contract.
  terms_snapshot  text not null,

  inquiry_code    text,          -- the corporate_inquiries row this came from
  status          text not null default 'sent',   -- 'sent' | 'signed'

  signature       text,
  signed_at       timestamptz,

  created_at      timestamptz not null default now(),
  admin_notes     text
);

create index if not exists corporate_contracts_code_idx
  on public.corporate_contracts (code);

-- Nobody touches this table directly. Everything goes through the
-- functions below, which decide what the public may see.
alter table public.corporate_contracts enable row level security;

-- 2) Draft a contract ─────────────────────────────────────────────────
--    Returns the new code. The browser never chooses it.
create or replace function public.auric_contract_create(
  pass            text,
  p_company       text,
  p_contact       text,
  p_email         text,
  p_terms         text,
  p_phone         text default null,
  p_class_type    text default null,
  p_duration      text default null,
  p_headcount     text default null,
  p_session_date  text default null,
  p_location      text default null,
  p_total         numeric default null,
  p_deposit       numeric default null,
  p_balance_days  int default 7,
  p_cancel_days   int default 7,
  p_resched_days  int default 14,
  p_extra         text default null,
  p_inquiry_code  text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;
  if coalesce(trim(p_company), '') = '' or coalesce(trim(p_contact), '') = ''
     or coalesce(trim(p_email), '') = '' then
    raise exception 'company, contact name and email are required';
  end if;
  if coalesce(trim(p_terms), '') = '' then
    raise exception 'the contract text is required';
  end if;

  -- 16 hex characters of a random uuid: 64 bits. Not guessable by hand
  -- and not reachable by walking a counter.
  new_code := 'CTR-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 16));

  insert into public.corporate_contracts (
    code, company_name, contact_name, contact_email, contact_phone,
    class_type, duration, headcount, session_date, location,
    total_fee, deposit, balance_due_days, cancel_window_days,
    reschedule_notice_days, extra_terms, terms_snapshot, inquiry_code
  ) values (
    new_code, trim(p_company), trim(p_contact), lower(trim(p_email)),
    nullif(trim(p_phone), ''), nullif(trim(p_class_type), ''),
    nullif(trim(p_duration), ''), nullif(trim(p_headcount), ''),
    nullif(trim(p_session_date), ''), nullif(trim(p_location), ''),
    p_total, p_deposit, coalesce(p_balance_days, 7), coalesce(p_cancel_days, 7),
    coalesce(p_resched_days, 14), nullif(trim(p_extra), ''), p_terms,
    nullif(trim(p_inquiry_code), '')
  );

  return new_code;
end;
$$;

-- 3) Read one contract by its code — PUBLIC ───────────────────────────
--    The client opening their link is not signed in, so this has to be
--    callable by anon. It returns exactly one row, found by exact code,
--    and deliberately leaves out admin_notes and the internal id.
create or replace function public.auric_contract_get(p_code text)
returns table (
  code text, company_name text, contact_name text, contact_email text,
  class_type text, duration text, headcount text, session_date text,
  location text, total_fee numeric, deposit numeric,
  balance_due_days int, cancel_window_days int, reschedule_notice_days int,
  extra_terms text, terms_snapshot text, status text,
  signature text, signed_at timestamptz, created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(trim(p_code), '') = '' then
    return;
  end if;
  return query
    select c.code, c.company_name, c.contact_name, c.contact_email,
           c.class_type, c.duration, c.headcount, c.session_date,
           c.location, c.total_fee, c.deposit,
           c.balance_due_days, c.cancel_window_days, c.reschedule_notice_days,
           c.extra_terms, c.terms_snapshot, c.status,
           c.signature, c.signed_at, c.created_at
      from public.corporate_contracts c
     where c.code = trim(p_code);
end;
$$;

-- 4) Sign it — PUBLIC ─────────────────────────────────────────────────
--    Signs once. A second attempt leaves the first signature and its
--    timestamp exactly where they are, so a reload cannot overwrite the
--    record of when it was actually signed.
create or replace function public.auric_contract_sign(
  p_code      text,
  p_signature text
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  rec   public.corporate_contracts%rowtype;
  stamp timestamptz;
begin
  if coalesce(trim(p_signature), '') = '' then
    raise exception 'a signature is required';
  end if;

  select * into rec from public.corporate_contracts where code = trim(p_code);
  if not found then
    raise exception 'contract not found';
  end if;
  if rec.signed_at is not null then
    return rec.signed_at;      -- already signed; say when, change nothing
  end if;

  stamp := now();
  update public.corporate_contracts
     set signature = trim(p_signature),
         signed_at = stamp,
         status    = 'signed'
   where code = trim(p_code)
     and signed_at is null;    -- belt and braces against two tabs at once

  select signed_at into stamp from public.corporate_contracts where code = trim(p_code);
  return stamp;
end;
$$;

-- 5) List them all, newest first — owner only ─────────────────────────
create or replace function public.auric_contracts_list(pass text default '')
returns setof public.corporate_contracts
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;
  return query
    select * from public.corporate_contracts
     order by (signed_at is not null), created_at desc;   -- unsigned first
end;
$$;

-- 6) Delete one drafted by mistake — owner only ───────────────────────
create or replace function public.auric_contract_delete(pass text, p_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;
  delete from public.corporate_contracts where code = trim(p_code);
end;
$$;

-- 7) Who may call what ────────────────────────────────────────────────
revoke all on function public.auric_contract_create(text,text,text,text,text,text,text,text,text,text,text,numeric,numeric,int,int,int,text,text) from public, anon;
revoke all on function public.auric_contracts_list(text)        from public, anon;
revoke all on function public.auric_contract_delete(text, text) from public, anon;

grant execute on function public.auric_contract_create(text,text,text,text,text,text,text,text,text,text,text,numeric,numeric,int,int,int,text,text) to authenticated;
grant execute on function public.auric_contracts_list(text)        to authenticated;
grant execute on function public.auric_contract_delete(text, text) to authenticated;

-- These two are the client's half of the deal. They hold the link; they
-- are not signed in. Both are scoped to a single row by exact code.
grant execute on function public.auric_contract_get(text)        to anon, authenticated;
grant execute on function public.auric_contract_sign(text, text) to anon, authenticated;

select 'contracts ready — the Contracts tab in the admin panel will now load.' as status;
