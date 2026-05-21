-- Adds automatic payment tracking + spot expiry to event tables
-- Run this in Supabase SQL Editor → Run

-- Pilates: payment tracking columns
alter table public.pilates_registrations add column if not exists is_paid boolean default false;
alter table public.pilates_registrations add column if not exists paid_at timestamptz;
alter table public.pilates_registrations add column if not exists expires_at timestamptz default (now() + interval '2 hours');

-- Mat & Chat: payment tracking columns
alter table public.matchat_registrations add column if not exists is_paid boolean default false;
alter table public.matchat_registrations add column if not exists paid_at timestamptz;
alter table public.matchat_registrations add column if not exists expires_at timestamptz default (now() + interval '2 hours');

-- Allow 'cancelled' as a valid type for both tables
alter table public.pilates_registrations drop constraint if exists pilates_registrations_type_check;
alter table public.pilates_registrations add  constraint pilates_registrations_type_check check (type in ('confirmed','waitlist','cancelled'));

alter table public.matchat_registrations  drop constraint if exists matchat_registrations_type_check;
alter table public.matchat_registrations  add  constraint matchat_registrations_type_check check (type in ('confirmed','waitlist','cancelled'));

-- Mark all existing rows as already paid (they pre-date this system)
update public.pilates_registrations set is_paid = true, paid_at = created_at where is_paid = false;
update public.matchat_registrations  set is_paid = true, paid_at = created_at where is_paid = false;
