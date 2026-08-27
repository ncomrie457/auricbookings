-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Business Expense Tracker setup
--
--  Creates:
--   1. business_expenses table (your ledger), owner-only.
--   2. A private "receipts" storage bucket for receipt photos/PDFs,
--      owner-only.
--
--  "Owner-only" means: only YOU (logged in as the owner) can see, add, or
--  delete expenses and receipts. Nobody else — not the public, not a
--  collaborator — can touch this. Same is_owner() login you already use.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

-- 1) The expense ledger ------------------------------------------------
create table if not exists public.business_expenses (
  id             uuid primary key default gen_random_uuid(),
  spent_on       date,            -- optional: fill in later if unknown now
  vendor         text,
  category       text,
  amount         numeric(12,2) not null,
  payment_method text,
  purpose        text,
  notes          text,
  deductible     boolean not null default true,
  receipt_path   text,            -- file path inside the "receipts" bucket
  created_at     timestamptz not null default now()
);

alter table public.business_expenses enable row level security;

drop policy if exists exp_owner_all on public.business_expenses;
create policy exp_owner_all on public.business_expenses
  for all to authenticated
  using (public.is_owner())
  with check (public.is_owner());

-- 2) Private receipts bucket -------------------------------------------
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- Owner-only access to files in the receipts bucket.
drop policy if exists receipts_owner_read   on storage.objects;
drop policy if exists receipts_owner_insert on storage.objects;
drop policy if exists receipts_owner_delete on storage.objects;

create policy receipts_owner_read on storage.objects
  for select to authenticated
  using (bucket_id = 'receipts' and public.is_owner());

create policy receipts_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'receipts' and public.is_owner());

create policy receipts_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'receipts' and public.is_owner());

select 'Expense tracker ready: table + receipts bucket created.' as status;
