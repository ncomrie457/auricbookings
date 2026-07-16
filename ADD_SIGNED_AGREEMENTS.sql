-- Signed agreements storage (drawn "wet" signatures from /sign/... pages)
-- Run this once in Supabase → SQL Editor → Run.

create table if not exists public.signed_agreements (
  id                uuid primary key default gen_random_uuid(),
  agreement_id      text not null default 'create-recharge-collab', -- which agreement was signed
  signer_name       text not null,
  signer_email      text,
  art_cost          text,          -- the fill-in amount (Section 3), if any
  agreement_text    text not null, -- exact agreement text that was signed (snapshot)
  signature_data    text not null, -- PNG data URL of the drawn signature
  signed_at         timestamptz not null default now(),
  signed_at_display text,          -- human-readable local timestamp from the signer's browser
  created_at        timestamptz not null default now()
);

-- Row Level Security: allow the public sign page to INSERT and the admin panel
-- (both use the publishable/anon key) to READ. Mirrors the existing tables.
alter table public.signed_agreements enable row level security;

drop policy if exists "anon insert signed_agreements" on public.signed_agreements;
create policy "anon insert signed_agreements" on public.signed_agreements
  for insert to anon, authenticated with check (true);

drop policy if exists "anon read signed_agreements" on public.signed_agreements;
create policy "anon read signed_agreements" on public.signed_agreements
  for select to anon, authenticated using (true);

drop policy if exists "anon delete signed_agreements" on public.signed_agreements;
create policy "anon delete signed_agreements" on public.signed_agreements
  for delete to anon, authenticated using (true);
