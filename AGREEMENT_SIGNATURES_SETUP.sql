-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — e-signature capture for the /northwell agreement page
--
--  Stores who signed the Professional Services Agreement, when, and what
--  they typed. Anyone with the link can submit a signature (insert); only
--  the owner (is_owner()) can read the signed records back.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

create table if not exists public.agreement_signatures (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz default now(),
  agreement       text,          -- version/id of the agreement signed
  signer_name     text,
  signer_title    text,
  signer_org      text,
  signer_email    text,
  typed_signature text,
  agreed          boolean default true,
  change_request  text,          -- set when the signer requests changes instead of signing
  user_agent      text
);

-- Ensure the column exists on installs created before change requests were added.
alter table public.agreement_signatures add column if not exists change_request text;

alter table public.agreement_signatures enable row level security;

-- Anyone with the link can sign (insert only).
drop policy if exists sig_public_insert on public.agreement_signatures;
create policy sig_public_insert on public.agreement_signatures
  for insert to anon, authenticated with check (true);

-- Only the owner can read the signed records.
drop policy if exists sig_owner_read on public.agreement_signatures;
create policy sig_owner_read on public.agreement_signatures
  for select to authenticated using (public.is_owner());

grant insert on public.agreement_signatures to anon, authenticated;
grant select on public.agreement_signatures to authenticated;

select 'agreement_signatures ready — the /northwell signing page can now record signatures.' as status;
