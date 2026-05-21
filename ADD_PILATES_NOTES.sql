-- Add notes column to pilates_registrations for health disclosure
alter table public.pilates_registrations add column if not exists notes text;
